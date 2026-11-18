import CoreGraphics
import Testing
@testable import SkinalyzeKit

/// Compare registers two photos by the eyes so faces sit in exactly the same place.
@Suite("Face alignment")
struct FaceAlignmentTests {
    let output = CGSize(width: 900, height: 1200)

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    @Test("Eyes land exactly on the canonical eye points")
    func eyesLandOnTargets() {
        let transform = FaceAlignment.transform(eyes: (CGPoint(x: 1200, y: 1500), CGPoint(x: 1800, y: 1560)), output: output)
        let targets = FaceAlignment.targetEyes(in: output)
        #expect(distance(CGPoint(x: 1200, y: 1500).applying(transform), targets.0) < 0.001)
        #expect(distance(CGPoint(x: 1800, y: 1560).applying(transform), targets.1) < 0.001)
    }

    @Test("Eye order doesn't matter (whichever is leftmost in the image maps left)")
    func eyeOrderInvariant() {
        let a = FaceAlignment.transform(eyes: (CGPoint(x: 100, y: 200), CGPoint(x: 300, y: 210)), output: output)
        let b = FaceAlignment.transform(eyes: (CGPoint(x: 300, y: 210), CGPoint(x: 100, y: 200)), output: output)
        #expect(a == b)
    }

    @Test("Two photos of the same face at different zoom and tilt end up registered")
    func twoPhotosRegister() {
        // Same face: second photo is 1.6x zoomed, shifted and rolled ~10°.
        let first = (CGPoint(x: 400, y: 500), CGPoint(x: 600, y: 500))
        let nose1 = CGPoint(x: 500, y: 650)
        let roll = 10 * CGFloat.pi / 180
        let warp = CGAffineTransform(translationX: 150, y: -80).rotated(by: roll).scaledBy(x: 1.6, y: 1.6)
        let second = (first.0.applying(warp), first.1.applying(warp))
        let nose2 = nose1.applying(warp)

        let t1 = FaceAlignment.transform(eyes: first, output: output)
        let t2 = FaceAlignment.transform(eyes: second, output: output)
        #expect(distance(nose1.applying(t1), nose2.applying(t2)) < 0.01)
    }

    @Test("Without landmarks, the face box still centres and scales the face")
    func faceBoxFallback() {
        // Face box in top-left pixel coords.
        let box = CGRect(x: 300, y: 400, width: 600, height: 700)
        let transform = FaceAlignment.transform(faceBox: box, output: output)
        let centre = CGPoint(x: box.midX, y: box.midY).applying(transform)
        #expect(abs(centre.x - output.width / 2) < 0.001)
        #expect(abs(centre.y - output.height * FaceAlignment.faceCentreY) < 0.001)
        let width = CGPoint(x: box.maxX, y: box.midY).applying(transform).x - CGPoint(x: box.minX, y: box.midY).applying(transform).x
        #expect(abs(width - output.width * FaceAlignment.faceWidthRatio) < 0.001)
    }
}
