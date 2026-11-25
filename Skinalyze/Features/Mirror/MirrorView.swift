import AudioToolbox
import SwiftData
import SwiftUI
import SkinalyzeKit

/// The first page of the dock. At rest it is Pimpi's place (`HomePlace`); asking for a scan opens the camera and the
/// scan runs in place (`ScanStage`) — never pushed on a stack, so folding, unfolding or rotating can't pop it. The
/// result then opens as a sheet from the shell.
struct MirrorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @AppStorage(UserProfile.Key.name) private var name = ""
    @AppStorage("routineLog") private var routineLogRaw = ""
    @Environment(EngagementModel.self) private var engagement
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(QuestModel.self) private var quests: QuestModel?
    @State private var paywall: PaywallReason?
    /// Owned by the shell so a scan survives dock paging, folding and rotation.
    let model: ScanCaptureModel

    /// Set when a scan's analysis has saved: the sticker sticks onto this colour, then the result opens.
    @State private var finishedBand: BreakoutBand?
    #if DEBUG
    /// `-stickerDemo`: replays the sticker moment on the latest scan (the Simulator has no camera).
    @State private var demoPhoto: UIImage?
    @State private var demoBand: BreakoutBand?
    /// `-scanStageDemo YES`: shows the scan screen without a camera, for layout checks in the Simulator.
    @State private var showsStageDemo = UserDefaults.standard.bool(forKey: "scanStageDemo")
    #endif

    private var latest: ScanSession? { scans.first }

    /// When today's free scan is used: the moment the next one opens.
    private var nextFreeScan: Date? {
        let policy = access?.policy ?? AccessPolicy(hasFullAccess: true)
        guard case let .limitReached(next) = policy.scanAllowance(savedScanDates: scans.map(\.createdAt),
                                                                  now: .now, calendar: .current) else { return nil }
        return next
    }

    private var scannedToday: Bool {
        scans.contains { Calendar.current.isDateInToday($0.createdAt) }
    }

    private func requestScan() {
        if let nextFreeScan {
            paywall = .scanLimit(nextFreeScan: nextFreeScan)
        } else {
            Task { await model.startScan() }
        }
    }

    private var isScanning: Bool {
        switch model.state {
        case .capturing, .reviewing, .analyzing, .finished: true
        default: false
        }
    }

    /// The scan screen is up from the moment the camera is asked for until the user is back home.
    private var showsStage: Bool {
        #if DEBUG
        if showsStageDemo { return true }
        #endif
        return model.isStageOpen || isScanning
    }

    var body: some View {
        ZStack {
            if showsStage {
                ScanStage(model: model, cancel: leaveScan)
                    .transition(.opacity)
            } else {
                HomePlace(latest: latest, name: name, scannedToday: scannedToday, nextFreeScan: nextFreeScan,
                          cameraUnavailable: model.cameraUnavailable, requestScan: requestScan,
                          showProfile: { appModel.isShowingProfile = true },
                          openLatest: { latest.map { appModel.presentedScan = .init(id: $0.persistentModelID) } })
                    .transition(.opacity)
            }
            overlay
            CaptureFlash(trigger: model.captures.count)
            #if DEBUG
            if let demoPhoto {
                StickerMakingView(photo: demoPhoto, band: demoBand) { self.demoPhoto = nil; demoBand = nil }
                    .environment(\.colorScheme, .dark)
            }
            #endif
        }
        .animation(MotionToken.smooth.resolved(reduceMotion: reduceMotion).animation, value: showsStage)
        .onChange(of: scans.count, initial: true) { _, _ in refreshEngagement() }
        #if DEBUG
        .task { await playStickerDemoIfRequested() }
        #endif
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.resume()
                refreshEngagement()
            case .background: model.pause()
            default: break
            }
        }
        .onChange(of: showsStage) { _, showing in appModel.isScanning = showing }
        .paywallSheet($paywall)
        .onChange(of: appModel.pendingScan, initial: true) { _, pending in
            guard pending else { return }
            appModel.pendingScan = false
            requestScan()
        }
        .onChange(of: model.state) { _, state in
            guard state == .finished else { return }
            let saved = model.savedSessionID.flatMap { modelContext.model(for: $0) as? ScanSession }
            finishedBand = saved?.band ?? .calm // the sticker now sticks; `finishScan` opens the result
            let container = modelContext.container
            Task {
                await WidgetSummary.refresh(from: container)
            }
        }
        .onChange(of: model.captures.count) { old, new in
            if new > old { AudioCue.capture() } // shutter sound with every photo
        }
        .sensoryFeedback(Haptic.capture, trigger: model.captures.count)
        .sensoryFeedback(Haptic.success, trigger: model.state == .finished)
    }

    @ViewBuilder private var overlay: some View {
        switch model.state {
        case let .reviewing(captured):
            ReviewScreen(model: model, captured: captured, close: leaveScan) {
                Task { await model.confirm(productIDs: UserProfile.currentProductIDs, container: modelContext.container) }
            }
            .background(Color.ds.canvas.ignoresSafeArea())
            .transition(.opacity)
        case .analyzing, .finished:
            StickerMakingView(photo: model.captures[.front], band: finishedBand, onDone: finishScan)
                .environment(\.colorScheme, .dark)
        case .permissionDenied:
            MessageScreen(systemImage: "camera", title: "Camera access is off",
                          message: "Skinalyze uses the front camera as your mirror. Photos stay on this iPhone.",
                          primary: ("Open Settings", openSettings),
                          secondary: ("Not now", leaveScan))
                .background(Color.ds.canvas.ignoresSafeArea())
        case .failed:
            MessageScreen(systemImage: "exclamationmark.triangle", title: "We couldn't read these photos",
                          message: "Your photos are still here. Try again, or retake them in softer light.",
                          primary: ("Try again", {
                              Task { await model.retryAnalysis(productIDs: UserProfile.currentProductIDs, container: modelContext.container) }
                          }),
                          secondary: ("Not now", leaveScan))
                .background(Color.ds.canvas.ignoresSafeArea())
        default:
            EmptyView()
        }
    }

    private func refreshEngagement() {
        engagement.refresh(scanDates: scans.map(\.createdAt), routineLogRaw: routineLogRaw)
    }

    /// Back to Pimpi's place; the camera stops.
    private func leaveScan() {
        #if DEBUG
        showsStageDemo = false
        #endif
        model.leaveScan()
    }

    private func finishScan() {
        engagement.scanCompleted()
        if model.savedSessionID != nil { quests?.did(.scan, isPro: access?.policy.hasFullAccess ?? false) }
        appModel.scanFinished(model.savedSessionID)
        model.leaveScan()
        finishedBand = nil
    }

    #if DEBUG
    private func playStickerDemoIfRequested() async {
        guard UserDefaults.standard.bool(forKey: "stickerDemo") else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard let latest, let photo = latest.uiImage(at: 0) else { return }
        demoPhoto = photo
        // Real analysis is often done in under a second — before the sticker has even lifted.
        try? await Task.sleep(for: .seconds(0.6))
        demoBand = latest.band
    }
    #endif

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
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
