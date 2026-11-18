/// Immutable per-type lesion counts.
public struct LesionCounts: Sendable, Hashable, Codable {
    private let storage: [LesionType: Int]

    public init(_ counts: [LesionType: Int] = [:]) {
        storage = counts.filter { $0.value > 0 }
    }

    /// Builds counts from raw model labels; unknown labels are ignored.
    public init(modelLabels: some Sequence<String>) {
        let types = modelLabels.compactMap(LesionType.init(modelLabel:))
        self.init(Dictionary(types.map { ($0, 1) }, uniquingKeysWith: +))
    }

    /// Builds counts from the legacy `[String: Int]` dictionary stored on `Result.acneCounts`.
    public init(legacyDictionary: [String: Int]) {
        let pairs = legacyDictionary.compactMap { label, count in
            LesionType(modelLabel: label).map { ($0, max(count, 0)) }
        }
        self.init(Dictionary(pairs, uniquingKeysWith: +))
    }

    public subscript(type: LesionType) -> Int { storage[type, default: 0] }

    public var total: Int { storage.values.reduce(0, +) }

    /// The legacy dictionary shape, with every type present (zeros included), as the app has always stored it.
    public var legacyDictionary: [String: Int] {
        Dictionary(uniqueKeysWithValues: LesionType.allCases.map { ($0.modelLabel, self[$0]) })
    }

    /// Returns new counts that sum `self` and `other`.
    public func adding(_ other: LesionCounts) -> LesionCounts {
        LesionCounts(storage.merging(other.storage, uniquingKeysWith: +))
    }
}
