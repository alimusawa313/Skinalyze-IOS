import CoreImage
import Foundation
import Observation
import SkinalyzeKit
import UIKit

/// Patch tests (P6), opened dates for expiry (P7) and scan lighting (P12). Rules live in the kit (tested); this stores
/// the user's entries on the device.
@Observable
@MainActor
final class ShelfToolsModel {
    private enum Key {
        static let patchTests = "patchTests"
        static let opened = "openedProducts"
        static let lighting = "scanLighting"
    }

    private(set) var patchTests: [PatchTest]
    private(set) var opened: [Int: OpenedProduct]
    private var lighting: [String: ScanLighting]
    private let defaults: UserDefaults
    let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        func load<T: Decodable>(_ key: String, _ type: T.Type) -> T? {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        }
        patchTests = load(Key.patchTests, [PatchTest].self) ?? []
        opened = load(Key.opened, [Int: OpenedProduct].self) ?? [:]
        lighting = load(Key.lighting, [String: ScanLighting].self) ?? [:]
    }

    var today: DayStamp { DayStamp(.now, calendar: calendar) }

    // MARK: Patch tests

    /// The running test for a product, or the latest one.
    func patchTest(for productID: Int) -> PatchTest? {
        patchTests.last { $0.productID == productID }
    }

    var runningTests: [PatchTest] {
        patchTests.filter {
            if case .running = PatchTestEngine.status($0, today: today, calendar: calendar) { return true }
            return false
        }
    }

    func startPatchTest(_ productID: Int) {
        patchTests.removeAll { $0.productID == productID }
        patchTests.append(PatchTest(productID: productID, started: today))
        save(patchTests, Key.patchTests)
    }

    func answer(_ test: PatchTest, changed: Bool) {
        guard let index = patchTests.firstIndex(of: test) else { return }
        patchTests[index] = PatchTestEngine.answering(test, changed: changed, on: today, today: today, calendar: calendar)
        save(patchTests, Key.patchTests)
    }

    func removePatchTest(_ test: PatchTest) {
        patchTests.removeAll { $0 == test }
        save(patchTests, Key.patchTests)
    }

    // MARK: Expiry

    func setOpened(_ productID: Int, on day: DayStamp, months: Int) {
        opened[productID] = OpenedProduct(productID: productID, openedOn: day, monthsAfterOpening: months)
        save(opened, Key.opened)
    }

    func clearOpened(_ productID: Int) {
        opened[productID] = nil
        save(opened, Key.opened)
    }

    func expiryStatus(_ productID: Int) -> ExpiryEngine.Status? {
        opened[productID].map { ExpiryEngine.status(of: $0, today: today, calendar: calendar) }
    }

    // MARK: Lighting

    /// Tips for this scan against the user's earlier scans. Photos are measured off the main thread, once each.
    func lightingTips(for scan: ScanSession, earlier: [ScanSession]) async -> [LightingCoach.Tip] {
        let scans = Array(earlier.suffix(8)) + [scan]
        let missing: [(String, Data)] = scans.compactMap { scan in
            let key = scan.id.uuidString
            guard lighting[key] == nil,
                  let data = scan.sortedCaptures.first(where: { $0.angle == .front })?.imageData else { return nil }
            return (key, data)
        }
        if !missing.isEmpty {
            let measured = await LightingMeter.measure(missing)
            lighting.merge(measured) { _, new in new }
            save(lighting, Key.lighting)
        }
        guard let current = lighting[scan.id.uuidString] else { return [] }
        let history = scans.dropLast().compactMap { lighting[$0.id.uuidString] }
        return LightingCoach.tips(for: current, history: history)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

/// Average colour of the middle of a photo (where the face is), as brightness and warmth.
enum LightingMeter {
    @concurrent
    static func measure(_ photos: [(String, Data)]) async -> [String: ScanLighting] {
        var results: [String: ScanLighting] = [:]
        for (key, data) in photos {
            if let image = UIImage(data: data)?.cgImage, let value = measure(image) { results[key] = value }
        }
        return results
    }

    nonisolated static func measure(_ image: CGImage) -> ScanLighting? {
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let input = CIImage(cgImage: image)
        let extent = input.extent.insetBy(dx: input.extent.width * 0.25, dy: input.extent.height * 0.2)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: extent)]),
              let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        let r = Double(pixel[0]) / 255, g = Double(pixel[1]) / 255, b = Double(pixel[2]) / 255
        let brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let total = max(r + g + b, 0.001)
        return ScanLighting(brightness: brightness, warmth: (r - b) / total)
    }
}
