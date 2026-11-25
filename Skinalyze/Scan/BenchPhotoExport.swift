#if DEBUG
import Foundation
import ImageIO
import OSLog
import SwiftData
import UniformTypeIdentifiers
import SkinalyzeKit

/// Debug-only export of scan photos for the detector benchmark (ML-PLAN M0.5). Only for photos of people who gave
/// written consent; nothing leaves the phone — the owner copies the folder off with Xcode.
///
/// Launch with `-exportBenchPhotos YES`. Writes `Documents/BenchExport/` in the layout `Tools/DetectorBench` reads:
/// `images/`, `meta.csv` (fill in `subject_id`, `fitzpatrick`, `lighting` by hand) and `device_detections.csv` (what
/// the phone counted, to check the Mac gives the same answer). Hidden (vault) scans are skipped. Copy it off with
/// Xcode → Devices and Simulators → Skinalyze → Download Container.
enum BenchPhotoExport {
    static let defaultsKey = "exportBenchPhotos"
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "BenchExport")

    @MainActor
    static func runIfRequested(container: ModelContainer) {
        guard UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        do {
            let folder = try export(from: container.mainContext)
            logger.notice("[bench] exported scan photos to \(folder.path, privacy: .public)")
        } catch {
            logger.error("[bench] export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private static func export(from context: ModelContext) throws -> URL {
        let descriptor = FetchDescriptor<ScanSession>(sortBy: [SortDescriptor(\.createdAt)])
        let sessions = try context.fetch(descriptor).filter { !$0.isHidden && $0.captureMode != .legacy }

        let folder = URL.documentsDirectory.appending(path: "BenchExport", directoryHint: .isDirectory)
        let images = folder.appending(path: "images", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)

        let rows = try sessions.flatMap { session in try exportRows(for: session, into: images) }
        try write(csv: [Self.metaHeader] + rows.map(\.meta), to: folder.appending(path: "meta.csv"))
        try write(csv: [Self.detectionHeader] + rows.flatMap(\.detections),
                  to: folder.appending(path: "device_detections.csv"))
        return folder
    }

    static let metaHeader = "file,subject_id,session_id,angle,fitzpatrick,lighting,captured_at,pipeline_version"
    static let detectionHeader = "file,class,confidence,x,y,width,height"

    private struct Rows {
        let meta: String
        let detections: [String]
    }

    @MainActor
    private static func exportRows(for session: ScanSession, into images: URL) throws -> [Rows] {
        let sessionID = String(session.id.uuidString.prefix(8))
        let date = session.createdAt.formatted(.iso8601)
        return try session.sortedCaptures.compactMap { capture -> Rows? in
            guard let data = capture.imageData else { return nil }
            let file = "\(sessionID)_\(capture.angle.rawValue).\(fileExtension(of: data))"
            try data.write(to: images.appending(path: file))
            let detections = session.allDetections
                .filter { $0.angle == capture.angle }
                .compactMap { detection -> String? in
                    guard let type = detection.lesionType else { return nil }
                    let box = detection.box
                    return [file, type.modelLabel, "\(detection.confidence)",
                            "\(box.x)", "\(box.y)", "\(box.width)", "\(box.height)"].joined(separator: ",")
                }
            let meta = [file, "", sessionID, capture.angle.rawValue, "", "", date, session.pipelineVersion ?? ""]
                .joined(separator: ",")
            return Rows(meta: meta, detections: detections)
        }
    }

    private static func fileExtension(of data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier)
        else { return "jpg" }
        return type.preferredFilenameExtension ?? "jpg"
    }

    private static func write(csv lines: [String], to url: URL) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
