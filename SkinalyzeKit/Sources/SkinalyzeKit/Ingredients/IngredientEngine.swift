import Foundation

// MARK: - Knowledge

public enum IngredientCategory: String, CaseIterable, Sendable, Hashable, Codable {
    case humectant, emollient, barrier, exfoliantAHA, exfoliantBHA, retinoid, benzoylPeroxide, azelaicAcid
    case niacinamide, vitaminC, soothing, fragrance, essentialOil, dryingAlcohol, harshSurfactant, comedogenicOil
}

public struct IngredientEntry: Sendable, Hashable {
    public let name: String
    public let aliases: [String]
    public let categories: Set<IngredientCategory>
}

/// A curated knowledge base of common actives, basics and irritants (PLAN.md §11.6), spelled the way INCI labels and
/// Indonesian product pages write them. Intentionally conservative: unknown ingredients are neutral, never guessed —
/// pH adjusters (citric acid), preservatives (phenoxyethanol, benzyl alcohol), fatty alcohols, sunscreen filters and
/// look-alike surfactants (cocamidopropyl betaine) are deliberately absent.
public enum IngredientKnowledge {
    public static let entries: [IngredientEntry] = [
        // Humectants
        IngredientEntry(name: "Glycerin", aliases: ["glycerine", "glycerol", "gliserin", "gliserol"], categories: [.humectant]),
        IngredientEntry(name: "Diglycerin", aliases: ["polyglycerin-3", "polyglycerin-10"], categories: [.humectant]),
        IngredientEntry(name: "Hyaluronic acid", aliases: ["sodium hyaluronate", "hyaluronan", "hydrolyzed hyaluronic acid", "hydrolyzed sodium hyaluronate", "sodium hyaluronate crosspolymer", "sodium acetylated hyaluronate", "potassium hyaluronate", "hydroxypropyltrimonium hyaluronate", "asam hialuronat"], categories: [.humectant]),
        IngredientEntry(name: "Panthenol", aliases: ["provitamin b5", "d-panthenol", "dexpanthenol", "pantenol"], categories: [.humectant, .soothing]),
        IngredientEntry(name: "Butylene glycol", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Propylene glycol", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Propanediol", aliases: ["1,3-propanediol"], categories: [.humectant]),
        IngredientEntry(name: "Pentylene glycol", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Sodium PCA", aliases: ["pca"], categories: [.humectant]),
        IngredientEntry(name: "Urea", aliases: ["hydroxyethyl urea"], categories: [.humectant]),
        IngredientEntry(name: "Sodium lactate", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Trehalose", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Sorbitol", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Xylitol", aliases: ["xylitylglucoside", "anhydroxylitol"], categories: [.humectant]),
        IngredientEntry(name: "Saccharide isomerate", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Polyglutamic acid", aliases: ["sodium polyglutamate"], categories: [.humectant]),
        IngredientEntry(name: "Glycereth-26", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Methyl gluceth-20", aliases: [], categories: [.humectant]),
        IngredientEntry(name: "Honey", aliases: ["mel", "mel extract", "honey extract"], categories: [.humectant]),

        // Barrier lipids
        IngredientEntry(name: "Ceramides", aliases: ["ceramide", "ceramide np", "ceramide ap", "ceramide eop", "ceramide ns", "ceramide as", "ceramide ng", "ceramide eos", "ceramide 1", "ceramide 2", "ceramide 3", "ceramide 6 ii"], categories: [.barrier]),
        IngredientEntry(name: "Pseudo-ceramides", aliases: ["hydroxypalmitoyl sphinganine", "cetyl-pg hydroxyethyl palmitamide", "caprooyl phytosphingosine", "caprooyl sphingosine"], categories: [.barrier]),
        IngredientEntry(name: "Cholesterol", aliases: [], categories: [.barrier]),
        IngredientEntry(name: "Phytosphingosine", aliases: [], categories: [.barrier]),
        IngredientEntry(name: "Sphingolipids", aliases: ["glycosphingolipids"], categories: [.barrier]),

        // Emollients
        IngredientEntry(name: "Squalane", aliases: [], categories: [.emollient]),
        IngredientEntry(name: "Mineral oil", aliases: ["paraffinum liquidum", "liquid paraffin", "paraffin oil"], categories: [.emollient]),
        IngredientEntry(name: "Petrolatum", aliases: ["petroleum jelly", "vaseline", "white petrolatum"], categories: [.emollient, .barrier]),
        IngredientEntry(name: "Dimethicone", aliases: [], categories: [.emollient]),
        IngredientEntry(name: "Shea butter", aliases: ["butyrospermum parkii butter", "butyrospermum parkii oil"], categories: [.emollient]),
        IngredientEntry(name: "Caprylic/capric triglyceride", aliases: ["caprylic capric triglyceride"], categories: [.emollient]),
        IngredientEntry(name: "Jojoba oil", aliases: ["simmondsia chinensis seed oil", "simmondsia chinensis oil", "jojoba esters"], categories: [.emollient]),
        IngredientEntry(name: "Sunflower seed oil", aliases: ["helianthus annuus seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Argan oil", aliases: ["argania spinosa kernel oil"], categories: [.emollient]),
        IngredientEntry(name: "Rosehip oil", aliases: ["rosa canina fruit oil", "rosa rubiginosa seed oil", "rosa canina seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Sweet almond oil", aliases: ["prunus amygdalus dulcis oil"], categories: [.emollient]),
        IngredientEntry(name: "Meadowfoam seed oil", aliases: ["limnanthes alba seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Avocado oil", aliases: ["persea gratissima oil"], categories: [.emollient]),
        IngredientEntry(name: "Olive oil", aliases: ["olea europaea fruit oil"], categories: [.emollient]),
        IngredientEntry(name: "Safflower seed oil", aliases: ["carthamus tinctorius seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Grape seed oil", aliases: ["vitis vinifera seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Apricot kernel oil", aliases: ["prunus armeniaca kernel oil"], categories: [.emollient]),
        IngredientEntry(name: "Camellia seed oil", aliases: ["camellia japonica seed oil", "camellia sinensis seed oil", "camellia oleifera seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Hemp seed oil", aliases: ["cannabis sativa seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Rice bran oil", aliases: ["oryza sativa bran oil"], categories: [.emollient]),
        IngredientEntry(name: "Macadamia oil", aliases: ["macadamia integrifolia seed oil", "macadamia ternifolia seed oil"], categories: [.emollient]),
        IngredientEntry(name: "Isononyl isononanoate", aliases: [], categories: [.emollient]),
        IngredientEntry(name: "C12-15 alkyl benzoate", aliases: [], categories: [.emollient]),
        IngredientEntry(name: "Hydrogenated polyisobutene", aliases: [], categories: [.emollient]),
        IngredientEntry(name: "Dicaprylyl carbonate", aliases: [], categories: [.emollient]),
        IngredientEntry(name: "Coco-caprylate/caprate", aliases: ["coco-caprylate"], categories: [.emollient]),
        IngredientEntry(name: "Octyldodecanol", aliases: [], categories: [.emollient]),

        // Exfoliating acids
        IngredientEntry(name: "Glycolic acid", aliases: ["asam glikolat"], categories: [.exfoliantAHA]),
        IngredientEntry(name: "Lactic acid", aliases: ["asam laktat"], categories: [.exfoliantAHA]),
        IngredientEntry(name: "Mandelic acid", aliases: [], categories: [.exfoliantAHA]),
        IngredientEntry(name: "AHA", aliases: ["ahas", "alpha hydroxy acid", "alpha hydroxy acids"], categories: [.exfoliantAHA]),
        IngredientEntry(name: "Gluconolactone", aliases: ["pha", "polyhydroxy acid"], categories: [.exfoliantAHA]),
        IngredientEntry(name: "Lactobionic acid", aliases: [], categories: [.exfoliantAHA]),
        // Not "bha": on INCI lists BHA is the antioxidant butylated hydroxyanisole, not a beta hydroxy acid.
        IngredientEntry(name: "Salicylic acid", aliases: ["beta hydroxy acid", "asam salisilat"], categories: [.exfoliantBHA]),
        IngredientEntry(name: "Betaine salicylate", aliases: [], categories: [.exfoliantBHA]),
        IngredientEntry(name: "Capryloyl salicylic acid", aliases: ["lha"], categories: [.exfoliantBHA]),
        IngredientEntry(name: "Sodium salicylate", aliases: [], categories: [.exfoliantBHA]),

        // Retinoids
        IngredientEntry(name: "Retinol", aliases: ["vitamin a"], categories: [.retinoid]),
        IngredientEntry(name: "Retinal", aliases: ["retinaldehyde"], categories: [.retinoid]),
        IngredientEntry(name: "Retinyl esters", aliases: ["retinyl palmitate", "retinyl acetate", "retinyl propionate", "retinyl linoleate", "vitamin a palmitate"], categories: [.retinoid]),
        IngredientEntry(name: "Retinyl retinoate", aliases: [], categories: [.retinoid]),
        IngredientEntry(name: "Hydroxypinacolone retinoate", aliases: ["granactive retinoid"], categories: [.retinoid]),
        IngredientEntry(name: "Adapalene", aliases: [], categories: [.retinoid]),
        IngredientEntry(name: "Tretinoin", aliases: ["retinoic acid", "all-trans retinoic acid"], categories: [.retinoid]),
        IngredientEntry(name: "Tazarotene", aliases: [], categories: [.retinoid]),
        IngredientEntry(name: "Trifarotene", aliases: [], categories: [.retinoid]),

        // Other actives
        IngredientEntry(name: "Benzoyl peroxide", aliases: ["hydrous benzoyl peroxide", "benzoil peroksida"], categories: [.benzoylPeroxide]),
        IngredientEntry(name: "Azelaic acid", aliases: ["asam azelat"], categories: [.azelaicAcid]),
        IngredientEntry(name: "Niacinamide", aliases: ["nicotinamide", "vitamin b3", "niasinamida"], categories: [.niacinamide]),
        IngredientEntry(name: "Vitamin C", aliases: ["ascorbic acid", "l-ascorbic acid", "asam askorbat", "sodium ascorbate"], categories: [.vitaminC]),
        IngredientEntry(name: "Ascorbyl phosphates", aliases: ["sodium ascorbyl phosphate", "magnesium ascorbyl phosphate"], categories: [.vitaminC]),
        IngredientEntry(name: "Ascorbyl glucoside", aliases: [], categories: [.vitaminC]),
        IngredientEntry(name: "Ethyl ascorbic acid", aliases: ["3-o-ethyl ascorbic acid"], categories: [.vitaminC]),
        IngredientEntry(name: "Tetrahexyldecyl ascorbate", aliases: ["ascorbyl tetraisopalmitate"], categories: [.vitaminC]),

        // Soothing
        IngredientEntry(name: "Centella asiatica", aliases: ["cica", "gotu kola"], categories: [.soothing]),
        IngredientEntry(name: "Madecassoside", aliases: ["madecassic acid"], categories: [.soothing]),
        IngredientEntry(name: "Asiaticoside", aliases: ["asiatic acid"], categories: [.soothing]),
        IngredientEntry(name: "Allantoin", aliases: ["alantoin"], categories: [.soothing]),
        IngredientEntry(name: "Bisabolol", aliases: ["alpha-bisabolol", "levomenol"], categories: [.soothing]),
        IngredientEntry(name: "Green tea extract", aliases: ["camellia sinensis leaf extract", "camellia sinensis leaf water", "camellia sinensis leaf", "camellia sinensis extract", "teh hijau"], categories: [.soothing]),
        IngredientEntry(name: "Aloe vera", aliases: ["aloe barbadensis", "aloe barbadensis leaf juice", "aloe barbadensis leaf extract", "lidah buaya"], categories: [.soothing]),
        IngredientEntry(name: "Licorice root extract", aliases: ["glycyrrhiza glabra root extract", "glycyrrhiza glabra", "glycyrrhiza inflata", "glycyrrhiza uralensis"], categories: [.soothing]),
        IngredientEntry(name: "Glycyrrhizate", aliases: ["dipotassium glycyrrhizate", "ammonium glycyrrhizate", "potassium glycyrrhizinate", "stearyl glycyrrhetinate"], categories: [.soothing]),
        IngredientEntry(name: "Oat", aliases: ["avena sativa kernel flour", "avena sativa kernel extract", "avena sativa", "colloidal oatmeal"], categories: [.soothing]),
        IngredientEntry(name: "Calendula", aliases: ["calendula officinalis flower extract", "calendula officinalis extract", "calendula officinalis"], categories: [.soothing]),
        IngredientEntry(name: "Chamomile extract", aliases: ["chamomilla recutita flower extract", "chamomilla recutita extract", "matricaria chamomilla flower extract"], categories: [.soothing]),
        IngredientEntry(name: "Mugwort", aliases: ["artemisia vulgaris extract", "artemisia princeps leaf extract", "artemisia princeps extract"], categories: [.soothing]),
        IngredientEntry(name: "Purslane extract", aliases: ["portulaca oleracea extract"], categories: [.soothing]),
        IngredientEntry(name: "Beta-glucan", aliases: ["beta glucan", "oat beta glucan"], categories: [.soothing]),
        IngredientEntry(name: "Ectoin", aliases: ["ectoine"], categories: [.soothing]),

        // Fragrance (added fragrance and the labelled fragrance allergens)
        IngredientEntry(name: "Fragrance", aliases: ["parfum", "perfume", "aroma", "flavor", "flavour", "pewangi", "wewangian"], categories: [.fragrance]),
        IngredientEntry(name: "Linalool", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Limonene", aliases: ["d-limonene"], categories: [.fragrance]),
        IngredientEntry(name: "Citronellol", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Geraniol", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Citral", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Hexyl cinnamal", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Amyl cinnamal", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Cinnamal", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Cinnamyl alcohol", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Benzyl salicylate", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Benzyl benzoate", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Benzyl cinnamate", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Alpha-isomethyl ionone", aliases: ["alpha isomethyl ionone"], categories: [.fragrance]),
        IngredientEntry(name: "Coumarin", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Eugenol", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Isoeugenol", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Butylphenyl methylpropional", aliases: ["lilial"], categories: [.fragrance]),
        IngredientEntry(name: "Hydroxycitronellal", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Farnesol", aliases: [], categories: [.fragrance]),
        IngredientEntry(name: "Anise alcohol", aliases: ["anisyl alcohol"], categories: [.fragrance]),
        IngredientEntry(name: "Oakmoss extract", aliases: ["evernia prunastri extract", "evernia furfuracea extract"], categories: [.fragrance]),

        // Essential oils
        IngredientEntry(name: "Essential oils", aliases: ["essential oil", "essential oil blend", "citrus oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Lavender oil", aliases: ["lavandula angustifolia oil", "lavandula angustifolia flower oil", "lavandula officinalis oil", "lavandula hybrida oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Peppermint oil", aliases: ["mentha piperita oil", "mentha piperita leaf oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Tea tree oil", aliases: ["melaleuca alternifolia leaf oil", "melaleuca alternifolia oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Eucalyptus oil", aliases: ["eucalyptus globulus leaf oil", "eucalyptus globulus oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Lemon oil", aliases: ["lemon peel oil", "citrus limon peel oil", "citrus limon oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Bergamot oil", aliases: ["citrus aurantium bergamia fruit oil", "citrus aurantium bergamia peel oil", "citrus bergamia peel oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Orange oil", aliases: ["citrus aurantium dulcis peel oil", "citrus aurantium dulcis oil", "citrus sinensis peel oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Mandarin oil", aliases: ["citrus reticulata peel oil", "citrus nobilis peel oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Grapefruit oil", aliases: ["citrus paradisi peel oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Lime oil", aliases: ["citrus aurantifolia oil", "citrus aurantifolia peel oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Neroli oil", aliases: ["citrus aurantium amara flower oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Geranium oil", aliases: ["pelargonium graveolens flower oil", "pelargonium graveolens oil", "pelargonium roseum leaf oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Rosemary oil", aliases: ["rosmarinus officinalis leaf oil", "rosmarinus officinalis oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Ylang-ylang oil", aliases: ["cananga odorata flower oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Sage oil", aliases: ["salvia officinalis oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Rose oil", aliases: ["rosa damascena flower oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Chamomile oil", aliases: ["anthemis nobilis flower oil", "chamomilla recutita flower oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Juniper oil", aliases: ["juniperus communis fruit oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Lemongrass oil", aliases: ["cymbopogon schoenanthus oil", "cymbopogon citratus leaf oil", "cymbopogon flexuosus oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Sandalwood oil", aliases: ["santalum album oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Patchouli oil", aliases: ["pogostemon cablin leaf oil", "pogostemon cablin oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Cedarwood oil", aliases: ["cedrus atlantica bark oil", "cedrus atlantica wood oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Thyme oil", aliases: ["thymus vulgaris flower/leaf oil", "thymus vulgaris oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Clove oil", aliases: ["eugenia caryophyllus flower oil", "eugenia caryophyllus leaf oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Lemon balm oil", aliases: ["melissa officinalis leaf oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Pine oil", aliases: ["pinus sylvestris leaf oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Lemon myrtle oil", aliases: ["leptospermum petersonii oil"], categories: [.essentialOil]),

        // Drying alcohol — only short-chain alcohols. Fatty alcohols (cetyl, cetearyl, stearyl…) and benzyl alcohol are not
        // listed, and a bare "alcohol" is never an alias because every fatty alcohol contains it.
        IngredientEntry(name: "Drying alcohol", aliases: ["alcohol denat", "alcohol denat.", "denatured alcohol", "sd alcohol", "sd alcohol 40", "sd alcohol 40-b", "ethanol", "ethyl alcohol"], categories: [.dryingAlcohol]),
        IngredientEntry(name: "Isopropyl alcohol", aliases: ["isopropanol"], categories: [.dryingAlcohol]),

        // Harsh surfactants
        IngredientEntry(name: "Sodium lauryl sulfate", aliases: ["sls", "sodium lauryl sulphate"], categories: [.harshSurfactant]),
        IngredientEntry(name: "Ammonium lauryl sulfate", aliases: ["ammonium lauryl sulphate"], categories: [.harshSurfactant]),
        IngredientEntry(name: "Sodium coco-sulfate", aliases: ["sodium coco sulfate", "sodium coco-sulphate"], categories: [.harshSurfactant]),
        IngredientEntry(name: "TEA-lauryl sulfate", aliases: [], categories: [.harshSurfactant]),

        // Pore-clogging oils and esters (high on the classic comedogenicity scales)
        IngredientEntry(name: "Coconut oil", aliases: ["cocos nucifera oil", "cocos nucifera (coconut) oil", "minyak kelapa"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Isopropyl myristate", aliases: [], categories: [.comedogenicOil]),
        IngredientEntry(name: "Isopropyl palmitate", aliases: [], categories: [.comedogenicOil]),
        IngredientEntry(name: "Isopropyl isostearate", aliases: [], categories: [.comedogenicOil]),
        IngredientEntry(name: "Myristyl myristate", aliases: [], categories: [.comedogenicOil]),
        IngredientEntry(name: "Myristyl lactate", aliases: [], categories: [.comedogenicOil]),
        IngredientEntry(name: "Isocetyl stearate", aliases: [], categories: [.comedogenicOil]),
        IngredientEntry(name: "Ethylhexyl palmitate", aliases: ["octyl palmitate"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Ethylhexyl stearate", aliases: ["octyl stearate"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Cocoa butter", aliases: ["theobroma cacao seed butter", "theobroma cacao butter"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Wheat germ oil", aliases: ["triticum vulgare germ oil"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Flaxseed oil", aliases: ["linum usitatissimum seed oil", "linseed oil"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Lanolin", aliases: ["acetylated lanolin", "acetylated lanolin alcohol"], categories: [.comedogenicOil]),
    ]

    private static let index: [String: IngredientEntry] = {
        var map: [String: IngredientEntry] = [:]
        for entry in entries {
            for key in [entry.name.lowercased()] + entry.aliases { map[key] = entry }
        }
        return map
    }()

    /// Keys long enough for the one-character OCR tolerance, sorted so the result never depends on hash order. Keys
    /// with a one- or two-character word ("vitamin c", "vitamin b3", "ceramide 3") are left out: one slip there is a
    /// different ingredient ("vitamin e"), not a typo.
    private static let fuzzyKeys: [String] = index.keys
        .filter { $0.count >= 6 && $0.split(separator: " ").allSatisfy { $0.count >= 3 } }
        .sorted()

    /// Exact/alias match, then contained-name match, then a tolerant match for OCR slips (one character off).
    public static func match(_ ingredient: String) -> IngredientEntry? {
        let key = ingredient.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = index[key] { return exact }
        if key.count > 4 {
            let contained = index.keys
                .filter { $0.count > 4 && containsWholeName($0, in: key) }
                .max { ($0.count, $0) < ($1.count, $1) }
            if let contained { return index[contained] }
        }
        return fuzzyKeys.first { editDistance($0, key) <= 1 }.flatMap { index[$0] }
    }

    /// True when `name` appears in `ingredient` as whole words ("niacinamide 5%", "centella asiatica leaf extract") and
    /// the ingredient is not a different compound built from it. Rejects "phenoxyethanol" for "ethanol", "polyglycerin"
    /// for "glycerin", esters/salts ("butylene glycol dicaprylate"), polymers ("lactic acid/glycolic acid copolymer")
    /// and PEG/PPG derivatives ("peg-10 dimethicone").
    static func containsWholeName(_ name: String, in ingredient: String) -> Bool {
        let words = ingredient.split { !$0.isLetter }
        if words.contains(where: { $0 == "peg" || $0 == "ppg" }) { return false }
        var searchStart = ingredient.startIndex
        while let range = ingredient.range(of: name, range: searchStart..<ingredient.endIndex) {
            let startsWord = range.lowerBound == ingredient.startIndex || !ingredient[ingredient.index(before: range.lowerBound)].isLetter
            let endsWord = range.upperBound == ingredient.endIndex || !ingredient[range.upperBound].isLetter
            if startsWord, endsWord {
                return !ingredient[range.upperBound...].split { !$0.isLetter }.contains(where: isDerivativeWord)
            }
            searchStart = ingredient.index(after: range.lowerBound)
        }
        return false
    }

    /// Words that, following a known name, make it a different compound: esters and salts ("…ate"), polymers, esters.
    private static func isDerivativeWord(_ word: Substring) -> Bool {
        (word.hasSuffix("ate") && word != "concentrate") || word.contains("polymer") || word.hasPrefix("ester")
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard abs(a.count - b.count) <= 1 else { return 2 }
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, cb) in b.enumerated() {
                current[j + 1] = min(previous[j + 1] + 1, current[j] + 1, previous[j] + (ca == cb ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}

// MARK: - Parsing

public enum IngredientParser {
    /// Turns raw label/OCR/web text into a normalized ingredient list (INCI order preserved, duplicates removed).
    public static func parse(_ text: String) -> [String] {
        var body = text.lowercased()
        if let header = body.range(of: "ingredients:") { body = String(body[header.upperBound...]) }
        if let tail = body.range(of: "may contain") { body = String(body[..<tail.lowerBound]) }
        body = body.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        let separators = CharacterSet(charactersIn: ",;•·\n")
        var seen = Set<String>()
        return body
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".*"))) }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .filter { !$0.isEmpty && $0.count < 80 && seen.insert($0).inserted }
    }
}

// MARK: - Verdicts

public enum ProductVerdict: String, CaseIterable, Sendable, Hashable, Codable {
    case goodMatch, useWithCaution, probablyNotForYou, notEnoughInfo

    public var title: String {
        switch self {
        case .goodMatch: String(localized: "Good match")
        case .useWithCaution: String(localized: "Use with care")
        case .probablyNotForYou: String(localized: "Probably not for you")
        case .notEnoughInfo: String(localized: "Not enough info")
        }
    }

    public var systemImage: String {
        switch self {
        case .goodMatch: "checkmark.seal"
        case .useWithCaution: "exclamationmark.circle"
        case .probablyNotForYou: "xmark.circle"
        case .notEnoughInfo: "questionmark.circle"
        }
    }
}

public struct VerdictReason: Sendable, Hashable, Identifiable {
    public enum Kind: Int, Sendable, Hashable { case negative = 0, caution = 1, positive = 2 }
    public let ruleID: String
    public let kind: Kind
    public let text: String
    public var id: String { ruleID }
}

public struct VerdictProfile: Sendable, Hashable {
    public let skinType: SkinType
    public let isSensitive: Bool
    public let latestCounts: LesionCounts
    public let routineCategories: Set<IngredientCategory>

    public init(skinType: SkinType, isSensitive: Bool, latestCounts: LesionCounts, routineCategories: Set<IngredientCategory>) {
        self.skinType = skinType
        self.isSensitive = isSensitive
        self.latestCounts = latestCounts
        self.routineCategories = routineCategories
    }

    var isComedonal: Bool {
        let comedones = latestCounts[.blackhead] + latestCounts[.whitehead]
        return comedones >= 4 && comedones >= latestCounts[.papule] + latestCounts[.pustule]
    }

    var isInflamed: Bool { latestCounts[.papule] + latestCounts[.pustule] + latestCounts[.nodule] >= 4 }
}

public struct VerdictResult: Sendable, Hashable {
    public let verdict: ProductVerdict
    public let reasons: [VerdictReason]
    public let matchedCategories: Set<IngredientCategory>
}

/// Deterministic, unit-tested rules (PLAN.md §12): an LLM never decides — it may only rephrase these reasons.
public enum ProductVerdictEngine {
    public static func categories(of ingredients: [String]) -> Set<IngredientCategory> {
        Set(ingredients.compactMap(IngredientKnowledge.match).flatMap(\.categories))
    }

    public static func evaluate(ingredients: [String], profile: VerdictProfile) -> VerdictResult {
        guard !ingredients.isEmpty else {
            return VerdictResult(verdict: .notEnoughInfo, reasons: [], matchedCategories: [])
        }
        let matched = ingredients.compactMap(IngredientKnowledge.match)
        let categories = Set(matched.flatMap(\.categories))
        let topFive = Set(ingredients.prefix(5).compactMap(IngredientKnowledge.match).flatMap(\.categories))
        let comedogenicCount = matched.filter { $0.categories.contains(.comedogenicOil) }.count
        var reasons: [VerdictReason] = []

        func add(_ id: String, _ kind: VerdictReason.Kind, _ text: String) {
            reasons.append(VerdictReason(ruleID: id, kind: kind, text: text))
        }

        if profile.isSensitive, !categories.isDisjoint(with: [.fragrance, .essentialOil]) {
            add("sensitive.fragrance", .caution, String(localized: "Contains fragrance or essential oils, which often sting sensitive skin."))
        }
        if profile.isComedonal || profile.skinType == .oily, comedogenicCount > 0 {
            add("comedonal.oils", comedogenicCount >= 2 ? .negative : .caution,
                String(localized: "Has pore-clogging oils, which tend to worsen blackheads and whiteheads."))
        }
        if profile.skinType == .dry, !topFive.isDisjoint(with: [.dryingAlcohol, .harshSurfactant]) {
            add("dry.stripping", .caution, String(localized: "High in drying alcohol or harsh cleansers, which can leave dry skin tight."))
        }
        let acids: Set<IngredientCategory> = [.exfoliantAHA, .exfoliantBHA]
        if categories.contains(.retinoid), !profile.routineCategories.isDisjoint(with: acids) {
            add("conflict.retinoid-acid", .caution, String(localized: "Your routine already has an exfoliating acid — don't layer it with this retinoid on the same night."))
        } else if !categories.isDisjoint(with: acids), profile.routineCategories.contains(.retinoid) {
            add("conflict.acid-retinoid", .caution, String(localized: "You already use a retinoid — alternate nights instead of layering with this acid."))
        }
        let calming: Set<IngredientCategory> = [.exfoliantBHA, .benzoylPeroxide, .azelaicAcid, .niacinamide]
        if profile.isInflamed, !categories.isDisjoint(with: calming) {
            add("breakouts.helpful-active", .positive, String(localized: "Has an ingredient many people use for active breakouts."))
        }
        let preferred = Set(SkinTypeGuidance.for(profile.skinType).lookFor.compactMap { IngredientKnowledge.match($0.name) }.flatMap(\.categories))
        if !categories.isDisjoint(with: preferred) {
            add("skintype.match", .positive, String(localized: "Includes ingredients suited to \(profile.skinType.title.lowercased()) skin."))
        }
        if !categories.isDisjoint(with: [.barrier, .soothing, .humectant]), reasons.allSatisfy({ $0.kind == .positive }) {
            add("gentle.basics", .positive, String(localized: "Hydrating, barrier-friendly basics."))
        }

        let sorted = reasons.sorted { $0.kind.rawValue < $1.kind.rawValue }
        let verdict: ProductVerdict = if sorted.contains(where: { $0.kind == .negative }) {
            .probablyNotForYou
        } else if sorted.contains(where: { $0.kind == .caution }) {
            .useWithCaution
        } else if matched.isEmpty {
            .notEnoughInfo
        } else {
            .goodMatch
        }
        return VerdictResult(verdict: verdict, reasons: sorted, matchedCategories: categories)
    }
}
