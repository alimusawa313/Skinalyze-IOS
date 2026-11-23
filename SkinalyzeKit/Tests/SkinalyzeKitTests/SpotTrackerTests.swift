import Foundation
import Testing
@testable import SkinalyzeKit

/// Following the same spot across scans, in eye-aligned photos. A wrong match would read like a wrong claim, so the
/// rules are strict: close in position, confident detections only, and unaligned scans are left out.
@Suite("Spot tracker")
struct SpotTrackerTests {
    private let radius = 38.0
    private func day(_ d: Int) -> Date { Date(timeIntervalSince1970: Double(d) * 86_400) }

    private func spot(_ id: String, _ type: LesionType, _ x: Double, _ y: Double, confidence: Double = 0.8) -> SpotObservation {
        SpotObservation(id: id, type: type, point: SIMD2(x, y), confidence: confidence)
    }

    private func scan(_ d: Int, _ spots: [SpotObservation], aligned: Bool = true) -> ScanSpots {
        ScanSpots(date: day(d), spots: spots, isAligned: aligned)
    }

    @Test("A spot in the same place across scans is one trail: first seen, then seen in the same place")
    func followsASpot() throws {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500)]),
            scan(8, [spot("a2", .papule, 310, 505)]),
            scan(15, [spot("a3", .papule, 305, 498)]),
        ], radius: radius)
        #expect(tracks.count == 1)
        let trail = try #require(tracks.first)
        #expect(trail.entries.map(\.status) == [.firstSeen, .samePlace, .samePlace])
        #expect(trail.entries.map(\.observation?.id) == ["a1", "a2", "a3"])
    }

    @Test("A spot that is no longer there ends with 'not seen'")
    func endsWhenGone() throws {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .pustule, 300, 500)]),
            scan(8, []),
            scan(15, [spot("b3", .pustule, 300, 500)]),
        ], radius: radius)
        let first = try #require(tracks.first { $0.entries.first?.observation?.id == "a1" })
        #expect(first.entries.map(\.status) == [.firstSeen, .notSeen])
        // Something in the same place later is a new trail, not the old one coming back.
        #expect(tracks.contains { $0.entries.map(\.status) == [.firstSeen] && $0.entries[0].observation?.id == "b3" })
    }

    @Test("A spot that leaves a dark mark is shown as a mark now")
    func becomesAMark() throws {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500)]),
            scan(8, [spot("a2", .darkSpot, 302, 501)]),
            scan(15, [spot("a3", .darkSpot, 301, 500)]),
        ], radius: radius)
        #expect(tracks.first?.entries.map(\.status) == [.firstSeen, .nowAMark, .samePlace])
    }

    @Test("Spots further apart than the radius are never joined")
    func respectsTheRadius() {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500)]),
            scan(8, [spot("b2", .papule, 300 + radius + 1, 500)]),
        ], radius: radius)
        #expect(tracks.count == 2)
    }

    @Test("Two spots close together each keep their own trail (nearest pairs first)")
    func nearestFirst() throws {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500), spot("b1", .papule, 330, 500)]),
            scan(8, [spot("b2", .papule, 328, 500), spot("a2", .papule, 302, 500)]),
        ], radius: radius)
        let a = try #require(tracks.first { $0.entries.first?.observation?.id == "a1" })
        let b = try #require(tracks.first { $0.entries.first?.observation?.id == "b1" })
        #expect(a.entries.last?.observation?.id == "a2")
        #expect(b.entries.last?.observation?.id == "b2")
    }

    @Test("Unsure detections are left out")
    func ignoresLowConfidence() {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500, confidence: SpotTracker.minimumConfidence - 0.01)]),
        ], radius: radius)
        #expect(tracks.isEmpty)
    }

    @Test("A scan whose face could not be lined up is skipped, not counted as 'not seen'")
    func skipsUnalignedScans() {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500)]),
            scan(8, [spot("x", .papule, 50, 50)], aligned: false),
            scan(15, [spot("a3", .papule, 301, 501)]),
        ], radius: radius)
        #expect(tracks.count == 1)
        #expect(tracks.first?.entries.map(\.status) == [.firstSeen, .samePlace])
    }

    @Test("The trail for a tapped spot is found by its detection id")
    func findsTrail() {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500)]),
            scan(8, [spot("a2", .papule, 301, 500)]),
        ], radius: radius)
        #expect(SpotTracker.trail(containing: "a2", in: tracks)?.entries.count == 2)
        #expect(SpotTracker.trail(containing: "nope", in: tracks) == nil)
    }

    @Test("The radius follows the eye spacing of the aligned frame")
    func radiusFromEyes() {
        let width = 900.0
        let eyeDistance = (1 - 2 * Double(FaceAlignment.eyeInset)) * width
        #expect(abs(SpotTracker.radius(alignedWidth: width) - eyeDistance * SpotTracker.radiusShareOfEyeDistance) < 1e-9)
    }

    @Test("Trails come out in the order they first appeared")
    func dates() throws {
        let tracks = SpotTracker.track([
            scan(1, [spot("a1", .papule, 300, 500)]),
            scan(8, [spot("a2", .papule, 300, 500), spot("b2", .whitehead, 600, 700)]),
        ], radius: radius)
        #expect(tracks.map { $0.entries[0].date } == [day(1), day(8)])
    }
}
