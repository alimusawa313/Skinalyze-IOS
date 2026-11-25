import Foundation
import SkinalyzeKit

/// Dataset layout (ML-PLAN M0.2), outside the repo (default `~/SkinalyzeData/bench`):
///
///     meta.csv                 file,subject_id,session_id,angle,fitzpatrick,lighting[,anything else]
///     images/<file>            upright JPEG or HEIC, as exported by the app (`-exportBenchPhotos YES`)
///     labels/<file stem>.txt   YOLO boxes: `class cx cy w h`, normalised, origin top-left; missing = unlabelled
///     device_detections.csv    optional, written by the app's export: what the phone counted
///
/// CSV files are plain comma-separated values without quoting; keep commas out of every field.
public enum DatasetError: Error, CustomStringConvertible, Equatable {
    case invalid(file: String, line: Int, reason: String)
    case missingFile(String)

    public var description: String {
        switch self {
        case let .invalid(file, line, reason): "\(file):\(line): \(reason)"
        case let .missingFile(path): "missing file: \(path)"
        }
    }
}

/// A labelled spot, in Vision coordinates (normalised, origin bottom-left) like the pipeline's output.
public struct LabelBox: Sendable, Hashable {
    public let type: LesionType
    public let box: ImageRect

    public init(type: LesionType, box: ImageRect) {
        self.type = type
        self.box = box
    }
}

public enum YOLOLabels {
    /// Class index → type. The order is fixed to `LesionType.allCases`; the labelling tool's class list must match.
    public static let classes = LesionType.allCases
    public static var classNames: [String] { classes.map(\.modelLabel) }

    public static func parse(_ text: String, file: String = "labels") throws -> [LabelBox] {
        try text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
            func fail(_ reason: String) -> DatasetError { .invalid(file: file, line: index + 1, reason: reason) }

            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 5 else { throw fail("expected `class cx cy w h`") }
            guard let classIndex = Int(fields[0]), classes.indices.contains(classIndex) else {
                throw fail("unknown class `\(fields[0])` (0…\(classes.count - 1))")
            }
            let values = fields.dropFirst().compactMap { Double($0) }
            guard values.count == 4, values.allSatisfy({ (0...1).contains($0) }) else {
                throw fail("box values must be numbers in 0…1")
            }
            let (cx, cy, width, height) = (values[0], values[1], values[2], values[3])
            guard width > 0, height > 0 else { throw fail("empty box") }
            return LabelBox(
                type: classes[classIndex],
                box: ImageRect(x: cx - width / 2, y: 1 - cy - height / 2, width: width, height: height)
            )
        }
    }
}

public struct SampleMeta: Sendable, Hashable {
    public let file: String
    public let subjectID: String
    public let sessionID: String
    public let angle: CaptureAngle
    /// Fitzpatrick group as written by the labeller (e.g. "IV"); blank = unknown.
    public let fitzpatrick: String
    public let lighting: String

    public init(file: String, subjectID: String, sessionID: String, angle: CaptureAngle,
                fitzpatrick: String, lighting: String) {
        self.file = file
        self.subjectID = subjectID
        self.sessionID = sessionID
        self.angle = angle
        self.fitzpatrick = fitzpatrick
        self.lighting = lighting
    }
}

/// Minimal CSV: header row, comma-separated, no quoting.
enum CSVTable {
    static func rows(_ text: String, file: String, required: [String]) throws -> [(line: Int, value: (String) -> String)] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let headerLine = lines.first else { throw DatasetError.invalid(file: file, line: 1, reason: "empty") }
        let header = headerLine.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let missing = required.filter { !header.contains($0) }
        guard missing.isEmpty else {
            throw DatasetError.invalid(file: file, line: 1, reason: "missing columns: \(missing.joined(separator: ", "))")
        }
        return lines.enumerated().dropFirst().filter { !$0.element.isEmpty }.map { index, line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let lookup: (String) -> String = { column in
                guard let position = header.firstIndex(of: column), fields.indices.contains(position) else { return "" }
                return fields[position]
            }
            return (line: index + 1, value: lookup)
        }
    }
}

public enum MetaCSV {
    static let columns = ["file", "subject_id", "session_id", "angle", "fitzpatrick", "lighting"]

    public static func parse(_ text: String) throws -> [SampleMeta] {
        let rows = try CSVTable.rows(text, file: "meta.csv", required: columns)
        let metas = try rows.map { row -> SampleMeta in
            func fail(_ reason: String) -> DatasetError { .invalid(file: "meta.csv", line: row.line, reason: reason) }
            let file = row.value("file")
            guard !file.isEmpty, !file.contains("/") else { throw fail("`file` must be a plain file name") }
            guard let angle = CaptureAngle(rawValue: row.value("angle").lowercased()) else {
                throw fail("angle must be front, right or left")
            }
            let subject = row.value("subject_id")
            guard !subject.isEmpty else { throw fail("fill in subject_id (one ID per person)") }
            return SampleMeta(
                file: file, subjectID: subject, sessionID: row.value("session_id"), angle: angle,
                fitzpatrick: row.value("fitzpatrick"), lighting: row.value("lighting")
            )
        }
        let duplicates = Dictionary(grouping: metas, by: \.file).filter { $0.value.count > 1 }.keys
        if let duplicate = duplicates.sorted().first {
            throw DatasetError.invalid(file: "meta.csv", line: 0, reason: "`\(duplicate)` is listed twice")
        }
        return metas
    }
}

/// What the phone counted for each photo (`device_detections.csv` from the app's export).
public enum DeviceDetections {
    public static func parse(_ text: String) throws -> [String: [RawDetection]] {
        let rows = try CSVTable.rows(
            text, file: "device_detections.csv",
            required: ["file", "class", "confidence", "x", "y", "width", "height"]
        )
        let pairs = try rows.map { row -> (String, RawDetection) in
            let numbers = ["confidence", "x", "y", "width", "height"].compactMap { Double(row.value($0)) }
            guard let type = LesionType(modelLabel: row.value("class")), numbers.count == 5 else {
                throw DatasetError.invalid(file: "device_detections.csv", line: row.line, reason: "unreadable row")
            }
            let box = ImageRect(x: numbers[1], y: numbers[2], width: numbers[3], height: numbers[4])
            return (row.value("file"), RawDetection(type: type, confidence: numbers[0], box: box))
        }
        return Dictionary(grouping: pairs, by: \.0).mapValues { $0.map(\.1) }
    }
}

public struct BenchSample: Sendable, Hashable {
    public let meta: SampleMeta
    public let imageURL: URL
    /// `nil` when the photo has no label file (still used for consistency).
    public let truth: [LabelBox]?
}

public enum BenchDataset {
    public static func load(root: URL) throws -> [BenchSample] {
        let metaURL = root.appending(path: "meta.csv")
        guard let metaText = try? String(contentsOf: metaURL, encoding: .utf8) else {
            throw DatasetError.missingFile(metaURL.path)
        }
        return try MetaCSV.parse(metaText).map { meta in
            let imageURL = root.appending(path: "images").appending(path: meta.file)
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                throw DatasetError.missingFile(imageURL.path)
            }
            let stem = (meta.file as NSString).deletingPathExtension
            let labelURL = root.appending(path: "labels").appending(path: stem + ".txt")
            let truth = try (try? String(contentsOf: labelURL, encoding: .utf8))
                .map { try YOLOLabels.parse($0, file: "labels/\(stem).txt") }
            return BenchSample(meta: meta, imageURL: imageURL, truth: truth)
        }
    }

    public static func deviceDetections(root: URL) throws -> [String: [RawDetection]] {
        let url = root.appending(path: "device_detections.csv")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return try DeviceDetections.parse(text)
    }
}
