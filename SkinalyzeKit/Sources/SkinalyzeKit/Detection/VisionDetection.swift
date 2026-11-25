import CoreGraphics
import CoreML
import Vision

/// Vision calls shared by the app and `Tools/DetectorBench`, so both find the same face, landmarks and model output.
/// All synchronous: call them off the main actor.
public enum VisionFaceAnalysis {
    /// Largest face in an upright image (Vision normalised box), or `nil` if none is found.
    public static func largestFace(in image: CGImage) throws -> ImageRect? {
        let request = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        guard let box = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width })?.boundingBox else {
            return nil
        }
        return ImageRect(x: box.minX, y: box.minY, width: box.width, height: box.height)
    }

    /// Landmark outlines for the face at `face`, or `nil` when Vision finds none.
    public static func landmarks(in image: CGImage, face: ImageRect) throws -> FaceLandmarkPoints? {
        let request = VNDetectFaceLandmarksRequest()
        request.inputFaceObservations = [
            VNFaceObservation(boundingBox: CGRect(x: face.x, y: face.y, width: face.width, height: face.height)),
        ]
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        guard let landmarks = request.results?.first?.landmarks else { return nil }

        let imageSize = CGSize(width: image.width, height: image.height)
        func points(_ region: VNFaceLandmarkRegion2D?) -> [ImagePoint] {
            (region?.pointsInImage(imageSize: imageSize) ?? []).map {
                ImagePoint(x: $0.x / imageSize.width, y: $0.y / imageSize.height)
            }
        }
        return FaceLandmarkPoints(
            leftEye: points(landmarks.leftEye),
            rightEye: points(landmarks.rightEye),
            leftEyebrow: points(landmarks.leftEyebrow),
            rightEyebrow: points(landmarks.rightEyebrow),
            outerLips: points(landmarks.outerLips),
            nose: points(landmarks.nose),
            faceContour: points(landmarks.faceContour)
        )
    }
}

/// Runs a Create ML object detector (such as `acneObj28200`) through Vision.
public enum CoreMLDetections {
    /// Runs `model` on the whole `image` (`.scaleFill`; tiles and face crops are square, so nothing is distorted) and
    /// returns its detections normalised to `image`. Unknown labels are ignored.
    public static func run(_ model: VNCoreMLModel, on image: CGImage) throws -> [RawDetection] {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        let observations = request.results as? [VNRecognizedObjectObservation] ?? []
        return observations.compactMap { observation in
            guard let label = observation.labels.first, let type = LesionType(modelLabel: label.identifier) else {
                return nil
            }
            let box = observation.boundingBox
            return RawDetection(
                type: type,
                confidence: Double(label.confidence),
                box: ImageRect(x: box.minX, y: box.minY, width: box.width, height: box.height)
            )
        }
    }

    /// Overrides the model's own confidence floor (an optional input of Create ML detectors), so per-class thresholds
    /// below the model default can be tuned. Leave unset to keep the model's default.
    public static func thresholdInputs(confidence: Double, iou: Double) throws -> MLFeatureProvider {
        try MLDictionaryFeatureProvider(dictionary: [
            "confidenceThreshold": MLFeatureValue(double: confidence),
            "iouThreshold": MLFeatureValue(double: iou),
        ])
    }
}
