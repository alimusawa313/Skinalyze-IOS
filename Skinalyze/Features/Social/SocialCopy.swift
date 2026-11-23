import Foundation
import SkinalyzeKit

/// Words for friends and leagues. Public names come from fixed lists, so they show in each reader's language.
enum SocialCopy {
    static func adjective(_ index: Int) -> String {
        let words = [
            String(localized: "Sunny"), String(localized: "Calm"), String(localized: "Brave"), String(localized: "Cosy"),
            String(localized: "Bright"), String(localized: "Gentle"), String(localized: "Happy"), String(localized: "Lucky"),
            String(localized: "Swift"), String(localized: "Quiet"), String(localized: "Bouncy"), String(localized: "Clever"),
            String(localized: "Cheerful"), String(localized: "Mellow"), String(localized: "Plucky"), String(localized: "Breezy"),
            String(localized: "Jolly"), String(localized: "Kind"), String(localized: "Merry"), String(localized: "Nimble"),
            String(localized: "Steady"), String(localized: "Sparkly"), String(localized: "Snug"), String(localized: "Zesty"),
        ]
        return words[index % words.count]
    }

    static func animal(_ index: Int) -> String {
        let words = [
            String(localized: "Otter"), String(localized: "Panda"), String(localized: "Koala"), String(localized: "Fox"),
            String(localized: "Penguin"), String(localized: "Owl"), String(localized: "Bunny"), String(localized: "Turtle"),
            String(localized: "Dolphin"), String(localized: "Hedgehog"), String(localized: "Kitten"), String(localized: "Puppy"),
            String(localized: "Duckling"), String(localized: "Seal"), String(localized: "Sloth"), String(localized: "Lemur"),
            String(localized: "Llama"), String(localized: "Gecko"), String(localized: "Robin"), String(localized: "Badger"),
            String(localized: "Beaver"), String(localized: "Hamster"), String(localized: "Squirrel"), String(localized: "Whale"),
        ]
        return words[index % words.count]
    }

    static func name(_ name: PublicName) -> String {
        let adjective = adjective(name.adjective), animal = animal(name.animal)
        return String(localized: "\(adjective) \(animal)", comment: "A generated public name: adjective then animal.")
    }

    static func tier(_ tier: LeagueTier) -> String {
        switch tier {
        case .bronze: String(localized: "Bronze league")
        case .silver: String(localized: "Silver league")
        case .gold: String(localized: "Gold league")
        case .emerald: String(localized: "Emerald league")
        case .diamond: String(localized: "Diamond league")
        }
    }

    static func tierSymbol(_ tier: LeagueTier) -> String {
        switch tier {
        case .bronze, .silver, .gold: "shield.fill"
        case .emerald: "seal.fill"
        case .diamond: "diamond.fill"
        }
    }

    static func inviteLink(_ code: FriendCode) -> URL {
        URL(string: "skinalyze://friend/\(code.value)")!
    }

    static func inviteMessage(_ code: FriendCode) -> String {
        String(localized: "Be my Skinalyze friend! My code is \(code.value). Open the link on your iPhone: \(inviteLink(code).absoluteString)")
    }
}

/// The invite reward: a free month of Pro for the invited friend, through an App Store offer code the owner creates in
/// App Store Connect (no server needed). Without a server the app can't grant the inviter a month itself, so the
/// inviter's thanks is a badge.
enum Referral {
    /// The custom offer code set up in App Store Connect (placeholder until the owner creates it).
    static let offerCode = "SKINFRIEND"
}
