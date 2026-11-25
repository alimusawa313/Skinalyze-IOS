import SwiftUI
import SkinalyzeKit

/// The scan, Face ID style: your face in a round camera window, ticks lighting around it as you turn your head, and
/// Pimpi coaching from the side. The window and the coaching are two panes, so on iPhone Duo they sit either side
/// of the fold (tabletop: window up, controls down) and in landscape they sit side by side.
struct ScanStage: View {
    let model: ScanCaptureModel
    let cancel: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The first scan after onboarding is coached a little more (ONBOARDING-PLAN.md §5.1); the scan itself is the same.
    @State private var isFirstScan = FirstScanCoaching.isPending

    private enum Metrics {
        static let window: CGFloat = 340
        /// Space between the tick ring and the camera circle.
        static let ringInset: CGFloat = 40
        static let pimpi: CGFloat = 116
        static let step: CGFloat = 40
    }

    var body: some View {
        AdaptivePair(.split) {
            VStack(spacing: Spacing.md) {
                Text(instruction)
                    .font(.ds.display)
                    .foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: instruction)
                    .accessibilityIdentifier("mirrorInstruction")
                window
            }
            .padding(Spacing.md)
        } secondary: {
            VStack(spacing: Spacing.lg) {
                if isFirstScan, model.captures.isEmpty, !model.isScanning3D {
                    FirstScanIntro(makes3D: model.supports3D)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                steps
                coach
                if model.canCaptureManually {
                    Button("Take photo anyway") { model.captureManually() }
                        .buttonStyle(.chunkyPlain)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Color.ds.canvas.ignoresSafeArea())
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: model.canCaptureManually)
    }

    private var header: some View {
        HStack {
            Label {
                Text(verbatim: "\(model.captures.count)/\(ScanFlow.sequence.count)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(model.captures.count)))
            } icon: {
                Image(systemName: "camera.fill")
            }
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: Chunk.iconButton)
            .dsSurface(radius: Chunk.iconButton / 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Scanning, \(model.captures.count) of 3 photos"))
            Spacer()
            Button(action: cancel) { Image(systemName: "xmark") }
                .buttonStyle(.chunkyIcon)
                .accessibilityLabel("Cancel scan")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: Camera window

    private var window: some View {
        let progress = model.ringProgress
        let ring = FaceRing(frontProgress: progress.front, rightProgress: progress.right, leftProgress: progress.left)
        return ZStack {
            ring
            Circle().fill(Color.ds.ink)
                .overlay {
                    if model.isPreviewing { CameraPreview(camera: model.camera) }
                }
                .clipShape(Circle())
                .padding(Metrics.ringInset)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: Metrics.window, maxHeight: Metrics.window)
        .keyframeAnimator(initialValue: 1.0, trigger: model.captures.count) { content, scale in
            content.scaleEffect(reduceMotion ? 1 : scale)
        } keyframes: { _ in
            SpringKeyframe(1.06, duration: 0.12, spring: .snappy)
            SpringKeyframe(1.0, duration: 0.5, spring: .bouncy(extraBounce: 0.2))
        }
        .sensoryFeedback(.selection, trigger: ring.litCount)
    }

    // MARK: Steps

    /// One check-off per photo, plus the 3D scan on iPhones that can make one.
    private var steps: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ForEach(ScanFlow.sequence, id: \.self) { angle in
                step(Text(GuidanceCopy.title(for: angle)), done: model.captures[angle] != nil)
            }
            if model.supports3D {
                step(Text(verbatim: "3D"), done: model.has3DScan)
            }
        }
    }

    private func step(_ title: Text, done: Bool) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: "checkmark")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(done ? Color.ds.canvas : Color.ds.hairline)
                .frame(width: Metrics.step, height: Metrics.step)
                .dsSurface(radius: Metrics.step / 2, fill: done ? Color.ds.positive : Color.ds.surface)
                .symbolEffect(.bounce, value: done)
            title
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? Text("Done") : Text("Not done"))
    }

    // MARK: Pimpi

    private var coach: some View {
        HStack(spacing: Spacing.xs) {
            Pimpi(mood: model.isScanning3D ? .happy : .curious)
                .frame(width: Metrics.pimpi, height: Metrics.pimpi)
            SpeechBubble(Text(coachLine), tail: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var coachLine: LocalizedStringResource {
        if model.isScanning3D { return isFirstScan ? "Hold still a second. I'm making your 3D head." : "Freeze! Statue mode." }
        if isFirstScan {
            switch model.captures.count {
            case 0: return "Look straight at me. I'll take it when you're still."
            case 1: return "Now turn your head slowly, like a sunflower."
            default: return "Last one: the other way. Nearly done!"
            }
        }
        switch model.captures.count {
        case 0: return "Eyes on me. I'm the cute one."
        case 1: return "Slowly. Like a sunflower."
        default: return "Other cheek's turn."
        }
    }

    private var instruction: String {
        if model.isScanning3D { return String(localized: "Hold still — 3D scan…") }
        if let hint = model.hint, hint != .turnHeadLeft, hint != .turnHeadRight { return GuidanceCopy.text(for: hint) }
        if model.captures[.front] == nil { return String(localized: "Look at me.") }
        return model.captures.count == 1 ? String(localized: "Slowly turn your head.") : String(localized: "Now the other way.")
    }
}

/// Before the first scan's first photo: the three poses, in order, so nothing comes as a surprise.
private struct FirstScanIntro: View {
    let makes3D: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Three quick poses")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
            HStack(spacing: Spacing.sm) {
                pose("face.smiling", "Look at me")
                pose("arrow.turn.up.right", "Turn one way")
                pose("arrow.turn.up.left", "Then the other")
            }
            Text(makes3D ? "Hold still when I ask: that's your 3D head being made." : "I take each photo by myself when you're still.")
                .font(.ds.footnote.weight(.semibold))
                .foregroundStyle(Color.ds.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface(radius: Radius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("firstScanIntro")
    }

    private func pose(_ symbol: String, _ title: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.ds.signal)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
