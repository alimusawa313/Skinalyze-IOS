import AVFoundation
import OSLog
import UIKit
import Vision
import SkinalyzeKit

/// A captured photo plus, on TrueDepth iPhones, its depth map (aligned with the upright photo).
struct CapturedPhoto: @unchecked Sendable {
    let image: UIImage
    let depth: DepthMap?
}

/// One analysed preview frame: face geometry + quality, ready for `GateEvaluator`.
struct FrameSample: Sendable {
    let face: FaceMeasurement?
    let quality: FrameQuality
    let timestamp: TimeInterval
}

/// Owns the AVFoundation capture pipeline for scanning.
///
/// Concurrency invariant (why `@unchecked Sendable` is safe): every `AVCaptureSession` configuration/start/stop and all
/// mutable capture state is touched only on `sessionQueue`; frame-analysis state only on `videoQueue`; the photo
/// continuation only on `sessionQueue`. Removal plan: convert to an actor with a custom serial executor once the app
/// target moves to Swift 6 (PHASES.md 0.1).
///
/// Fixes vs. the old `FaceTrackingViewModel`: exposure is continuous + face-driven (never locked), frames are rotated
/// upright before analysis, luma is read from the real Y plane (not misread as BGRA), analysis is throttled, photos come
/// from `AVCapturePhotoOutput` at quality priority, and capture is never mirrored (stored photos stay unmirrored).
/// Face ID iPhones use the TrueDepth camera so the front photo carries a real depth map (the 3D scan). iPhone Duo has
/// no TrueDepth camera, so it falls back to the regular front camera — 2D only (CLAUDE.md §1.8).
final class CameraSession: NSObject, @unchecked Sendable {
    enum CameraError: Error {
        case unavailable
        case configurationFailed
        case captureFailed
    }

    static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Camera")
    static let analysisInterval: TimeInterval = 1.0 / 15.0
    static let qualitySampleSide = 128

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.Patani.Skinalyze.camera.session")
    private let videoQueue = DispatchQueue(label: "com.Patani.Skinalyze.camera.video", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let depthQueue = DispatchQueue(label: "com.Patani.Skinalyze.camera.depth", qos: .userInitiated)
    /// depthQueue state: recent depth frames (native sensor orientation) for temporal fusion with the photo's depth.
    private var depthBurst: [(time: TimeInterval, map: DepthMap)] = []
    private var isCollectingDepth = false
    static let depthBurstWindow: TimeInterval = 0.9
    static let depthBurstMax = 24
    private var isConfigured = false
    private(set) var device: AVCaptureDevice?

    // videoQueue state
    private var lastAnalysis: TimeInterval = 0
    private var previousFace: (bounds: ImageRect, time: TimeInterval)?
    private var frameContinuation: AsyncStream<FrameSample>.Continuation?

    // sessionQueue state
    private var photoContinuation: CheckedContinuation<CapturedPhoto, Error>?
    /// Set once configured: the front camera is TrueDepth and depth delivery is on.
    private(set) var supportsDepth = false

    /// Latest-frame-wins stream of analysed frames (~15 Hz).
    private(set) lazy var frames: AsyncStream<FrameSample> = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        self.frameContinuation = continuation
    }

    static func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func configure() async throws {
        _ = frames // create the stream before frames can arrive
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.configureOnQueue()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    /// Applies the rotation coordinator's horizon-level capture angle to photo + video outputs, so stored photos and
    /// analysed frames are upright in every orientation and iPhone Duo pose.
    func applyCaptureRotation(_ angle: CGFloat) {
        sessionQueue.async {
            for connection in [self.photoOutput.connection(with: .video), self.videoOutput.connection(with: .video)] {
                guard let connection, connection.isVideoRotationAngleSupported(angle) else { continue }
                connection.videoRotationAngle = angle
            }
        }
    }

    /// Captures a photo; with `withDepth`, also its TrueDepth depth map (when the device has one).
    /// Start/stop buffering streamed depth frames (only while the front photo is being lined up).
    func setCollectingDepth(_ collecting: Bool) {
        depthQueue.async {
            self.isCollectingDepth = collecting
            if !collecting { self.depthBurst.removeAll() }
        }
    }

    /// The buffered frames from the last `depthBurstWindow` seconds.
    private func recentDepthFrames() -> [DepthMap] {
        depthQueue.sync {
            guard let latest = depthBurst.last?.time else { return [] }
            return depthBurst.filter { latest - $0.time <= Self.depthBurstWindow }.map(\.map)
        }
    }

    func capturePhoto(withDepth: Bool = false) async throws -> CapturedPhoto {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.session.isRunning, self.photoContinuation == nil else {
                    continuation.resume(throwing: CameraError.captureFailed)
                    return
                }
                self.photoContinuation = continuation
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                if withDepth, self.photoOutput.isDepthDataDeliveryEnabled {
                    settings.isDepthDataDeliveryEnabled = true
                    settings.isDepthDataFiltered = true // fills sensor holes
                    settings.embedsDepthDataInPhoto = false
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - Configuration (sessionQueue)

    private func configureOnQueue() throws {
        guard !isConfigured else { return }
        let trueDepth = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
        guard let device = trueDepth ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.unavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput), session.canAddOutput(videoOutput) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        if trueDepth != nil, photoOutput.isDepthDataDeliverySupported {
            photoOutput.isDepthDataDeliveryEnabled = true
            supportsDepth = true
            // Stream depth too, so the front photo's depth can be fused with a burst of frames (far less noise).
            if session.canAddOutput(depthOutput) {
                session.addOutput(depthOutput)
                depthOutput.isFilteringEnabled = true
                depthOutput.alwaysDiscardsLateDepthData = true
                depthOutput.setDelegate(self, callbackQueue: depthQueue)
            }
            Self.selectBestDepthFormat(device)
        }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        session.addOutput(videoOutput)

        for connection in [photoOutput.connection(with: .video), videoOutput.connection(with: .video)] {
            guard let connection, connection.isVideoMirroringSupported else { continue }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }

        try device.lockForConfiguration()
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        device.unlockForConfiguration()

        self.device = device
        isConfigured = true
    }
}

// MARK: - Frame analysis (videoQueue)

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard timestamp - lastAnalysis >= Self.analysisInterval,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = timestamp

        let face = detectFace(in: pixelBuffer)
        let quality = measureQuality(pixelBuffer, face: face?.bounds, timestamp: timestamp)
        previousFace = face.map { ($0.bounds, timestamp) }
        frameContinuation?.yield(FrameSample(face: face, quality: quality, timestamp: timestamp))
    }

    private func detectFace(in pixelBuffer: CVPixelBuffer) -> FaceMeasurement? {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            Self.logger.error("Face detection failed: \(error.localizedDescription)")
            return nil
        }
        guard let observation = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else {
            return nil
        }
        let box = observation.boundingBox
        let degrees = { (value: NSNumber?) in (value?.doubleValue ?? 0) * 180 / .pi }
        return FaceMeasurement(
            bounds: ImageRect(x: box.minX, y: box.minY, width: box.width, height: box.height),
            yawDegrees: degrees(observation.yaw),
            pitchDegrees: degrees(observation.pitch),
            rollDegrees: degrees(observation.roll)
        )
    }

    private func measureQuality(_ pixelBuffer: CVPixelBuffer, face: ImageRect?, timestamp: TimeInterval) -> FrameQuality {
        var motion = 0.0
        if let previousFace, let face {
            motion = FrameAnalysis.motion(from: previousFace.bounds, to: face, elapsed: timestamp - previousFace.time)
        }
        guard let face, let gray = Self.lumaSample(pixelBuffer, region: face) else {
            return FrameQuality(meanLuma: 0, clippedFraction: 0, sharpness: 0, motion: motion)
        }
        return FrameQuality(
            meanLuma: FrameAnalysis.meanLuma(gray),
            clippedFraction: FrameAnalysis.clippedFraction(gray),
            sharpness: FrameAnalysis.laplacianVariance(gray),
            motion: motion
        )
    }

    /// Samples the luma (Y) plane inside the face box into a ≤128 px grayscale image.
    static func lumaSample(_ pixelBuffer: CVPixelBuffer, region: ImageRect) -> GrayImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)

        let minX = max(Int(region.x * Double(width)), 0)
        let maxX = min(Int((region.x + region.width) * Double(width)), width)
        let minY = max(Int((1 - region.y - region.height) * Double(height)), 0)
        let maxY = min(Int((1 - region.y) * Double(height)), height)
        guard maxX - minX >= 3, maxY - minY >= 3 else { return nil }

        let step = max(max(maxX - minX, maxY - minY) / qualitySampleSide, 1)
        let xs = Array(stride(from: minX, to: maxX, by: step))
        let ys = Array(stride(from: minY, to: maxY, by: step))
        let pixels = ys.flatMap { y in xs.map { x in bytes[y * rowBytes + x] } }
        return GrayImage(width: xs.count, height: ys.count, pixels: pixels)
    }
}

// MARK: - Photo capture

extension CameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let result: Swift.Result<CapturedPhoto, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            let burst = photo.depthData == nil ? [] : recentDepthFrames()
            result = .success(CapturedPhoto(image: image, depth: Self.depthMap(from: photo, matching: image.size, burst: burst)))
        } else {
            result = .failure(CameraError.captureFailed)
        }
        sessionQueue.async {
            let continuation = self.photoContinuation
            self.photoContinuation = nil
            continuation?.resume(with: result)
        }
    }
}

// MARK: - Depth (TrueDepth → DepthMap)

extension CameraSession: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData,
                         timestamp: CMTime, connection: AVCaptureConnection) {
        guard isCollectingDepth, let map = Self.nativeMap(depthData) else { return }
        depthBurst.append((timestamp.seconds, map))
        if depthBurst.count > Self.depthBurstMax { depthBurst.removeFirst(depthBurst.count - Self.depthBurstMax) }
    }

    /// Highest-resolution float depth format the active video format offers.
    static func selectBestDepthFormat(_ device: AVCaptureDevice) {
        let formats = device.activeFormat.supportedDepthDataFormats.filter {
            let type = CMFormatDescriptionGetMediaSubType($0.formatDescription)
            return type == kCVPixelFormatType_DepthFloat32 || type == kCVPixelFormatType_DepthFloat16
        }
        guard let best = formats.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        }) else { return }
        do {
            try device.lockForConfiguration()
            device.activeDepthDataFormat = best
            device.unlockForConfiguration()
        } catch {
            logger.error("Could not select depth format: \(error.localizedDescription)")
        }
    }

    /// Depth for the stored photo: the photo's own depth fused (per-pixel median) with the streamed burst, rotated to
    /// the photo's upright orientation, intrinsics scaled to the map. Returns nil (2D-only scan) rather than a
    /// mis-oriented map if the result doesn't match the photo's aspect.
    static func depthMap(from photo: AVCapturePhoto, matching photoSize: CGSize, burst: [DepthMap]) -> DepthMap? {
        guard let depthData = photo.depthData, let native = nativeMap(depthData) else { return nil }
        let matching = burst.map { $0.width == native.width && $0.height == native.height ? $0 : $0.resampled(width: native.width, height: native.height) }
        let fused = DepthFusion.median(matching + [native]) ?? native
        #if DEBUG
        print("[scan] depth fusion: \(matching.count) streamed frames + photo depth \(native.width)x\(native.height)")
        #endif
        let withIntrinsics = DepthMap(width: fused.width, height: fused.height, meters: fused.meters,
                                      intrinsics: intrinsics(depthData.cameraCalibrationData, width: native.width, height: native.height))
        let raw = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32
        let orientation = raw.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
        guard let turns = quarterTurns(orientation) else { return nil }
        let upright = withIntrinsics.rotated(quarterTurnsClockwise: turns)
        guard (upright.width < upright.height) == (photoSize.width < photoSize.height) else {
            logger.error("Depth orientation does not match the photo (\(upright.width)x\(upright.height)); saving 2D only")
            return nil
        }
        return upright
    }

    /// Float32 metres in the sensor's native orientation.
    static func nativeMap(_ depthData: AVDepthData) -> DepthMap? {
        let converted = depthData.depthDataType == kCVPixelFormatType_DepthFloat32
            ? depthData : depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let buffer = converted.depthDataMap
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer), width > 2, height > 2 else { return nil }
        var meters: [Float] = []
        meters.reserveCapacity(width * height)
        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            for x in 0..<width { meters.append(row[x]) }
        }
        return DepthMap(width: width, height: height, meters: meters, intrinsics: nil)
    }

    /// EXIF orientation → clockwise quarter turns to make the map upright (mirrored orientations aren't used).
    private static func quarterTurns(_ orientation: CGImagePropertyOrientation) -> Int? {
        switch orientation {
        case .up: 0
        case .right: 1
        case .down: 2
        case .left: 3
        default: nil
        }
    }

    private static func intrinsics(_ calibration: AVCameraCalibrationData?, width: Int, height: Int) -> CameraIntrinsics? {
        guard let calibration, calibration.intrinsicMatrixReferenceDimensions.width > 0 else { return nil }
        let matrix = calibration.intrinsicMatrix
        let scale = Float(width) / Float(calibration.intrinsicMatrixReferenceDimensions.width)
        return CameraIntrinsics(fx: matrix.columns.0.x * scale, fy: matrix.columns.1.y * scale,
                                cx: Float(width) / 2, cy: Float(height) / 2)
    }
}
