import Observation
import OSLog
import SwiftData
import UIKit
import SkinalyzeKit

/// Drives a scan: permission → gated auto-capture of front/right/left → review → analysis → save.
/// UI state only; the camera works on its own queues and analysis runs off the main actor.
@Observable
@MainActor
final class ScanCaptureModel {
    static let manualCaptureDelay: TimeInterval = 8
    /// The front photo is also the 3D scan: hold a little longer so a burst of depth frames can be fused.
    static let frontHold3D: TimeInterval = 0.8
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Scan")

    private(set) var state: ScanFlowState = .idle
    private(set) var report: GateReport?
    private(set) var holdProgress: Double = 0
    private(set) var captures: [CaptureAngle: UIImage] = [:]
    private(set) var isCapturing = false
    private(set) var canCaptureManually = false
    private(set) var cameraUnavailable = false
    private(set) var captureFailed = false
    private(set) var savedSessionID: PersistentIdentifier?

    let camera = CameraSession()
    private var tracker = StabilityTracker()
    private var angleStartedAt: TimeInterval?
    private var latestTimestamp: TimeInterval = 0
    private var frameTask: Task<Void, Never>?

    var currentAngle: CaptureAngle? {
        if case let .capturing(angle, _) = state { return angle }
        return nil
    }

    /// Debounced so the instruction never flickers (it changes only after a new hint has persisted ~0.6 s).
    var hint: GuidanceHint? { hintStabilizer.displayed }
    private var hintStabilizer = HintStabilizer()
    /// The angle the current frames are being matched against (front, or whichever side the user turned to).
    private(set) var targetAngle: CaptureAngle?
    /// Live head yaw (degrees, + = turned right) driving the Face ID-style ring.
    private(set) var liveYaw: Double = 0

    /// Ring progress per arc (0…1): captured arcs are full; the active arc fills as the head turns toward it.
    var ringProgress: (front: Double, right: Double, left: Double) {
        let target = GateThresholds.default.sideYaw.lowerBound
        func side(_ angle: CaptureAngle, sign: Double) -> Double {
            if captures[angle] != nil { return 1 }
            guard captures[.front] != nil else { return 0 }
            return min(max(liveYaw * sign / target, 0), 1) * 0.85 + (targetAngle == angle ? holdProgress * 0.15 : 0)
        }
        let front = captures[.front] != nil ? 1 : (targetAngle == .front ? max(holdProgress, report?.passed.count == CaptureGate.allCases.count ? 0.5 : 0.15) : 0)
        return (front, side(.right, sign: 1), side(.left, sign: -1))
    }

    // MARK: - Mirror (camera as the home screen)

    /// Live face box (Vision coords) for overlays on the Mirror, updated every analysed frame.
    private(set) var liveFace: ImageRect?
    private(set) var isPreviewing = false

    /// Runs the camera as a live mirror without starting a scan (no auto-capture while idle).
    func startPreview() async {
        guard !isPreviewing else { camera.start(); return }
        let granted: Bool = switch CameraSession.authorizationStatus() {
        case .authorized: true
        case .notDetermined: await CameraSession.requestAccess()
        default: false
        }
        guard granted else { send(.start); send(.permissionDenied); return }
        do {
            try await camera.configure()
        } catch {
            cameraUnavailable = true
            return
        }
        isPreviewing = true
        camera.start()
        listenToFrames()
    }

    /// Starts a scan in place on the already-running mirror camera.
    func beginScan() {
        guard isPreviewing, state == .idle || state == .finished else { return }
        captures = [:]
        frontDepth = nil
        sideDepths = [:]
        savedSessionID = nil
        resetHold()
        state = .idle
        send(.start)
        send(.permissionGranted)
        camera.setCollectingDepth(supports3D)
        camera.start()
    }

    /// Back to the plain mirror (after a scan finishes or is cancelled).
    func returnToMirror() {
        camera.setCollectingDepth(false)
        captures = [:]
        frontDepth = nil
        resetHold()
        state = .idle
        if isPreviewing { camera.start() }
    }

    // MARK: - Lifecycle

    /// Called when the app leaves/returns to the foreground or the device folds/unfolds: captured angles are kept.
    func pause() {
        camera.stop()
        resetHold()
        send(.interrupted)
    }

    func resume() {
        switch state {
        case .capturing: camera.start()
        case .idle where isPreviewing: camera.start()
        default: break
        }
    }

    /// The Mirror is off screen (another dock page): stop the camera unless a scan is mid-capture.
    func setMirrorVisible(_ visible: Bool) {
        guard isPreviewing else { return }
        if visible {
            resume()
        } else if case .capturing = state {
            return
        } else {
            camera.stop()
        }
    }

    // MARK: - Capture

    func captureManually() {
        guard let angle = currentAngle else { return }
        Task { await capture(angle) }
    }

    func retake(_ angle: CaptureAngle) {
        captures[angle] = nil
        if angle == .front {
            frontDepth = nil
            camera.setCollectingDepth(supports3D)
        }
        send(.retake(angle))
        resetHold()
        camera.start()
    }

    private func listenToFrames() {
        frameTask?.cancel()
        let frames = camera.frames
        frameTask = Task { [weak self] in
            for await sample in frames {
                guard let self, !Task.isCancelled else { return }
                self.handle(sample)
            }
        }
    }

    private func handle(_ sample: FrameSample) {
        latestTimestamp = sample.timestamp
        liveFace = sample.face?.bounds
        guard let expected = currentAngle, !isCapturing else { return }
        // After the front photo, accept whichever side the user turns to first (like Face ID enrollment).
        let candidates: [CaptureAngle] = expected == .front
            ? [.front]
            : [CaptureAngle.right, .left].filter { captures[$0] == nil }
        let evaluated = candidates.map { ($0, GateEvaluator.evaluate(face: sample.face, quality: sample.quality, angle: $0)) }
        let (angle, report) = evaluated.first { $0.1.allPassed } ?? evaluated.first ?? (expected, GateReport(passed: [], hint: .noFace))
        self.report = report
        liveYaw = sample.face?.yawDegrees ?? liveYaw
        if targetAngle != angle { tracker = makeTracker(for: angle) }
        targetAngle = angle
        hintStabilizer = hintStabilizer.updated(candidate: report.hint, at: sample.timestamp)
        tracker = tracker.updated(allPassed: report.allPassed, at: sample.timestamp)
        holdProgress = tracker.progress(at: sample.timestamp)
        angleStartedAt = angleStartedAt ?? sample.timestamp
        canCaptureManually = sample.timestamp - (angleStartedAt ?? sample.timestamp) >= Self.manualCaptureDelay
        logCalibration(sample, report: report, angle: angle)
        if tracker.isReady(at: sample.timestamp) {
            Task { await capture(angle) }
        }
    }

    #if DEBUG
    private var lastLog: TimeInterval = 0
    #endif

    /// Debug builds print live gate numbers (read with `devicectl … --console`) to calibrate thresholds on real hardware.
    private func logCalibration(_ sample: FrameSample, report: GateReport, angle: CaptureAngle) {
        #if DEBUG
        guard sample.timestamp - lastLog >= 0.5 else { return }
        lastLog = sample.timestamp
        let f = sample.face
        let q = sample.quality
        print(String(format: "[scan] %@ face=%@ w=%.2f cx=%.2f cy=%.2f yaw=%.0f pitch=%.0f roll=%.0f luma=%.0f clip=%.2f sharp=%.1f motion=%.2f passed=%d hint=%@",
                     angle.rawValue, f == nil ? "no" : "yes", f?.bounds.width ?? 0, f.map { $0.bounds.x + $0.bounds.width / 2 } ?? 0,
                     f.map { $0.bounds.y + $0.bounds.height / 2 } ?? 0, f?.yawDegrees ?? 0, f?.pitchDegrees ?? 0, f?.rollDegrees ?? 0,
                     q.meanLuma, q.clippedFraction, q.sharpness, q.motion, report.passed.count, report.hint?.rawValue ?? "ok"))
        #endif
    }

    private func capture(_ angle: CaptureAngle) async {
        guard !isCapturing, captures[angle] == nil, currentAngle != nil else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            // Every shot carries its TrueDepth depth map: the front one is the 3D scan today; the side ones are kept so
            // the cheeks/jaw can be added from their own view (multi-view merge).
            let photo = try await camera.capturePhoto(withDepth: true)
            captures[angle] = photo.image
            sideDepths[angle] = angle == .front ? nil : photo.depth
            #if DEBUG
            if angle != .front {
                print("[scan] \(angle.rawValue) depth:", photo.depth.map { "\($0.width)x\($0.height)" } ?? "none")
            }
            #endif
            if angle == .front {
                camera.setCollectingDepth(false)
                frontDepth = photo.depth
                #if DEBUG
                print("[scan] front depth:", photo.depth.map { "\($0.width)x\($0.height) intrinsics=\($0.intrinsics != nil)" } ?? "none",
                      "supportsDepth=\(camera.supportsDepth)")
                #endif
            }
            captureFailed = false
            send(.captured(angle))
            resetHold()
            if case .reviewing = state { camera.stop() }
        } catch {
            Self.logger.error("Photo capture failed: \(error.localizedDescription)")
            captureFailed = true
            resetHold()
        }
    }

    private func makeTracker(for angle: CaptureAngle) -> StabilityTracker {
        StabilityTracker(holdDuration: angle == .front && supports3D ? Self.frontHold3D : StabilityTracker().holdDuration)
    }

    /// True while lining up the front photo on a TrueDepth iPhone (the 3D scan is happening).
    var isScanning3D: Bool { supports3D && captures[.front] == nil && targetAngle == .front && holdProgress > 0 }

    private func resetHold() {
        tracker = StabilityTracker()
        holdProgress = 0
        angleStartedAt = nil
        canCaptureManually = false
        report = nil
        hintStabilizer = HintStabilizer()
        targetAngle = nil
    }

    // MARK: - 3D (TrueDepth iPhones; never on iPhone Duo)

    /// Depth map captured with the front photo (nil on iPhone Duo / devices without TrueDepth).
    private(set) var frontDepth: DepthMap?
    /// Depth captured with the left/right photos (not yet merged into the model; recorded for the multi-view work).
    private var sideDepths: [CaptureAngle: DepthMap] = [:]
    /// The device scans in 3D (TrueDepth front camera).
    var supports3D: Bool { camera.supportsDepth }
    var has3DScan: Bool { frontDepth != nil }

    /// Fuses front + side captures into one head mesh (nil when there are no usable sides or they can't be registered).
    private static func buildFusedMesh(front: UIImage, frontDepth: DepthMap, captures: [CaptureAngle: UIImage],
                                       sideDepths: [CaptureAngle: DepthMap]) async -> FaceMeshDraft? {
        let sides = [CaptureAngle.right, .left].compactMap { angle -> MultiViewScanBuilder.Capture? in
            guard let image = captures[angle], let depth = sideDepths[angle] else { return nil }
            return MultiViewScanBuilder.Capture(image: image, depth: depth)
        }
        guard !sides.isEmpty else { return nil }
        // Detached on purpose: Vision landmarks, registration and texture baking must not run on the main actor.
        return await Task.detached(priority: .userInitiated) {
            let fused = MultiViewScanBuilder.build(front: .init(image: front, depth: frontDepth), sides: sides)
            #if DEBUG
            print("[scan] multi-view fusion:", fused.map { "registered sides at \($0.sideYawDegrees.map { Int($0.rounded()) })°, \($0.mesh.vertices.count) vertices" } ?? "not possible — front-only scan")
            #endif
            return fused?.mesh
        }.value
    }

    /// Builds the real face mesh from the front photo's depth, textured with that photo. Off the main actor.
    private static func buildFaceMesh(depth: DepthMap, front: UIImage, faceBox: ImageRect) async -> FaceMeshDraft? {
        // Detached on purpose: meshing ~20k points and encoding the texture must not run on the main actor.
        await Task.detached(priority: .userInitiated) {
            // Trim only the wall behind and the shoulders; the face, cheeks and ears keep their real depth.
            guard let texture = uprightTexture(front) else { return nil }
            return DepthMeshBuilder.build(depth: depth, faceBox: faceBox, texture: texture,
                                          mask: FaceMaskMaker.trimMask(from: front))
        }.value
    }

    /// Upright, ≤ 2048 px JPEG for the 3D texture (RealityKit ignores EXIF orientation).
    nonisolated private static func uprightTexture(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 2048
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.85)
    }

    // MARK: - Analysis

    func confirm(productIDs: [Int], container: ModelContainer) async {
        send(.confirm)
        guard state == .analyzing else { return }
        await analyze(productIDs: productIDs, container: container)
    }

    func retryAnalysis(productIDs: [Int], container: ModelContainer) async {
        send(.retryAnalysis)
        guard state == .analyzing else { return }
        await analyze(productIDs: productIDs, container: container)
    }

    private func analyze(productIDs: [Int], container: ModelContainer) async {
        camera.stop()
        let prepared = ScanFlow.sequence.compactMap { angle in
            captures[angle].flatMap { ScanAnalyzer.prepare($0, angle: angle) }
        }
        guard prepared.count == ScanFlow.sequence.count else {
            send(.analysisFailed("photos"))
            return
        }
        do {
            let analysis = try await ScanAnalyzer.analyze(prepared, productIDs: productIDs)
            var faceMesh: FaceMeshDraft?
            var pins: [FacePin] = []
            #if DEBUG
            Debug3DDump.write(captures: captures, depths: sideDepths.merging(frontDepth.map { [.front: $0] } ?? [:]) { a, _ in a },
                              frontFace: analysis.frontFace)
            #endif
            if let frontDepth, let front = captures[.front] {
                // Best: fuse the three views into one head with real sides. Otherwise: the front-only scan.
                faceMesh = await Self.buildFusedMesh(front: front, frontDepth: frontDepth, captures: captures, sideDepths: sideDepths)
                if faceMesh == nil, let frontFace = analysis.frontFace {
                    faceMesh = await Self.buildFaceMesh(depth: frontDepth, front: front, faceBox: frontFace)
                }
                if faceMesh == nil { Self.logger.error("3D mesh could not be built from this depth map") }
                #if DEBUG
                print("[scan] 3D mesh:", faceMesh.map { "\($0.vertices.count) vertices, \($0.indices.count / 3) triangles" } ?? "none")
                #endif
            }
            if let faceMesh, let frontFace = analysis.frontFace {
                pins = FacePinMapper.pins(for: analysis.draft.detections, photoFace: frontFace, mesh: faceMesh)
            }
            savedSessionID = try await ScanStore(modelContainer: container)
                .save(analysis.draft, faceMesh: faceMesh, pins: pins)
            send(.analysisSucceeded)
        } catch {
            Self.logger.error("Analysis failed: \(error.localizedDescription)")
            send(.analysisFailed(error.localizedDescription))
        }
    }

    private func send(_ event: ScanFlowEvent) {
        state = ScanFlow.reduce(state, event)
    }
}

#if DEBUG
/// Debug builds save each scan's raw inputs (photos + depth maps) to Documents/debug3d so the 3D pipeline can be
/// developed and verified offline on real captures before anything ships. Never compiled into release builds.
enum Debug3DDump {
    static let maximumDumps = 3
    static func write(captures: [CaptureAngle: UIImage], depths: [CaptureAngle: DepthMap], frontFace: ImageRect?) {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        Task.detached(priority: .utility) {
            guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let folder = documents.appendingPathComponent("debug3d/\(stamp)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for (angle, image) in captures {
                    try image.jpegData(compressionQuality: 0.92)?.write(to: folder.appendingPathComponent("\(angle.rawValue).jpg"))
                }
                for (angle, depth) in depths {
                    try depth.meters.withUnsafeBufferPointer { Data(buffer: $0) }
                        .write(to: folder.appendingPathComponent("\(angle.rawValue).depth"))
                    let k = depth.intrinsics
                    let meta = "{\"width\": \(depth.width), \"height\": \(depth.height), \"fx\": \(k?.fx ?? 0), \"fy\": \(k?.fy ?? 0), "
                        + "\"cx\": \(k?.cx ?? 0), \"cy\": \(k?.cy ?? 0), \"imageOrientation\": \(captures[angle]?.imageOrientation.rawValue ?? -1)}"
                    try Data(meta.utf8).write(to: folder.appendingPathComponent("\(angle.rawValue).json"))
                }
                if let frontFace {
                    try Data("\(frontFace.x) \(frontFace.y) \(frontFace.width) \(frontFace.height)".utf8)
                        .write(to: folder.appendingPathComponent("frontFace.txt"))
                }
                print("[scan] debug3d dump:", folder.lastPathComponent, "depths:", depths.keys.map(\.rawValue).sorted())
                // Keep only the most recent dumps (each is several megabytes).
                let root = folder.deletingLastPathComponent()
                let all = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))?.sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []
                for old in all.dropFirst(maximumDumps) { try? FileManager.default.removeItem(at: old) }
            } catch {
                print("[scan] debug3d dump failed:", error.localizedDescription)
            }
        }
    }
}
#endif
