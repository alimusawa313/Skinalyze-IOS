import Foundation
import SkinalyzeKit

/// The minimum the share extension and Siri need to personalise a verdict, mirrored into the App Group by the app.
/// Extensions never open the SwiftData store. No photos or scan images are shared.
struct SharedContext: Codable, Equatable {
    var skinTypeRaw: String
    var sensitivityRaw: String
    var latestCounts: [String: Int]
    var routineIngredients: [String]

    static let appGroup = "group.com.Patani.Skinalyze"
    static let key = "sharedContext"

    static func load() -> SharedContext? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedContext.self, from: data)
    }

    func save() {
        guard SharedContext.load() != self, let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: SharedContext.appGroup)?.set(data, forKey: SharedContext.key)
    }

    var verdictProfile: VerdictProfile {
        VerdictProfile(
            skinType: SkinType(stored: skinTypeRaw),
            isSensitive: !sensitivityRaw.isEmpty && sensitivityRaw != "Not sensitive",
            latestCounts: LesionCounts(legacyDictionary: latestCounts),
            routineCategories: ProductVerdictEngine.categories(of: routineIngredients)
        )
    }

    #if !SHARE_EXTENSION
    /// Mirrors the user's profile, latest counts and routine ingredients for the extensions and Siri.
    static func publish(latestCounts: LesionCounts?) {
        let defaults = UserDefaults.standard
        SharedContext(
            skinTypeRaw: defaults.string(forKey: UserProfile.Key.skinType) ?? "",
            sensitivityRaw: defaults.string(forKey: UserProfile.Key.sensitivity) ?? "",
            latestCounts: latestCounts?.legacyDictionary ?? [:],
            routineIngredients: UserProfile.currentProductIDs
                .compactMap(ProductCatalog.shared.product(id:))
                .flatMap(\.ingredientList)
                .map { $0.lowercased() }
        ).save()
    }
    #endif

    /// Evaluates raw text (label, web page, shared selection) against this profile.
    func verdict(forIngredientText text: String) -> VerdictResult {
        ProductVerdictEngine.evaluate(ingredients: IngredientParser.parse(text), profile: verdictProfile)
    }
}
