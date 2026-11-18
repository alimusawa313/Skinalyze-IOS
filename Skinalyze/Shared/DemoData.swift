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
        guard (try? context.fetchCount(FetchDescriptor<ScanSession>())) == 0 else { return }
        UserDefaults.standard.set(true, forKey: UserProfile.Key.onboardingComplete)
        UserDefaults.standard.set("Combination", forKey: UserProfile.Key.skinType)
        UserDefaults.standard.set("Demo", forKey: UserProfile.Key.name)

        let store = ScanStore(modelContainer: container)
        let plan: [(daysAgo: Int, lesions: [(LesionType, FaceZone)])] = [
            (35, [(.papule, .chin), (.papule, .chin), (.pustule, .chin), (.whitehead, .forehead), (.blackhead, .nose),
                  (.papule, .leftCheek), (.pustule, .rightJaw), (.darkSpot, .leftCheek)]),
            (28, [(.papule, .chin), (.pustule, .chin), (.whitehead, .forehead), (.blackhead, .nose), (.papule, .leftCheek),
                  (.darkSpot, .leftCheek)]),
            (21, [(.papule, .chin), (.whitehead, .forehead), (.blackhead, .nose), (.papule, .rightCheek), (.darkSpot, .leftCheek)]),
            (14, [(.papule, .chin), (.blackhead, .nose), (.whitehead, .forehead), (.darkSpot, .leftCheek)]),
            (7, [(.blackhead, .nose), (.whitehead, .forehead), (.darkSpot, .leftCheek)]),
            (1, [(.blackhead, .nose), (.darkSpot, .leftCheek)]),
        ]
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
                    portrait(seed: index, angle: angle).map { CaptureDraft(angle: angle, imageData: $0) }
                },
                detections: detections,
                productIDs: index >= 2 ? [18] : [],
                legacyResultID: nil
            )
            _ = try? await store.save(draft)
        }
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

    /// A soft, abstract "face" placeholder — clearly not a real photo.
    private static func portrait(seed: Int, angle: CaptureAngle) -> Data? {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.93, green: 0.90, blue: 0.86, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let shift: CGFloat = angle == .front ? 0 : (angle == .right ? 70 : -70)
            let tone = 0.78 - CGFloat(seed % 3) * 0.04
            UIColor(red: tone + 0.1, green: tone, blue: tone - 0.08, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 180 + shift, y: 150, width: 540, height: 760))
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
#endif
