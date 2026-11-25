import Foundation
import SkinalyzeKit

/// Command-line options. Each M1 change is a flag, so variants can be compared side by side.
public struct BenchOptions: Sendable {
    public let dataURL: URL
    public let modelURL: URL
    public let variant: String
    /// `nil`: write to the repo's `docs/redesign/benchmarks/`.
    public let outputURL: URL?
    public let configuration: DetectionPipeline.Configuration
    /// Overrides the model's own confidence floor so per-class thresholds below it can take effect.
    public let modelConfidenceFloor: Double?
    public let cpuOnly: Bool

    public enum ParseError: Error, CustomStringConvertible {
        case message(String)

        public var description: String {
            switch self {
            case let .message(text): "\(text)\n\n\(BenchOptions.usage)"
            }
        }
    }

    public static let usage = """
    Usage: swift run -c release DetectorBench --data DIR --model FILE.mlmodel [options]

      --variant NAME            report name (letters, digits, . _ -); default "baseline"
      --out DIR                 where to write NAME.md / NAME.json; default docs/redesign/benchmarks
      --tiles NxN               run on N×N overlapping tiles of the face crop (M1.1)
      --overlap F               tile overlap, 0…0.5; default 0.2
      --no-whole-crop           with --tiles: skip the extra whole-crop run
      --class-thresholds FILE   JSON {"papules": 0.5, …} keyed by model label (M1.3)
      --model-floor F           lower the model's own confidence floor (needed for thresholds below it)
      --iou F                   cross-class NMS IoU; default 0.45
      --mask-landmarks          drop detections on eyes, brows, lips, nostrils, outside the face (M1.2)
      --color-normalize         white balance + exposure normalisation of the crop (M1.4)
      --cpu-only                run Core ML on the CPU (to compare against GPU/Neural Engine results)
    """

    private static let flags: Set<String> = ["--no-whole-crop", "--mask-landmarks", "--color-normalize", "--cpu-only"]
    private static let valued: Set<String> = [
        "--data", "--model", "--variant", "--out", "--tiles", "--overlap", "--class-thresholds", "--model-floor", "--iou",
    ]

    public static func parse(
        _ arguments: [String],
        readFile: (String) throws -> Data = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    ) throws -> BenchOptions {
        let (values, switches) = try split(arguments)
        guard let data = values["--data"], let model = values["--model"] else {
            throw ParseError.message("--data and --model are required")
        }
        let variant = values["--variant"] ?? "baseline"
        guard variant.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil else {
            throw ParseError.message("--variant may only use letters, digits, . _ -")
        }
        let thresholds = try values["--class-thresholds"]
            .map { path in try classThresholds(json: try readFile(path)) } ?? DetectionFilter.classThresholds

        return BenchOptions(
            dataURL: URL(fileURLWithPath: (data as NSString).expandingTildeInPath),
            modelURL: URL(fileURLWithPath: (model as NSString).expandingTildeInPath),
            variant: variant,
            outputURL: values["--out"].map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) },
            configuration: DetectionPipeline.Configuration(
                tiling: try tiling(values["--tiles"],
                                   overlap: try number(values["--overlap"], name: "--overlap"),
                                   includesWholeCrop: !switches.contains("--no-whole-crop")),
                thresholds: thresholds,
                iouThreshold: try number(values["--iou"], name: "--iou") ?? DetectionFilter.defaultIoUThreshold,
                masksLandmarks: switches.contains("--mask-landmarks"),
                normalizesColor: switches.contains("--color-normalize")
            ),
            modelConfidenceFloor: try number(values["--model-floor"], name: "--model-floor"),
            cpuOnly: switches.contains("--cpu-only")
        )
    }

    public static func classThresholds(json: Data) throws -> ClassThresholds {
        guard let object = try? JSONDecoder().decode([String: Double].self, from: json) else {
            throw ParseError.message("class thresholds must be a JSON object of label → number")
        }
        let pairs = try object.map { label, value -> (LesionType, Double) in
            guard let type = LesionType(modelLabel: label) else {
                let known = LesionType.allCases.map(\.modelLabel).joined(separator: ", ")
                throw ParseError.message("unknown class `\(label)`; use one of: \(known)")
            }
            guard (0...1).contains(value) else { throw ParseError.message("threshold for \(label) must be 0…1") }
            return (type, value)
        }
        return ClassThresholds(Dictionary(pairs, uniquingKeysWith: { $1 }))
    }

    private static func split(_ arguments: [String]) throws -> (values: [String: String], switches: Set<String>) {
        var values: [String: String] = [:]
        var switches: Set<String> = []
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            if argument == "--help" || argument == "-h" { throw ParseError.message("") }
            if flags.contains(argument) {
                switches.insert(argument)
            } else if valued.contains(argument) {
                guard let value = remaining.popFirst() else { throw ParseError.message("\(argument) needs a value") }
                values[argument] = value
            } else {
                throw ParseError.message("unknown option \(argument)")
            }
        }
        return (values, switches)
    }

    private static func number(_ text: String?, name: String) throws -> Double? {
        guard let text else { return nil }
        guard let value = Double(text), (0...1).contains(value) else {
            throw ParseError.message("\(name) must be a number in 0…1")
        }
        return value
    }

    private static func tiling(_ text: String?, overlap: Double?, includesWholeCrop: Bool) throws -> Tiling {
        guard let text else { return .none }
        let sides = text.lowercased().split(separator: "x").compactMap { Int($0) }
        guard sides.count == 2, sides[0] == sides[1], (1...4).contains(sides[0]) else {
            throw ParseError.message("--tiles must be a square grid like 2x2 or 3x3")
        }
        return Tiling(grid: sides[0], overlap: overlap ?? Tiling.twoByTwoWithWhole.overlap,
                      includesWholeCrop: includesWholeCrop)
    }
}
