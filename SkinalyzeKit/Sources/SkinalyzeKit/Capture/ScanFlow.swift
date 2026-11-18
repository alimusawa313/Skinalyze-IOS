/// The scan flow as an explicit state machine (PLAN.md §14.3). Pure, so it is unit-tested and independent of view
/// lifecycle: folding, rotating or backgrounding (`.interrupted`) never loses captured angles.
public enum ScanFlowState: Sendable, Hashable {
    case idle
    case needsPermission
    case permissionDenied
    case capturing(CaptureAngle, captured: [CaptureAngle])
    case reviewing(captured: [CaptureAngle])
    case analyzing
    case finished
    case failed(String)

    public var capturedCount: Int {
        switch self {
        case let .capturing(_, captured), let .reviewing(captured): captured.count
        default: 0
        }
    }
}

public enum ScanFlowEvent: Sendable, Hashable {
    case start
    case permissionGranted
    case permissionDenied
    case captured(CaptureAngle)
    case retake(CaptureAngle)
    case confirm
    case interrupted
    case analysisSucceeded
    case analysisFailed(String)
    case retryAnalysis
    case cancel
}

public enum ScanFlow {
    public static let sequence: [CaptureAngle] = [.front, .right, .left]

    public static func reduce(_ state: ScanFlowState, _ event: ScanFlowEvent) -> ScanFlowState {
        switch (state, event) {
        case (_, .cancel):
            return .idle
        case (.idle, .start):
            return .needsPermission
        case (.needsPermission, .permissionGranted), (.permissionDenied, .permissionGranted):
            return .capturing(sequence[0], captured: [])
        case (.needsPermission, .permissionDenied):
            return .permissionDenied
        case let (.capturing(expected, captured), .captured(angle))
            where angle == expected || (expected != .front && angle != .front && !captured.contains(angle)):
            // After the front photo, either side may come first — turn whichever way feels natural.
            let updated = ordered(Set(captured).union([angle]))
            guard let next = sequence.first(where: { !updated.contains($0) }) else {
                return .reviewing(captured: updated)
            }
            return .capturing(next, captured: updated)
        case let (.reviewing(captured), .retake(angle)):
            return .capturing(angle, captured: captured.filter { $0 != angle })
        case let (.reviewing(captured), .confirm) where Set(captured) == Set(sequence):
            return .analyzing
        case (.analyzing, .analysisSucceeded):
            return .finished
        case let (.analyzing, .analysisFailed(reason)):
            return .failed(reason)
        case (.failed, .retryAnalysis):
            return .analyzing
        default:
            return state // invalid or no-op events (incl. .interrupted) leave the state unchanged
        }
    }

    private static func ordered(_ angles: Set<CaptureAngle>) -> [CaptureAngle] {
        sequence.filter(angles.contains)
    }
}
