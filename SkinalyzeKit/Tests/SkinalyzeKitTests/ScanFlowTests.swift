import Testing
@testable import SkinalyzeKit

@Suite("Scan flow state machine")
struct ScanFlowTests {
    private func run(_ events: [ScanFlowEvent], from state: ScanFlowState = .idle) -> ScanFlowState {
        events.reduce(state, ScanFlow.reduce)
    }

    @Test("Happy path: permission → front, right, left → review → analysis → finished")
    func happyPath() {
        let state = run([.start, .permissionGranted, .captured(.front)])
        #expect(state == .capturing(.right, captured: [.front]))
        let reviewed = run([.captured(.right), .captured(.left)], from: state)
        #expect(reviewed == .reviewing(captured: [.front, .right, .left]))
        #expect(run([.confirm, .analysisSucceeded], from: reviewed) == .finished)
    }

    @Test("Denied permission is a real state, not a black screen; granting later resumes")
    func permission() {
        let denied = run([.start, .permissionDenied])
        #expect(denied == .permissionDenied)
        #expect(run([.permissionGranted], from: denied) == .capturing(.front, captured: []))
    }

    @Test("A capture for the wrong angle is ignored (never advances without the right photo)")
    func wrongAngleIgnored() {
        let state = run([.start, .permissionGranted, .captured(.left)])
        #expect(state == .capturing(.front, captured: []))
    }

    @Test("After the front photo, either side can come first (turn whichever way feels natural)")
    func eitherSideFirst() {
        let state = run([.start, .permissionGranted, .captured(.front), .captured(.left)])
        #expect(state == .capturing(.right, captured: [.front, .left]))
        #expect(run([.captured(.right)], from: state) == .reviewing(captured: [.front, .right, .left]))
    }

    @Test("Confirm without all three angles is ignored — fixes scans saved with fewer than 3 photos")
    func confirmNeedsAllAngles() {
        let partial = ScanFlowState.reviewing(captured: [.front, .right])
        #expect(run([.confirm], from: partial) == partial)
    }

    @Test("Retake replaces only that angle and returns to review")
    func retakeOne() {
        let reviewed = ScanFlowState.reviewing(captured: [.front, .right, .left])
        let retaking = run([.retake(.right)], from: reviewed)
        #expect(retaking == .capturing(.right, captured: [.front, .left]))
        #expect(run([.captured(.right)], from: retaking) == .reviewing(captured: [.front, .right, .left]))
    }

    @Test("Interruptions (fold/unfold, rotate, backgrounding) keep captured angles")
    func interruption() {
        let state = ScanFlowState.capturing(.left, captured: [.front, .right])
        #expect(run([.interrupted], from: state) == state)
    }

    @Test("Analysis failure is surfaced; retrying analysis is allowed")
    func failure() {
        let failed = run([.analysisFailed("model")], from: .analyzing)
        #expect(failed == .failed("model"))
        #expect(run([.retryAnalysis], from: failed) == .analyzing)
    }

    @Test("Cancel returns to idle from anywhere")
    func cancel() {
        #expect(run([.cancel], from: .capturing(.right, captured: [.front])) == .idle)
        #expect(run([.cancel], from: .analyzing) == .idle)
    }

    @Test("Progress reflects captured angles")
    func progress() {
        #expect(ScanFlowState.capturing(.left, captured: [.front, .right]).capturedCount == 2)
        #expect(ScanFlowState.idle.capturedCount == 0)
    }
}
