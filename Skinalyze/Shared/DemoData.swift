#if DEBUG
import SwiftData
import UIKit
import SkinalyzeKit

/// Debug-only sample scans so every screen can be exercised in the Simulator (which has no camera).
/// Enable with the launch argument `-seedDemoData` (UI tests and manual simulator testing).
enum DemoData {
    static let launchArgument = "-seedDemoData"

    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    @MainActor
    static func seedIfRequested(into container: ModelContainer) async {
        guard isRequested else { return }
        let context = container.mainContext
        // `-resetDemoData YES`: start from a clean set of demo scans (tests that need a particular newest scan).
        if UserDefaults.standard.bool(forKey: "resetDemoData") {
            try? context.delete(model: ScanSession.self)
            try? context.save()
        }
        guard (try? context.fetchCount(FetchDescriptor<ScanSession>())) == 0 else { return }
        UserDefaults.standard.set(true, forKey: UserProfile.Key.onboardingComplete)
        UserDefaults.standard.set("Combination", forKey: UserProfile.Key.skinType)
        UserDefaults.standard.set("Demo", forKey: UserProfile.Key.name)

        let store = ScanStore(modelContainer: container)
        // `-demoNewestDaysAgo 0`: the newest demo scan is from today, to test the daily scan limit.
        let newestDaysAgo = UserDefaults.standard.string(forKey: "demoNewestDaysAgo").flatMap(Int.init) ?? 1
        let basePlan: [(daysAgo: Int, lesions: [(LesionType, FaceZone)])] = [
            (35, [(.papule, .chin), (.papule, .chin), (.pustule, .chin), (.whitehead, .forehead), (.blackhead, .nose),
                  (.papule, .leftCheek), (.pustule, .rightJaw), (.darkSpot, .leftCheek)]),
            (28, [(.papule, .chin), (.pustule, .chin), (.whitehead, .forehead), (.blackhead, .nose), (.papule, .leftCheek),
                  (.darkSpot, .leftCheek)]),
            (21, [(.papule, .chin), (.whitehead, .forehead), (.blackhead, .nose), (.papule, .rightCheek), (.darkSpot, .leftCheek)]),
            (14, [(.papule, .chin), (.blackhead, .nose), (.whitehead, .forehead), (.darkSpot, .leftCheek)]),
            (7, [(.blackhead, .nose), (.whitehead, .forehead), (.darkSpot, .leftCheek)]),
            (newestDaysAgo, [(.blackhead, .nose), (.darkSpot, .leftCheek)]),
        ]
        // `-demoScanCount N`: older weekly scans before the usual six (reels and history with many scans).
        let extra = max(0, (UserDefaults.standard.string(forKey: "demoScanCount").flatMap(Int.init) ?? 0) - basePlan.count)
        let older: [(daysAgo: Int, lesions: [(LesionType, FaceZone)])] = (0..<extra).reversed().map { step in
            (42 + step * 7, Array(basePlan[step % 2].lesions.prefix(5 + step % 4)))
        }
        let plan = older + basePlan
        for (index, entry) in plan.enumerated() {
            let detections = entry.lesions.enumerated().map { offset, lesion in
                DetectionDraft(type: lesion.0, confidence: 0.8, box: box(for: lesion.1, offset: offset),
                               captureAngle: angle(for: lesion.1), zone: lesion.1)
            }
            let counts = LesionCounts(Dictionary(entry.lesions.map { ($0.0, 1) }, uniquingKeysWith: +))
            let draft = ScanDraft(
                createdAt: Calendar.current.date(byAdding: .day, value: -entry.daysAgo, to: .now) ?? .now,
                captureMode: .camera2D,
                modelVersion: "demo",
                counts: counts,
                legacyScore: LegacySeverityScale.score(for: counts),
                captures: CaptureAngle.legacyOrder.compactMap { angle in
                    let marks = detections.filter { $0.captureAngle == angle }.map { detection in
                        DemoPortrait.Mark(type: detection.type,
                                          center: CGPoint(x: detection.box.x + detection.box.width / 2,
                                                          y: 1 - detection.box.y - detection.box.height / 2))
                    }
                    return DemoPortrait.jpeg(angle: angle, seed: index, marks: marks).map { CaptureDraft(angle: angle, imageData: $0) }
                },
                detections: detections,
                productIDs: index >= 2 ? [18] : [],
                legacyResultID: nil
            )
            let isNewest = index == plan.count - 1
            let mesh = isNewest ? (realMesh() ?? draft.captures.first.map { demoMesh(texture: $0.imageData) }) : nil
            let pins = mesh.map { mesh in
                FacePinMapper.pins(for: detections, photoFace: ImageRect(x: 0.2, y: 0.24, width: 0.6, height: 0.63), mesh: mesh)
            } ?? []
            _ = try? await store.save(draft, faceMesh: mesh, pins: pins)
        }
    }

    /// `-demoActivity YES`: ~10 weeks of routine days (every fifth day missed), quests on those days, sunscreen on
    /// the shelf for the last 60 days, and a sunscreen challenge 12 days in — so recaps, Wrapped and the journey map
    /// show realistic numbers. Runs before any model reads these stores.
    static func seedActivityIfRequested(now: Date = .now) {
        guard UserDefaults.standard.bool(forKey: "demoActivity") else { return }
        let calendar = Calendar.current
        let store = EngagementStore()
        var ledger = RewardLedger.empty
        for daysAgo in 0..<70 where daysAgo % 5 != 4 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            let day = DayStamp(date, calendar: calendar)
            store.setDone(true, on: day)
            let kinds: Set<QuestKind> = daysAgo % 3 == 0 ? [.routine, .lesson, .share] : [.routine, .lookBack]
            ledger.completed[day.string] = kinds
            ledger.points += kinds.reduce(0) { $0 + QuestEngine.points(for: $1) }
        }
        ledger.latestDay = DayStamp(now, calendar: calendar)
        UserDefaults.standard.set(try? JSONEncoder().encode(ledger), forKey: "rewardLedger")
        UserDefaults.standard.set(18, forKey: UserProfile.Key.sunscreenID)
        RoutineHistory.started(18, at: calendar.date(byAdding: .day, value: -60, to: now) ?? now)
        let start = DayStamp(calendar.date(byAdding: .day, value: -14, to: now) ?? now, calendar: calendar)
        let done = (1...14).filter { $0 % 7 != 0 }.compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        let book = ChallengeBook(active: Challenge(kind: .sunscreen, started: start,
                                                   doneDays: Set(done.map { DayStamp($0, calendar: calendar) })),
                                 finished: [])
        UserDefaults.standard.set(try? JSONEncoder().encode(book), forKey: "challengeBook")
        UserDefaults.standard.removeObject(forKey: "seenRecaps")
        // Journal: stressed around the older (busier) demo scans, workouts around the newer ones — so a pattern shows.
        let journal = (0..<40).compactMap { daysAgo -> JournalEntry? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { return nil }
            return JournalEntry(day: DayStamp(date, calendar: calendar), tags: daysAgo >= 18 ? [.stressed] : [.workout])
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(journal), forKey: "journalEntries")
    }

    /// `-resetOnboarding YES`: a first run again (answers, shelf, tutorial and first-scan coaching cleared), for the
    /// onboarding UI tests and screenshots.
    static func resetOnboardingIfRequested(defaults: UserDefaults = .standard) {
        // `-resetTutorial YES`: only the coach marks, tours and first-week path start over.
        if defaults.bool(forKey: "resetTutorial") {
            for key in ["tutorialState", "tutorialSessions", "tutorialCompared", "tutorialJourneyVisited",
                        "resultTourPending"] {
                defaults.removeObject(forKey: key)
            }
        }
        // `-firstWeekDemo YES`: walk the first-week path as if just onboarded.
        if defaults.bool(forKey: "firstWeekDemo") { defaults.set(true, forKey: "firstWeekActive") }
        guard defaults.bool(forKey: "resetOnboarding") else { return }
        for key in [UserProfile.Key.onboardingComplete, UserProfile.Key.name, UserProfile.Key.skinType,
                    UserProfile.Key.sensitivity, UserProfile.Key.goals, UserProfile.Key.legacyUseSkincare,
                    UserProfile.Key.cleanserID, UserProfile.Key.tonerID, UserProfile.Key.moisturizerID,
                    UserProfile.Key.sunscreenID, "tutorialState", "tutorialSessions", "tutorialCompared",
                    "tutorialJourneyVisited", "firstScanCoachingPending", "resultTourPending", "firstWeekActive"] {
            defaults.removeObject(forKey: key)
        }
    }

    /// `-debugMeshDir <folder>`: load a real captured mesh (vertices.bin / indices.bin / uvs.bin / texture.bin, as
    /// stored by `FaceMeshRecord`) so the phone's renderer can be checked in the Simulator on real scan data.
    private static func realMesh() -> FaceMeshDraft? {
        guard let folder = UserDefaults.standard.string(forKey: "debugMeshDir") else { return nil }
        func load(_ name: String) -> Data? { try? Data(contentsOf: URL(fileURLWithPath: folder).appendingPathComponent(name)) }
        guard let vertexData = load("vertices.bin"), let indexData = load("indices.bin"),
              let uvData = load("uvs.bin"), let texture = load("texture.bin") else { return nil }
        let uvs = FaceMeshCodec.decodeUVs(uvData)
        return FaceMeshDraft(vertices: FaceMeshCodec.decodeVertices(vertexData), indices: FaceMeshCodec.decodeIndices(indexData),
                             textureCoordinates: uvs, projected: uvs.map { SIMD2($0.x, 1 - $0.y) },
                             texture: texture, mirroredProjection: false, projectedIsPhotoSpace: true)
    }

    /// A synthetic half-ellipsoid "face" so the 3D viewer can be exercised in the Simulator (no TrueDepth camera there).
    private static func demoMesh(texture: Data) -> FaceMeshDraft {
        let rings = 24, segments = 24
        var vertices: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], projected: [SIMD2<Float>] = [], indices: [UInt16] = []
        for r in 0...rings {
            let v = Float(r) / Float(rings)
            let theta = (v - 0.5) * .pi * 0.95
            for s in 0...segments {
                let u = Float(s) / Float(segments)
                let phi = (u - 0.5) * .pi * 0.9
                vertices.append(SIMD3(0.075 * sin(phi) * cos(theta), -0.1 * sin(theta), 0.05 * cos(phi) * cos(theta)))
                uvs.append(SIMD2(0.2 + 0.6 * u, 1 - (0.12 + 0.64 * v)))
                projected.append(SIMD2(0.2 + 0.6 * u, 0.12 + 0.64 * v))
            }
        }
        let row = segments + 1
        for r in 0..<rings {
            for s in 0..<segments {
                let a = UInt16(r * row + s), b = a + 1, c = a + UInt16(row), d = c + 1
                indices += [a, c, b, b, c, d]
            }
        }
        return FaceMeshDraft(vertices: vertices, indices: indices, textureCoordinates: uvs, projected: projected,
                             texture: texture, mirroredProjection: false)
    }

    private static func angle(for zone: FaceZone) -> CaptureAngle {
        ZoneOwnership.owner(of: zone, available: Set(CaptureAngle.allCases))
    }

    private static func box(for zone: FaceZone, offset: Int) -> ImageRect {
        let jitter = Double(offset % 3) * 0.03
        let (x, y): (Double, Double) = switch zone {
        case .forehead: (0.45 + jitter, 0.70)
        case .nose: (0.48, 0.52 + jitter / 2)
        case .chin: (0.46 + jitter, 0.28)
        case .leftCheek, .leftJaw: (0.55 + jitter, 0.42)
        case .rightCheek, .rightJaw: (0.38 + jitter, 0.42)
        }
        return ImageRect(x: x, y: y, width: 0.03, height: 0.03)
    }
}
#endif
