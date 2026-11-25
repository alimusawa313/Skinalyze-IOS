import CoreGraphics

/// Runs the detector on overlapping tiles of the face crop instead of the whole crop squeezed to the model's 416 px
/// input, so small spots keep more pixels (ML-PLAN M1.1).
public struct Tiling: Sendable, Hashable {
    /// Tiles per side: `grid × grid` runs. `1` means the whole crop in one run.
    public let grid: Int
    /// Share of a tile that overlaps its neighbour (0…0.5).
    public let overlap: Double
    /// Adds one extra run over the whole crop, so lesions larger than the overlap band are still seen whole.
    public let includesWholeCrop: Bool

    public static let maxOverlap = 0.5

    /// One run over the whole crop (the behaviour before tiling).
    public static let none = Tiling(grid: 1, overlap: 0, includesWholeCrop: false)
    /// First candidate from ML-PLAN M1.1: 2×2 tiles with 20% overlap plus the whole crop (5 runs per photo).
    public static let twoByTwoWithWhole = Tiling(grid: 2, overlap: 0.2, includesWholeCrop: true)

    public init(grid: Int, overlap: Double, includesWholeCrop: Bool) {
        let clampedGrid = max(grid, 1)
        self.grid = clampedGrid
        self.overlap = clampedGrid > 1 ? min(max(overlap, 0), Self.maxOverlap) : 0
        self.includesWholeCrop = clampedGrid > 1 && includesWholeCrop
    }

    /// Model runs per photo — the number that matters for the time budget.
    public var runsPerImage: Int { grid * grid + (includesWholeCrop ? 1 : 0) }

    /// Tiles in crop-local, top-left-origin pixel coordinates. Grid tiles come first (row by row), the whole-crop
    /// run last. Grid tiles have the same size and together cover the crop exactly.
    public func tiles(in size: CGSize) -> [Tile] {
        let whole = Tile(rect: CGRect(origin: .zero, size: size), interiorEdges: [])
        guard grid > 1 else { return [whole] }

        let count = Double(grid)
        let span: Double = count - (count - 1) * overlap
        let tileWidth: Double = size.width / span
        let tileHeight: Double = size.height / span
        let stepX: Double = tileWidth * (1 - overlap)
        let stepY: Double = tileHeight * (1 - overlap)
        let last = grid - 1
        let cells: [(row: Int, column: Int)] = (0..<grid).flatMap { row in (0..<grid).map { (row, $0) } }
        let gridTiles: [Tile] = cells.map { cell in
            let rect = CGRect(
                x: Double(cell.column) * stepX,
                y: Double(cell.row) * stepY,
                width: tileWidth,
                height: tileHeight
            )
            return Tile(rect: rect, interiorEdges: TileEdges(row: cell.row, column: cell.column, last: last))
        }
        return includesWholeCrop ? gridTiles + [whole] : gridTiles
    }
}

/// Edges of a tile, in top-left-origin terms (`top` is the smaller y).
public struct TileEdges: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let top = TileEdges(rawValue: 1 << 0)
    public static let bottom = TileEdges(rawValue: 1 << 1)
    public static let left = TileEdges(rawValue: 1 << 2)
    public static let right = TileEdges(rawValue: 1 << 3)

    /// Edges shared with a neighbouring tile for the tile at `row`, `column` in a grid whose last index is `last`.
    init(row: Int, column: Int, last: Int) {
        let edges: [(Bool, TileEdges)] = [
            (row > 0, .top), (row < last, .bottom), (column > 0, .left), (column < last, .right),
        ]
        self = edges.reduce(into: TileEdges()) { result, entry in
            if entry.0 { result.insert(entry.1) }
        }
    }
}

public struct Tile: Sendable, Hashable {
    /// Crop-local, top-left-origin pixel rectangle.
    public let rect: CGRect
    /// Edges shared with a neighbouring tile (the crop's own border is never a seam).
    public let interiorEdges: TileEdges

    public init(rect: CGRect, interiorEdges: TileEdges) {
        self.rect = rect
        self.interiorEdges = interiorEdges
    }

    /// How close (as a share of the tile) a box edge must be to a seam to count as cut by it.
    public static let seamTolerance = 0.01

    /// `true` when a box (normalised to this tile, Vision bottom-left origin) touches an edge shared with a
    /// neighbouring tile. The neighbour sees that lesion whole (the overlap is wider than a spot), and the
    /// whole-crop run sees large ones, so the cut copy is dropped.
    public func cutsAtSeam(_ box: ImageRect) -> Bool {
        let tolerance = Self.seamTolerance
        return (interiorEdges.contains(.left) && box.x <= tolerance)
            || (interiorEdges.contains(.right) && box.x + box.width >= 1 - tolerance)
            || (interiorEdges.contains(.bottom) && box.y <= tolerance)
            || (interiorEdges.contains(.top) && box.y + box.height >= 1 - tolerance)
    }
}
