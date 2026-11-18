import UIKit
import SkinalyzeKit

/// App-side image helpers for `ScanSession` (UIKit isn't available to the platform-neutral Kit model).
extension ScanSession {
    /// Decoded photo for the capture at `index` (front, right, left order), or `nil`.
    func uiImage(at index: Int) -> UIImage? {
        let captures = sortedCaptures
        guard captures.indices.contains(index), let data = captures[index].imageData else { return nil }
        return UIImage(data: data)
    }

    /// Angle of the capture at `index`.
    func captureAngle(at index: Int) -> CaptureAngle? {
        let captures = sortedCaptures
        return captures.indices.contains(index) ? captures[index].angle : nil
    }
}
