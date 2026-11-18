import CoreGraphics

/// Registers face photos for Compare: a similarity transform (scale + rotation + shift) that puts the eyes on fixed
/// canonical points of an output frame, so two scans' faces sit in exactly the same place. All points are pixels,
/// top-left origin, upright photo.
public enum FaceAlignment {
    /// Canonical eye positions as fractions of the output frame.
    public static let eyeY: CGFloat = 0.40
    public static let eyeInset: CGFloat = 0.36
    /// Face-box fallback (no landmarks): where the box centre goes and how wide the face is.
    public static let faceCentreY: CGFloat = 0.5
    public static let faceWidthRatio: CGFloat = 0.56

    public static func targetEyes(in output: CGSize) -> (CGPoint, CGPoint) {
        (CGPoint(x: output.width * eyeInset, y: output.height * eyeY),
         CGPoint(x: output.width * (1 - eyeInset), y: output.height * eyeY))
    }

    /// Maps the two eye centres (any order) onto the canonical eye points.
    public static func transform(eyes: (CGPoint, CGPoint), output: CGSize) -> CGAffineTransform {
        let (left, right) = eyes.0.x <= eyes.1.x ? (eyes.0, eyes.1) : (eyes.1, eyes.0)
        let (targetLeft, targetRight) = targetEyes(in: output)
        let source = CGVector(dx: right.x - left.x, dy: right.y - left.y)
        let target = CGVector(dx: targetRight.x - targetLeft.x, dy: targetRight.y - targetLeft.y)
        let sourceLength = hypot(source.dx, source.dy)
        guard sourceLength > 0 else { return .identity }
        let scale = hypot(target.dx, target.dy) / sourceLength
        let rotation = atan2(target.dy, target.dx) - atan2(source.dy, source.dx)
        // Applied right-to-left: move the left eye to the origin, scale, rotate, then onto its target.
        return CGAffineTransform(translationX: targetLeft.x, y: targetLeft.y)
            .rotated(by: rotation)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -left.x, y: -left.y)
    }

    /// Fallback when eyes can't be found: centre and scale the face box (no rotation).
    public static func transform(faceBox: CGRect, output: CGSize) -> CGAffineTransform {
        guard faceBox.width > 0 else { return .identity }
        let scale = output.width * faceWidthRatio / faceBox.width
        return CGAffineTransform(translationX: output.width / 2, y: output.height * faceCentreY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -faceBox.midX, y: -faceBox.midY)
    }
}
