import AudioToolbox
import SwiftData
import SwiftUI
import SkinalyzeKit

/// Home is a mirror: the live front camera, graded and full-bleed, with your last scan's active zones glowing on your
/// live face. The shutter ring scans in place — Face ID style — and the result opens as a new card.
struct MirrorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @AppStorage(UserProfile.Key.name) private var name = ""
    /// Owned by the shell so the camera survives dock paging, folding and rotation.
    let model: ScanCaptureModel

    private var latest: ScanSession? { scans.first }
    private var band: BreakoutBand { latest?.band ?? .calm }

    private var isScanning: Bool {
        switch model.state {
        case .capturing, .reviewing, .analyzing: true
        default: false
        }
    }

    var body: some View {
        ZStack {
            MirrorBackdrop(model: model, band: band)
            if model.isPreviewing, !isScanning, let latest {
                MirrorZoneGlows(face: model.liveFace, session: latest)
            }
            overlay
            CaptureFlash(trigger: model.captures.count)
        }
        .task { await model.startPreview() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.resume()
            case .background: model.pause()
            default: break
            }
        }
        .onChange(of: isScanning) { _, scanning in appModel.isScanning = scanning }
        .onChange(of: appModel.pendingScan, initial: true) { _, pending in
            guard pending else { return }
            appModel.pendingScan = false
            model.beginScan()
        }
        .onChange(of: model.state) { _, state in
            guard state == .finished else { return }
            appModel.scanFinished(model.savedSessionID)
            let container = modelContext.container
            Task {
                await WidgetSummary.refresh(from: container)
                await ScanReminders.rescheduleIfEnabled()
            }
            model.returnToMirror()
        }
        .sensoryFeedback(Haptic.capture, trigger: model.captures.count)
        .sensoryFeedback(Haptic.success, trigger: model.state == .finished)
    }

    @ViewBuilder private var overlay: some View {
        switch model.state {
        case let .reviewing(captured):
            ReviewScreen(model: model, captured: captured, close: { model.returnToMirror() }) {
                Task { await model.confirm(productIDs: UserProfile.currentProductIDs, container: modelContext.container) }
            }
            .background(Color.black.opacity(0.88).ignoresSafeArea())
            .environment(\.colorScheme, .dark) // capture review stays dark, like the system camera
            .transition(.opacity)
        case .analyzing, .finished:
            AnalyzingScreen(image: model.captures[.front])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.88).ignoresSafeArea())
                .environment(\.colorScheme, .dark)
        case .permissionDenied:
            MessageScreen(systemImage: "camera", title: "Camera access is off",
                          message: "Skinalyze uses the front camera as your mirror. Photos stay on this iPhone.",
                          primary: ("Open Settings", openSettings))
        case .failed:
            MessageScreen(systemImage: "exclamationmark.triangle", title: "We couldn't read these photos",
                          message: "Your photos are still here. Try again, or retake them in softer light.",
                          primary: ("Try again", {
                              Task { await model.retryAnalysis(productIDs: UserProfile.currentProductIDs, container: modelContext.container) }
                          }),
                          secondary: ("Back to mirror", { model.returnToMirror() }))
        default:
            MirrorChrome(model: model, latest: latest, name: name, isScanning: isScanning,
                         showProfile: { appModel.isShowingProfile = true },
                         openLatest: { latest.map { appModel.presentedScan = .init(id: $0.persistentModelID) } })
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

/// Live camera (or a breathing mood-gradient stand-in), graded dark and tinted by your skin's mood.
private struct MirrorBackdrop: View {
    let model: ScanCaptureModel
    let band: BreakoutBand
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if model.isPreviewing {
                CameraPreview(camera: model.camera)
            } else {
                LivingBackground(band: band)
            }
            LinearGradient(colors: [Color.ds.canvas.opacity(0.75), .clear, .clear, Color.ds.canvas.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            RadialGradient(colors: [.clear, Color.ds.band(band).opacity(0.4)], center: .center,
                           startRadius: 140, endRadius: 560)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// Last scan's active zones, tracked onto your live face.
private struct MirrorZoneGlows: View {
    let face: ImageRect?
    let session: ScanSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if let face {
                ForEach(FaceZone.allCases.filter { session.zoneIndex($0) > 0 }, id: \.self) { zone in
                    let point = MirrorMapping.screenPoint(face: face, zone: zone, in: proxy.size)
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.85), Color.ds.band(session.band).opacity(0.65), .clear],
                                             center: .center, startRadius: 0, endRadius: 28))
                        .frame(width: 56, height: 56)
                        .blendMode(.plusLighter)
                        .position(point)
                        .animation(reduceMotion ? nil : .interpolatingSpring(duration: 0.25), value: point)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Giant index + sentence on top, shutter ring at the bottom.
private struct MirrorChrome: View {
    let model: ScanCaptureModel
    let latest: ScanSession?
    let name: String
    let isScanning: Bool
    let showProfile: () -> Void
    let openLatest: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var indexSize: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Counts up to the real index on arrival — a small hello every time you open the app.
    @State private var shownIndex = 0
    @ScaledMetric(relativeTo: .largeTitle) private var greetingSize: CGFloat = 54

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.md) {
                headline
                    .foregroundStyle(Color.ds.ink)
                    .shadow(color: Color.ds.canvas.opacity(0.6), radius: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isScanning {
                    Button { model.returnToMirror() } label: {
                        Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Cancel scan")
                } else {
                    Button(action: showProfile) { Avatar(name: name) }
                        .accessibilityLabel("Profile and settings")
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            Spacer(minLength: Spacing.md)
            MirrorShutter(model: model, isScanning: isScanning)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 96)
        }
    }

    @ViewBuilder private var headline: some View {
        if isScanning {
            Text(instruction)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .contentTransition(.opacity)
                .animation(.smooth, value: instruction)
                .accessibilityIdentifier("mirrorInstruction")
        } else if let latest {
            Button(action: openLatest) {
                VStack(alignment: .leading, spacing: 0) {
                Text(shownIndex, format: .number)
                    .font(.system(size: indexSize, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(shownIndex)))
                    .onAppear { countUp(to: latest.breakoutIndex) }
                    .onChange(of: latest.breakoutIndex) { _, value in countUp(to: value) }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("\(BandCopy.title(latest.band)) · breakout index").font(.ds.headline).opacity(0.85)
            }
            .multilineTextAlignment(.leading)
            .contentShape(Rectangle())
            }
            .buttonStyle(.bouncy(0.95))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens your latest scan")
            .accessibilityIdentifier("mirrorIndex")
        } else {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name.isEmpty ? "Hey." : "Hey, \(name).")
                    .font(.system(size: greetingSize, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                Text("Let's meet your skin.").font(.ds.title).opacity(0.85)
            }
        }
    }

    private func countUp(to value: Int) {
        withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation.delay(0.15)) { shownIndex = value }
    }

    private var instruction: String {
        if let hint = model.hint, hint != .turnHeadLeft, hint != .turnHeadRight { return GuidanceCopy.text(for: hint) }
        if model.captures[.front] == nil { return String(localized: "Look at me.") }
        return model.captures.count == 1 ? String(localized: "Slowly turn your head.") : String(localized: "Now the other way.")
    }
}

/// The huge Face ID-style tick ring; tap to scan in place.
private struct MirrorShutter: View {
    let model: ScanCaptureModel
    let isScanning: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        let progress = model.ringProgress
        let ring = FaceRing(frontProgress: isScanning ? progress.front : 0,
                            rightProgress: isScanning ? progress.right : 0,
                            leftProgress: isScanning ? progress.left : 0)
        VStack(spacing: Spacing.md) {
            Button { model.beginScan() } label: {
                ZStack {
                    ring.frame(width: 200, height: 200)
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 124, height: 124)
                        .overlay {
                            if isScanning {
                                Text("\(model.captures.count)/3")
                                    .font(.system(.title, design: .rounded).weight(.heavy))
                                    .monospacedDigit()
                                    .contentTransition(.numericText(value: Double(model.captures.count)))
                            } else {
                                Image(systemName: "faceid").font(.system(size: 48))
                            }
                        }
                        .foregroundStyle(Color.ds.ink)
                        .scaleEffect(breathing && !isScanning && !reduceMotion ? 1.06 : 1)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: breathing)
                }
            }
            .buttonStyle(.bouncy(0.9))
            .keyframeAnimator(initialValue: 1.0, trigger: model.captures.count) { content, scale in
                content.scaleEffect(reduceMotion ? 1 : scale)
            } keyframes: { _ in
                SpringKeyframe(1.16, duration: 0.12, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy(extraBounce: 0.2))
            }
            .disabled(isScanning || !model.isPreviewing)
            .accessibilityIdentifier("mirrorShutter")
            .accessibilityLabel(isScanning ? Text("Scanning, \(model.captures.count) of 3 photos") : Text("Scan my skin"))
            .sensoryFeedback(.selection, trigger: ring.litCount)

            if model.cameraUnavailable {
                Text("Camera unavailable — scan on a real iPhone.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            } else if isScanning, model.canCaptureManually {
                Button("Take photo anyway") { model.captureManually() }
                    .buttonStyle(.glass)
            }
        }
        .onAppear { breathing = true }
    }
}

/// Maps Vision face boxes (normalized, origin bottom-left, unmirrored buffer) onto the mirrored aspect-fill preview.
enum MirrorMapping {
    /// Portrait photo-preset frames (width / height).
    static let bufferAspect: CGFloat = 3.0 / 4.0

    static func screenPoint(face: ImageRect, zone: FaceZone, in size: CGSize) -> CGPoint {
        let (u, v) = canonical(zone)
        let nx = face.x + face.width * u
        let ny = face.y + face.height * (1 - v)
        let displayedWidth = max(size.height * bufferAspect, size.width)
        let displayedHeight = displayedWidth / bufferAspect
        let offsetX = (displayedWidth - size.width) / 2
        let offsetY = (displayedHeight - size.height) / 2
        return CGPoint(x: (1 - nx) * displayedWidth - offsetX, y: (1 - ny) * displayedHeight - offsetY)
    }

    /// Zone centre in face-box space (u across the image, v from the top).
    private static func canonical(_ zone: FaceZone) -> (Double, Double) {
        switch zone {
        case .forehead: (0.5, 0.15)
        case .nose: (0.5, 0.5)
        case .rightCheek: (0.25, 0.55)
        case .leftCheek: (0.75, 0.55)
        case .chin: (0.5, 0.92)
        case .rightJaw: (0.15, 0.8)
        case .leftJaw: (0.85, 0.8)
        }
    }
}

/// A soft white blink on every capture, like a shutter — skipped under Reduce Motion.
private struct CaptureFlash: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.white
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, opacity in
                content.opacity(reduceMotion || trigger == 0 ? 0 : opacity)
            } keyframes: { _ in
                LinearKeyframe(0.55, duration: 0.06)
                CubicKeyframe(0, duration: 0.35)
            }
    }
}
