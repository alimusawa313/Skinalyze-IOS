import SwiftData
import SwiftUI
import SkinalyzeKit

/// The scan ritual: live camera → gated auto-capture of three angles → review → analysis.
/// Lives in a full-screen cover so fold/unfold/rotate never interrupts it; the model keeps captured angles.
struct ScanFlowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var model = ScanCaptureModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.dark)
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.resume()
            case .background: model.pause()
            default: break
            }
        }
        .onChange(of: model.state) { _, state in
            guard state == .finished else { return }
            appModel.scanFinished(model.savedSessionID)
            let container = modelContext.container
            Task {
                await WidgetSummary.refresh(from: container)
                await ScanReminders.rescheduleIfEnabled()
            }
        }
        .onDisappear { model.cancel() }
        .sensoryFeedback(Haptic.capture, trigger: model.captures.count)
        .sensoryFeedback(Haptic.success, trigger: model.state == .finished)
    }

    @ViewBuilder private var content: some View {
        if model.cameraUnavailable {
            MessageScreen(
                systemImage: "camera.metering.unknown",
                title: "Camera unavailable",
                message: "The front camera couldn't start. The Simulator has no camera — scan on a real iPhone.",
                primary: ("Close", close)
            )
        } else {
            switch model.state {
            case .idle, .needsPermission:
                ProgressView("Starting camera…").tint(.white).foregroundStyle(.white)
            case .permissionDenied:
                MessageScreen(
                    systemImage: "camera",
                    title: "Camera access is off",
                    message: "Skinalyze needs the front camera to scan. Photos are analysed on this iPhone and never uploaded.",
                    primary: ("Open Settings", openSettings),
                    secondary: ("Not now", close)
                )
            case let .capturing(angle, captured):
                CaptureScreen(model: model, angle: angle, captured: captured, close: close)
            case let .reviewing(captured):
                ReviewScreen(model: model, captured: captured, close: close) {
                    Task { await model.confirm(productIDs: UserProfile.currentProductIDs, container: modelContext.container) }
                }
            case .analyzing, .finished:
                AnalyzingScreen(image: model.captures[.front])
            case .failed:
                MessageScreen(
                    systemImage: "exclamationmark.triangle",
                    title: "We couldn't read these photos",
                    message: "Your photos are still here. Try again, or retake them in softer light.",
                    primary: ("Try again", {
                        Task { await model.retryAnalysis(productIDs: UserProfile.currentProductIDs, container: modelContext.container) }
                    }),
                    secondary: ("Close", close)
                )
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func close() {
        model.cancel()
        appModel.isScanning = false
    }
}

// MARK: - Capture

private struct CaptureScreen: View {
    let model: ScanCaptureModel
    let angle: CaptureAngle
    let captured: [CaptureAngle]
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = false

    var body: some View {
        AdaptivePair(.overlay) {
            CameraPreview(camera: model.camera)
                .ignoresSafeArea()
                .overlay { faceGuide }
                .overlay { Color.white.opacity(flash ? 0.6 : 0).ignoresSafeArea().allowsHitTesting(false) }
        } secondary: {
            controls
        }
        .onChange(of: model.captures.count) {
            guard !reduceMotion else { return }
            flash = true
            withAnimation(.easeOut(duration: 0.35)) { flash = false }
        }
        .onChange(of: model.hint) { _, hint in
            AccessibilityNotification.Announcement(GuidanceCopy.text(for: hint)).post()
        }
    }

    private var faceGuide: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, proxy.size.height) * 0.68
            ZStack {
                Ellipse()
                    .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .frame(width: width, height: width * 1.3)
                CaptureRing(segments: GuidanceCopy.ringSegments(model.report), holdProgress: model.holdProgress)
                    .frame(width: width * 1.18, height: width * 1.18 * 1.3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .sensoryFeedback(Haptic.gatePassed, trigger: model.report?.passed.count ?? 0) { old, new in new > old }
    }

    private var controls: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Cancel scan")
                Spacer()
                Text("\(GuidanceCopy.title(for: angle)) · \(captured.count + 1) of 3")
                    .font(.ds.label)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .glassEffect()
            }
            Spacer(minLength: 0)
            Text(GuidanceCopy.text(for: model.hint))
                .font(.ds.titleSmall)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .dsAnimation(.smooth, value: model.hint)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .glassEffect(in: RoundedRectangle(cornerRadius: Radius.medium))
            AngleTray(captures: model.captures, current: angle)
            if model.canCaptureManually {
                Button("Take photo anyway") { model.captureManually() }
                    .buttonStyle(.dsPrimary)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if model.captureFailed {
                Text("That photo didn't take — hold still and we'll try again.")
                    .font(.ds.footnote).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(Spacing.md)
    }
}

private struct AngleTray: View {
    let captures: [CaptureAngle: UIImage]
    let current: CaptureAngle?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(ScanFlow.sequence, id: \.self) { angle in
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.small)
                        .fill(Color.white.opacity(0.12))
                    if let image = captures[angle] {
                        Image(uiImage: image).resizable().scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        Text(GuidanceCopy.title(for: angle)).font(.ds.caption).foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 64, height: 80)
                .overlay(RoundedRectangle(cornerRadius: Radius.small)
                    .strokeBorder(angle == current ? Color.ds.signal : .clear, lineWidth: 2))
                .accessibilityElement()
                .accessibilityLabel(Text("\(GuidanceCopy.title(for: angle)): \(captures[angle] == nil ? "not taken" : "taken")"))
            }
        }
        .dsAnimation(.expressive, value: captures.count)
    }
}

// MARK: - Review

private struct ReviewScreen: View {
    let model: ScanCaptureModel
    let captured: [CaptureAngle]
    let close: () -> Void
    let analyze: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Button("Cancel", action: close).foregroundStyle(.white)
                Spacer()
            }
            Text("Looking good").font(.ds.display).foregroundStyle(.white)
            Text("Retake any angle, or analyse now.").font(.ds.body).foregroundStyle(.white.opacity(0.75))
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.md) {
                    ForEach(ScanFlow.sequence, id: \.self) { angle in
                        VStack(spacing: Spacing.xs) {
                            if let image = model.captures[angle] {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 180, height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                                    .accessibilityLabel(Text("\(GuidanceCopy.title(for: angle)) photo"))
                            }
                            Button {
                                model.retake(angle)
                            } label: {
                                Text("Retake \(GuidanceCopy.title(for: angle).lowercased())")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ds.signal)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            Spacer()
            if model.canCapture3D {
                Button {
                    Task { await model.captureFaceMesh() }
                } label: {
                    if model.isCapturingMesh {
                        Label("Hold still — capturing 3D…", systemImage: "faceid")
                    } else if model.faceMesh != nil {
                        Label("3D view added", systemImage: "checkmark.circle.fill")
                    } else {
                        Label("Add a 3D view (2 seconds)", systemImage: "cube")
                    }
                }
                .buttonStyle(.dsSecondary)
                .foregroundStyle(.white)
                .disabled(model.isCapturingMesh || model.faceMesh != nil)
                if model.meshFailed {
                    Text("Couldn't capture 3D — you can still analyse without it.")
                        .font(.ds.footnote).foregroundStyle(.white.opacity(0.75))
                }
            }
            Button("Analyse my skin", action: analyze)
                .buttonStyle(.dsPrimary)
                .disabled(captured.count < ScanFlow.sequence.count)
        }
        .padding(Spacing.md)
    }
}

// MARK: - Analysis

private struct AnalyzingScreen: View {
    let image: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 240, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
                        .opacity(0.55)
                }
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                    ContourMotif(phase: reduceMotion ? 0 : phase * 1.2, rings: 9)
                        .stroke(Color.ds.signal, lineWidth: 1.2)
                        .frame(width: 220, height: 220)
                        .opacity(0.9)
                }
            }
            Text("Reading your skin…").font(.ds.title).foregroundStyle(.white)
            Text("Looking at each zone once, across all three photos.")
                .font(.ds.footnote)
                .foregroundStyle(.white.opacity(0.7))
            ProgressView().tint(.white)
        }
        .padding(Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Messages

private struct MessageScreen: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primary: (LocalizedStringKey, () -> Void)
    var secondary: (LocalizedStringKey, () -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: systemImage).font(.system(.largeTitle)).foregroundStyle(Color.ds.signal)
                .accessibilityHidden(true)
            Text(title).font(.ds.title).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(message).font(.ds.body).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            Spacer()
            Button(primary.0, action: primary.1).buttonStyle(.dsPrimary)
            if let secondary {
                Button(secondary.0, action: secondary.1).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 520)
    }
}
