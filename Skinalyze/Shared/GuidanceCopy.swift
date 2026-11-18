import Foundation
import SkinalyzeKit

/// Short, friendly instructions for the scan camera (one at a time, never all-caps).
enum GuidanceCopy {
    static func text(for hint: GuidanceHint?) -> String {
        switch hint {
        case nil: String(localized: "Hold still…")
        case .noFace: String(localized: "Bring your face into the frame")
        case .moveCloser: String(localized: "Move a little closer")
        case .moveBack: String(localized: "Move back a little")
        case .centerFace: String(localized: "Center your face in the outline")
        case .faceForward: String(localized: "Look straight at the camera")
        case .turnHeadLeft: String(localized: "Turn your head to your left")
        case .turnHeadRight: String(localized: "Turn your head to your right")
        case .levelHead: String(localized: "Keep your head level")
        case .needMoreLight: String(localized: "Find softer, brighter light — try facing a window")
        case .tooBright: String(localized: "Too bright — step out of direct light")
        case .holdStill: String(localized: "Hold still")
        }
    }

    static func title(for angle: CaptureAngle) -> String {
        switch angle {
        case .front: String(localized: "Front")
        case .right: String(localized: "Turn right")
        case .left: String(localized: "Turn left")
        }
    }

    static func zoneName(_ zone: FaceZone) -> String {
        switch zone {
        case .forehead: String(localized: "Forehead")
        case .nose: String(localized: "Nose")
        case .leftCheek: String(localized: "Left cheek")
        case .rightCheek: String(localized: "Right cheek")
        case .chin: String(localized: "Chin")
        case .leftJaw: String(localized: "Left jaw")
        case .rightJaw: String(localized: "Right jaw")
        }
    }

    /// Segments of the capture ring: framing, angle, light, focus, stillness.
    static func ringSegments(_ report: GateReport?) -> [Bool] {
        guard let report else { return Array(repeating: false, count: 5) }
        let passed = report.passed
        return [
            passed.contains(.distance) && passed.contains(.centering),
            passed.contains(.angle),
            passed.contains(.light),
            passed.contains(.sharpness),
            passed.contains(.stillness),
        ]
    }
}
