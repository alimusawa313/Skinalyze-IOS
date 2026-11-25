import Foundation
import Testing
@testable import BenchCore
import SkinalyzeKit

@Suite("YOLO labels")
struct YOLOLabelTests {
    @Test("Class indices follow LesionType.allCases and boxes convert to Vision coordinates (origin bottom-left)")
    func parse() throws {
        let boxes = try YOLOLabels.parse("0 0.5 0.25 0.1 0.1\n\n5 0.2 0.8 0.04 0.02\n")
        #expect(boxes.count == 2)
        #expect(boxes[0].type == .blackhead)
        // cy 0.25 from the top → box spans 0.2…0.3 from the top → 0.7…0.8 from the bottom
        #expect(abs(boxes[0].box.x - 0.45) < 1e-9 && abs(boxes[0].box.y - 0.7) < 1e-9)
        #expect(boxes[1].type == .darkSpot)
        #expect(YOLOLabels.classNames == ["blackheads", "whiteheads", "papules", "pustules", "nodules", "dark spot"])
    }

    @Test("Malformed lines name the line", arguments: [
        "7 0.5 0.5 0.1 0.1",   // unknown class
        "0 0.5 0.5 0.1",       // missing value
        "0 1.5 0.5 0.1 0.1",   // outside the image
        "0 0.5 0.5 0 0.1",     // empty box
        "x 0.5 0.5 0.1 0.1",
    ])
    func malformed(line: String) {
        #expect(throws: DatasetError.self) { try YOLOLabels.parse("0 0.5 0.5 0.1 0.1\n" + line) }
    }
}

@Suite("meta.csv")
struct MetaCSVTests {
    private let header = "file,subject_id,session_id,angle,fitzpatrick,lighting"

    @Test("Parses rows by header name; extra columns are ignored")
    func parse() throws {
        let rows = try MetaCSV.parse("""
        file,subject_id,session_id,angle,fitzpatrick,lighting,captured_at
        a_front.heic,S01,a,front,IV,indoor,2026-11-25
        a_right.heic, S01 ,a,right,,window,
        """)
        #expect(rows.count == 2)
        #expect(rows[0] == SampleMeta(file: "a_front.heic", subjectID: "S01", sessionID: "a", angle: .front,
                                      fitzpatrick: "IV", lighting: "indoor"))
        #expect(rows[1].subjectID == "S01")
        #expect(rows[1].fitzpatrick == "", "blank groups are allowed and reported as unknown")
    }

    @Test("Rejects missing columns, unknown angles, blank subjects and duplicate files", arguments: [
        "file,subject_id,angle\na.jpg,S1,front",
        "file,subject_id,session_id,angle,fitzpatrick,lighting\na.jpg,S1,s,up,,",
        "file,subject_id,session_id,angle,fitzpatrick,lighting\na.jpg,,s,front,,",
        "file,subject_id,session_id,angle,fitzpatrick,lighting\na.jpg,S1,s,front,,\na.jpg,S1,s,left,,",
    ])
    func invalid(text: String) {
        #expect(throws: DatasetError.self) { try MetaCSV.parse(text) }
    }
}

@Suite("Dataset folder")
struct DatasetFolderTests {
    @Test("Loads images, labels for labelled photos only, and fails on a missing image")
    func load() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "bench-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default
        try fm.createDirectory(at: root.appending(path: "images"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appending(path: "labels"), withIntermediateDirectories: true)
        try Data([0xFF]).write(to: root.appending(path: "images/a_front.jpg"))
        try Data([0xFF]).write(to: root.appending(path: "images/a_left.jpg"))
        try "2 0.5 0.5 0.1 0.1\n".write(to: root.appending(path: "labels/a_front.txt"), atomically: true, encoding: .utf8)
        try """
        file,subject_id,session_id,angle,fitzpatrick,lighting
        a_front.jpg,S1,a,front,III,indoor
        a_left.jpg,S1,a,left,III,indoor
        """.write(to: root.appending(path: "meta.csv"), atomically: true, encoding: .utf8)

        let samples = try BenchDataset.load(root: root)
        #expect(samples.count == 2)
        #expect(samples[0].truth?.map(\.type) == [.papule])
        #expect(samples[1].truth == nil, "no label file = unlabelled (still used for consistency)")

        try fm.removeItem(at: root.appending(path: "images/a_left.jpg"))
        #expect(throws: DatasetError.self) { try BenchDataset.load(root: root) }
    }

    @Test("Device detections exported by the app are read per file")
    func deviceDetections() throws {
        let rows = try DeviceDetections.parse("""
        file,class,confidence,x,y,width,height
        a_front.heic,papules,0.8,0.1,0.2,0.01,0.01
        a_front.heic,dark spot,0.5,0.3,0.2,0.01,0.01
        """)
        #expect(rows["a_front.heic"]?.map(\.type) == [.papule, .darkSpot])
    }
}

@Suite("Options")
struct OptionsTests {
    @Test("Defaults are the shipping pipeline")
    func defaults() throws {
        let options = try BenchOptions.parse(["--data", "/d", "--model", "/m.mlmodel"])
        #expect(options.variant == "baseline")
        #expect(options.configuration == .baseline)
        #expect(options.modelConfidenceFloor == nil)
    }

    @Test("Variant flags build the pipeline configuration")
    func variants() throws {
        let options = try BenchOptions.parse([
            "--data", "/d", "--model", "/m.mlmodel", "--variant", "tiles",
            "--tiles", "3x3", "--overlap", "0.25", "--no-whole-crop", "--mask-landmarks", "--color-normalize",
            "--iou", "0.5", "--model-floor", "0.05",
        ])
        #expect(options.configuration.tiling == Tiling(grid: 3, overlap: 0.25, includesWholeCrop: false))
        #expect(options.configuration.masksLandmarks)
        #expect(options.configuration.normalizesColor)
        #expect(options.configuration.iouThreshold == 0.5)
        #expect(options.modelConfidenceFloor == 0.05)
        #expect(options.variant == "tiles")
    }

    @Test("Tiling defaults to the whole-crop pass plus 20% overlap")
    func tilingDefaults() throws {
        let options = try BenchOptions.parse(["--data", "/d", "--model", "/m", "--tiles", "2x2"])
        #expect(options.configuration.tiling == .twoByTwoWithWhole)
    }

    @Test("Bad input fails with a message", arguments: [
        ["--model", "/m"],
        ["--data", "/d"],
        ["--data", "/d", "--model", "/m", "--tiles", "2x3"],
        ["--data", "/d", "--model", "/m", "--overlap", "abc"],
        ["--data", "/d", "--model", "/m", "--wat"],
        ["--data", "/d", "--model", "/m", "--variant", "../evil"],
    ])
    func invalid(arguments: [String]) {
        #expect(throws: BenchOptions.ParseError.self) { try BenchOptions.parse(arguments) }
    }

    @Test("Class thresholds JSON is keyed by model label; unknown labels are rejected")
    func thresholds() throws {
        let thresholds = try BenchOptions.classThresholds(json: Data(#"{"nodules": 0.7, "blackheads": 0.25}"#.utf8))
        #expect(thresholds[.nodule] == 0.7)
        #expect(thresholds[.blackhead] == 0.25)
        #expect(thresholds[.papule] == DetectionFilter.defaultMinConfidence)
        #expect(throws: BenchOptions.ParseError.self) {
            try BenchOptions.classThresholds(json: Data(#"{"zits": 0.5}"#.utf8))
        }
    }
}
