import Foundation
import OSLog
import SkinalyzeKit

// What Pimpi says when poked: one shared pool (PimpiLines.json, English and Indonesian side by side) for Home, the
// scan result and the Shelf. Lines are about habits, showing up and Pimpi itself — never about how the skin looks.

/// Where Pimpi is when it gets poked.
enum PimpiPlace: String, CaseIterable, Sendable {
    case home, shelf, result
}

/// The part of the day a line can be tied to. Lines without a time tag fit any time.
enum PimpiTimeOfDay: CaseIterable, Sendable {
    case morning, afternoon, evening, night

    static let morningFromHour = 5
    static let afternoonFromHour = 12
    static let eveningFromHour = 17
    static let nightFromHour = 22

    init(hour: Int) {
        switch hour {
        case Self.morningFromHour..<Self.afternoonFromHour: self = .morning
        case Self.afternoonFromHour..<Self.eveningFromHour: self = .afternoon
        case Self.eveningFromHour..<Self.nightFromHour: self = .evening
        default: self = .night
        }
    }

    /// The tag a line carries to be said at this time (the afternoon has none: only untimed lines then).
    var tag: PimpiLine.Tag? {
        switch self {
        case .morning: .morning
        case .afternoon: nil
        case .evening: .evening
        case .night: .night
        }
    }
}

/// One thing Pimpi can say, with the face it pulls while saying it.
struct PimpiLine: Decodable, Hashable, Sendable, Identifiable {
    enum Tag: String, Codable, CaseIterable, Sendable {
        /// Fits every place.
        case any
        case morning, evening, night
        case home, shelf, result
        /// Only while a streak is running.
        case streak

        static let places: Set<Tag> = [.any, .home, .shelf, .result]
        static let times: Set<Tag> = [.morning, .evening, .night]
    }

    let id: String
    let text: LocalizedText
    let mood: MascotMood
    let contexts: Set<Tag>

    init(id: String, text: LocalizedText, mood: MascotMood, contexts: Set<Tag>) {
        self.id = id
        self.text = text
        self.mood = mood
        self.contexts = contexts
    }

    private enum CodingKeys: String, CodingKey { case id, text, mood, contexts }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMood = try container.decode(String.self, forKey: .mood)
        guard let mood = MascotMood(rawValue: rawMood) else {
            throw DecodingError.dataCorruptedError(forKey: .mood, in: container, debugDescription: "Unknown mood \(rawMood)")
        }
        self.init(id: try container.decode(String.self, forKey: .id),
                  text: try container.decode(LocalizedText.self, forKey: .text),
                  mood: mood,
                  contexts: try container.decode(Set<Tag>.self, forKey: .contexts))
    }

    /// Whether Pimpi can say this here, now.
    func fits(place: PimpiPlace, time: PimpiTimeOfDay, hasStreak: Bool) -> Bool {
        guard contexts.contains(.any) || contexts.contains(where: { $0.rawValue == place.rawValue }) else { return false }
        let times = contexts.intersection(Tag.times)
        if !times.isEmpty {
            guard let now = time.tag, times.contains(now) else { return false }
        }
        return hasStreak || !contexts.contains(.streak)
    }

    /// The line in the app's language: Indonesian when the app runs in Indonesian, English otherwise.
    var localized: String { text.text(for: PimpiLines.languageCode) }

    /// Said when the bundled lines can't be read.
    static let fallback = PimpiLine(
        id: "fallback",
        text: LocalizedText(en: "You showed up. That already counts.", id: "Kamu sudah hadir. Itu sudah berarti."),
        mood: .excited,
        contexts: [.any]
    )
}

/// The pool of Pimpi lines.
struct PimpiLines: Sendable {
    private struct File: Decodable {
        let lines: [PimpiLine]
    }

    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "PimpiLines")
    static let resourceName = "PimpiLines"
    /// A routine streak this long or longer lets Pimpi talk about it.
    static let minimumStreakDays = 2
    static let languageCode = Locale.current.language.languageCode?.identifier

    let lines: [PimpiLine]

    static let shared = loadBundled()

    static func decode(_ data: Data) throws -> PimpiLines {
        PimpiLines(lines: try JSONDecoder().decode(File.self, from: data).lines)
    }

    static func bundledData(bundle: Bundle = .main) throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    static func loadBundled(bundle: Bundle = .main) -> PimpiLines {
        do {
            return try decode(bundledData(bundle: bundle))
        } catch {
            logger.error("PimpiLines.json could not be read: \(error.localizedDescription)")
            return PimpiLines(lines: [PimpiLine.fallback])
        }
    }

    /// The lines Pimpi can say at a place and time.
    func eligible(place: PimpiPlace, time: PimpiTimeOfDay, hasStreak: Bool) -> [PimpiLine] {
        lines.filter { $0.fits(place: place, time: time, hasStreak: hasStreak) }
    }

    /// What Pimpi says on the `poke`-th poke (1-based) at a place: today's shuffle of the lines that fit right now.
    func line(poke: Int, place: PimpiPlace, hasStreak: Bool = false, date: Date = .now,
              calendar: Calendar = .current) -> PimpiLine {
        let time = PimpiTimeOfDay(hour: calendar.component(.hour, from: date))
        let seed = PimpiLinePicker.seed(day: calendar.ordinality(of: .day, in: .era, for: date) ?? 0, place: place)
        return PimpiLinePicker.pick(poke: poke, from: eligible(place: place, time: time, hasStreak: hasStreak), seed: seed)
            ?? PimpiLine.fallback
    }
}

/// Deterministic order for the pokes: every line once per round, shuffled by a seed (the day and the place), and a
/// new round never starts with the line the last one ended on — so Pimpi never says the same thing twice in a row.
enum PimpiLinePicker {
    /// The line for the `poke`-th poke (1-based), or nil when there are no lines.
    static func pick(poke: Int, from lines: [PimpiLine], seed: UInt64) -> PimpiLine? {
        guard !lines.isEmpty else { return nil }
        let index = max(poke, 1) - 1
        let round = order(of: lines, seed: seed, round: index / lines.count)
        return round[index % lines.count]
    }

    /// The order of one round.
    static func order(of lines: [PimpiLine], seed: UInt64, round: Int) -> [PimpiLine] {
        let sorted = lines.sorted { $0.id < $1.id } // the JSON's order doesn't matter
        var previousLast: PimpiLine?
        var current: [PimpiLine] = []
        for number in 0...max(round, 0) {
            var shuffled = shuffle(sorted, seed: mix(seed, UInt64(number)))
            if shuffled.count > 1, shuffled.first == previousLast {
                shuffled.append(shuffled.removeFirst())
            }
            previousLast = shuffled.last
            current = shuffled
        }
        return current
    }

    static func seed(day: Int, place: PimpiPlace) -> UInt64 {
        mix(UInt64(bitPattern: Int64(day)), fnv1a(place.rawValue))
    }

    /// Fisher–Yates with our own generator, so the order is the same on every OS version.
    private static func shuffle(_ lines: [PimpiLine], seed: UInt64) -> [PimpiLine] {
        var result = lines
        var generator = SplitMix64(state: seed)
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let other = Int(generator.next() % UInt64(index + 1))
            result.swapAt(index, other)
        }
        return result
    }

    private static func mix(_ first: UInt64, _ second: UInt64) -> UInt64 {
        var generator = SplitMix64(state: first ^ (second &* 0x9E37_79B9_7F4A_7C15))
        return generator.next()
    }

    /// A stable string hash (Swift's `Hasher` is seeded per launch).
    private static func fnv1a(_ text: String) -> UInt64 {
        text.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3 }
    }
}

/// A tiny seeded random number generator (SplitMix64).
private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
