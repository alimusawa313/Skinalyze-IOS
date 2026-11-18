/// The app's original 0–5 severity scale (shipped as "GEA"), preserved so existing scans keep their meaning.
///
/// It is **not** a clinical GEA grade. The redesign replaces it with the zone-based Breakout Index
/// (PLAN.md §11.1); this type stays for legacy scans and comparisons.
///
/// Fix vs. the shipped version: blackheads are now counted (the old code read the key `"blackhead"` while the
/// stored key is `"blackheads"`, so blackhead-only faces scored 0).
public enum LegacySeverityScale {
    public static let range = 0...5

    private enum Threshold {
        static let nodulesVerySevere = 5
        static let nodulesExtreme = 10
        static let pustulesVerySevere = 10
        static let pustulesExtreme = 15
        static let pustulesSevere = 5
        static let papulesSevere = 10
        static let papulesModerate = 5
        static let comedonesModerate = 10
    }

    public static func score(for counts: LesionCounts) -> Int {
        let papules = counts[.papule]
        let pustules = counts[.pustule]
        let nodules = counts[.nodule]
        let blackheads = counts[.blackhead]
        let whiteheads = counts[.whitehead]

        if nodules > Threshold.nodulesVerySevere || pustules > Threshold.pustulesVerySevere {
            let isExtreme = nodules > Threshold.nodulesExtreme || pustules > Threshold.pustulesExtreme
            return isExtreme ? 5 : 4
        }
        if pustules > Threshold.pustulesSevere || papules > Threshold.papulesSevere {
            return 3
        }
        if papules > Threshold.papulesModerate
            || blackheads > Threshold.comedonesModerate
            || whiteheads > Threshold.comedonesModerate {
            return 2
        }
        let breakoutTotal = papules + pustules + nodules + blackheads + whiteheads
        return breakoutTotal == 0 ? 0 : 1
    }
}
