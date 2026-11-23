import CoreLocation
import Foundation
import Observation
import OSLog
import SkinalyzeKit
import WeatherKit

/// P10: today's highest UV index from Apple Weather, for a "sunscreen today" nudge. Off until the user turns it on.
/// Location is asked for once a day while the app is open, at reduced accuracy, and only Apple Weather sees it.
@Observable
@MainActor
final class UVModel {
    enum State: Equatable {
        case off, loading, failed
        case ready(index: Int)
    }

    private enum Key {
        static let enabled = "uvNudgeEnabled"
        static let cache = "uvToday"
    }

    private struct Cache: Codable {
        let day: String
        let index: Int
    }

    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "UV")

    private(set) var state: State = .off
    private(set) var isEnabled: Bool
    private(set) var attribution: WeatherAttribution?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Key.enabled)
        if isEnabled {
            state = cachedToday.map { .ready(index: $0) } ?? .loading
        }
    }

    private var todayKey: String { DayStamp(.now, calendar: .current).string }

    private var cachedToday: Int? {
        guard let data = defaults.data(forKey: Key.cache), let cache = try? JSONDecoder().decode(Cache.self, from: data),
              cache.day == todayKey else { return nil }
        return cache.index
    }

    func setEnabled(_ on: Bool) async {
        isEnabled = on
        defaults.set(on, forKey: Key.enabled)
        if on { await refresh() } else { state = .off }
    }

    /// Once a day; later calls the same day use the cached value.
    func refresh() async {
        guard isEnabled else { return }
        #if DEBUG
        if let fake = defaults.string(forKey: "uvDebugIndex").flatMap(Int.init) {
            state = .ready(index: fake)
            return
        }
        #endif
        if let cached = cachedToday {
            state = .ready(index: cached)
            return
        }
        state = .loading
        do {
            let location = try await Self.currentLocation()
            let weather = try await WeatherService.shared.weather(for: location, including: .daily)
            guard let today = weather.forecast.first(where: { Calendar.current.isDateInToday($0.date) }) ?? weather.forecast.first else {
                state = .failed
                return
            }
            let index = today.uvIndex.value
            defaults.set(try? JSONEncoder().encode(Cache(day: todayKey, index: index)), forKey: Key.cache)
            attribution = try? await WeatherService.shared.attribution
            state = .ready(index: index)
        } catch {
            Self.logger.error("UV lookup failed: \(error.localizedDescription)")
            state = .failed
        }
    }

    private static func currentLocation() async throws -> CLLocation {
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        for try await update in CLLocationUpdate.liveUpdates(.default) {
            if update.authorizationDenied || update.authorizationDeniedGlobally { throw CLError(.denied) }
            if let location = update.location { return location }
        }
        throw CLError(.locationUnknown)
    }
}
