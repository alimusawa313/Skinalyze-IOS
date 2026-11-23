import CoreGraphics
import Foundation
import Testing
@testable import SkinalyzeKit

/// The zone heat map over time and the "this area over time" crops.
@Suite("Zone map and area crops")
struct ZoneMapTests {
    // MARK: Heat

    @Test("Levels are shares of the busiest zone across all scans, so dates compare fairly")
    func levelsShareOneScale() {
        let scans: [[FaceZone: Int]] = [[.chin: 8, .forehead: 2], [.chin: 4], [:]]
        let levels = ZoneHeat.levels(scans)
        #expect(levels[0][.chin] == 1)
        #expect(levels[0][.forehead] == 0.25)
        #expect(levels[1][.chin] == 0.5)
        #expect(levels[2].values.allSatisfy { $0 == 0 })
        #expect(levels.allSatisfy { Set($0.keys) == Set(FaceZone.allCases) })
    }

    @Test("Scans with nothing marked anywhere are all zero, not a division by zero")
    func allQuiet() {
        let levels = ZoneHeat.levels([[:], [:]])
        #expect(levels.allSatisfy { $0.values.allSatisfy { $0 == 0 } })
    }

    @Test("Every zone has an anchor inside the face, with the cheeks and jaw mirrored")
    func anchors() {
        for zone in FaceZone.allCases {
            let p = ZoneHeat.anchor(zone)
            #expect((0...1).contains(p.x) && (0...1).contains(p.y))
        }
        #expect(abs(ZoneHeat.anchor(.leftCheek).x + ZoneHeat.anchor(.rightCheek).x - 1) < 1e-9)
        #expect(abs(ZoneHeat.anchor(.leftJaw).x + ZoneHeat.anchor(.rightJaw).x - 1) < 1e-9)
        #expect(ZoneHeat.anchor(.forehead).y < ZoneHeat.anchor(.nose).y)
        #expect(ZoneHeat.anchor(.nose).y < ZoneHeat.anchor(.chin).y)
    }

    // MARK: Area crops

    @Test("The crop is centred on the tapped spot and kept inside the photo")
    func cropStaysInside() {
        let frame = CGSize(width: 900, height: 1200)
        let middle = AreaCrop.rect(around: CGPoint(x: 450, y: 600), in: frame)
        #expect(middle.midX == 450 && middle.midY == 600)
        let corner = AreaCrop.rect(around: CGPoint(x: 10, y: 1190), in: frame)
        #expect(corner.minX == 0)
        #expect(corner.maxY == 1200)
        #expect(corner.width == middle.width)
    }

    @Test("Only spots inside the crop are marked, placed relative to the crop")
    func marksInside() {
        let crop = CGRect(x: 100, y: 100, width: 200, height: 200)
        let marks = AreaCrop.marks([CGPoint(x: 200, y: 200), CGPoint(x: 500, y: 500)], in: crop)
        #expect(marks == [CGPoint(x: 0.5, y: 0.5)])
    }
}
