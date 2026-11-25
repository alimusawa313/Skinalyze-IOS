import Foundation

/// A polygon in normalised image coordinates (Vision convention: origin bottom-left).
public struct FacePolygon: Sendable, Hashable {
    public let points: [ImagePoint]

    public init(_ points: [ImagePoint]) {
        self.points = points
    }

    public var isUsable: Bool { points.count >= 3 }

    public var centroid: ImagePoint {
        guard !points.isEmpty else { return ImagePoint(x: 0, y: 0) }
        let count = Double(points.count)
        return ImagePoint(
            x: points.reduce(0) { $0 + $1.x } / count,
            y: points.reduce(0) { $0 + $1.y } / count
        )
    }

    public var bounds: ImageRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return ImageRect(x: 0, y: 0, width: 0, height: 0)
        }
        return ImageRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Even–odd ray casting. Degenerate polygons (fewer than 3 points) contain nothing.
    public func contains(_ point: ImagePoint) -> Bool {
        guard isUsable else { return false }
        let edges = zip(points, points.dropFirst() + [points[0]])
        let crossings = edges.filter { a, b in
            guard (a.y > point.y) != (b.y > point.y) else { return false }
            let crossingX = a.x + (point.y - a.y) / (b.y - a.y) * (b.x - a.x)
            return point.x < crossingX
        }
        return crossings.count % 2 == 1
    }

    /// Pushes every point away from the centroid by `margin` × the face size (measured per axis in face units, so
    /// the growth is even in pixels whatever the image's aspect ratio).
    public func dilated(by margin: Double, face: ImageRect) -> FacePolygon {
        guard face.width > 0, face.height > 0 else { return self }
        let center = centroid
        return FacePolygon(points.map { point in
            let u = (point.x - center.x) / face.width
            let v = (point.y - center.y) / face.height
            let length = (u * u + v * v).squareRoot()
            guard length > 0 else { return point }
            return ImagePoint(
                x: point.x + u / length * margin * face.width,
                y: point.y + v / length * margin * face.height
            )
        })
    }

    /// The part of the polygon with `y ≤ maxY` — its lower part in Vision coordinates (Sutherland–Hodgman against one
    /// half-plane).
    public func clipped(maxY: Double) -> FacePolygon {
        guard isUsable else { return self }
        func crossing(_ a: ImagePoint, _ b: ImagePoint) -> ImagePoint {
            let t = (maxY - a.y) / (b.y - a.y)
            return ImagePoint(x: a.x + t * (b.x - a.x), y: maxY)
        }
        let edges = zip(points, points.dropFirst() + [points[0]])
        return FacePolygon(edges.flatMap { a, b -> [ImagePoint] in
            switch (a.y <= maxY, b.y <= maxY) {
            case (true, true): [b]
            case (true, false): [crossing(a, b)]
            case (false, true): [crossing(a, b), b]
            case (false, false): []
            }
        })
    }
}

/// Where on a photo detections are allowed (ML-PLAN M1.2): inside the face region and outside the eyes, eyebrows,
/// lips and nostrils, which the model often mistakes for spots.
public struct SkinMask: Sendable, Hashable {
    /// Detections must be inside this region when it is present.
    public let faceRegion: FacePolygon?
    public let excluded: [FacePolygon]

    public init(faceRegion: FacePolygon?, excluded: [FacePolygon]) {
        self.faceRegion = faceRegion
        self.excluded = excluded
    }

    public func allows(_ point: ImagePoint) -> Bool {
        if let faceRegion, faceRegion.isUsable, !faceRegion.contains(point) { return false }
        return !excluded.contains { $0.contains(point) }
    }
}

/// Face landmark outlines in normalised image coordinates (Vision convention), copied out of a Vision observation so
/// the mask maths stays pure and testable.
public struct FaceLandmarkPoints: Sendable, Hashable {
    public let leftEye: [ImagePoint]
    public let rightEye: [ImagePoint]
    public let leftEyebrow: [ImagePoint]
    public let rightEyebrow: [ImagePoint]
    public let outerLips: [ImagePoint]
    /// Outline of the lower nose (alae and nostrils).
    public let nose: [ImagePoint]
    /// Jaw line from one side of the face, round the chin, to the other.
    public let faceContour: [ImagePoint]

    public init(
        leftEye: [ImagePoint], rightEye: [ImagePoint],
        leftEyebrow: [ImagePoint], rightEyebrow: [ImagePoint],
        outerLips: [ImagePoint], nose: [ImagePoint], faceContour: [ImagePoint]
    ) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftEyebrow = leftEyebrow
        self.rightEyebrow = rightEyebrow
        self.outerLips = outerLips
        self.nose = nose
        self.faceContour = faceContour
    }
}

public enum SkinMaskBuilder {
    // Margins are shares of the face size. Starting points; the benchmark decides whether they stay.
    static let eyeMargin = 0.04
    static let eyebrowMargin = 0.025
    static let lipMargin = 0.02
    static let nostrilMargin = 0.01
    static let contourMargin = 0.03
    /// Only the lower part of the nose outline is masked (nostril shadows); the upper nose keeps its blackheads.
    static let nostrilShare = 0.45
    /// Vision's contour stops at the jaw; the region is closed above the face box by this share of its height
    /// (the same tolerance `FaceZoneMapper` uses). There is no hairline landmark, so the forehead top is approximate.
    static let foreheadAllowance = 0.10

    public static func mask(for landmarks: FaceLandmarkPoints, face: ImageRect) -> SkinMask {
        let features: [(points: [ImagePoint], margin: Double)] = [
            (landmarks.leftEye, eyeMargin),
            (landmarks.rightEye, eyeMargin),
            (landmarks.leftEyebrow, eyebrowMargin),
            (landmarks.rightEyebrow, eyebrowMargin),
            (landmarks.outerLips, lipMargin),
        ]
        let featurePolygons = features
            .map { FacePolygon($0.points).dilated(by: $0.margin, face: face) }
            .filter(\.isUsable)
        let nostrils = nostrilPolygon(nose: landmarks.nose, face: face)
        return SkinMask(
            faceRegion: faceRegion(contour: landmarks.faceContour, face: face),
            excluded: featurePolygons + [nostrils].compactMap { $0 }
        )
    }

    static func nostrilPolygon(nose: [ImagePoint], face: ImageRect) -> FacePolygon? {
        let outline = FacePolygon(nose)
        guard outline.isUsable else { return nil }
        let bounds = outline.bounds
        let lower = outline
            .clipped(maxY: bounds.y + bounds.height * nostrilShare)
            .dilated(by: nostrilMargin, face: face)
        return lower.isUsable ? lower : nil
    }

    static func faceRegion(contour: [ImagePoint], face: ImageRect) -> FacePolygon? {
        guard contour.count >= 3, let first = contour.first, let last = contour.last else { return nil }
        let top = face.y + face.height * (1 + foreheadAllowance)
        let closed = contour + [ImagePoint(x: last.x, y: top), ImagePoint(x: first.x, y: top)]
        return FacePolygon(closed).dilated(by: contourMargin, face: face)
    }
}
