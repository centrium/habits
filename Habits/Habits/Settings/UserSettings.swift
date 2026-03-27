import Combine
import Foundation
import SwiftUI

enum WeekStartPreference: String, CaseIterable, Codable, Identifiable {
    case system
    case monday
    case sunday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .monday:
            return "Monday"
        case .sunday:
            return "Sunday"
        }
    }

    func resolvedFirstWeekday(in calendar: Calendar) -> Int {
        switch self {
        case .system:
            return calendar.firstWeekday
        case .monday:
            return 2
        case .sunday:
            return 1
        }
    }
}

protocol SettingsKeyValueStore {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)

    func bool(forKey key: String) -> Bool?
    func set(_ value: Bool, forKey key: String)

    func int(forKey key: String) -> Int?
    func set(_ value: Int, forKey key: String)
}

struct UserDefaultsSettingsStore: SettingsKeyValueStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func bool(forKey key: String) -> Bool? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.bool(forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func int(forKey key: String) -> Int? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.integer(forKey: key)
    }

    func set(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

@MainActor
final class UserSettings: ObservableObject {

    private enum Keys {
        static let weekStart = "settings.weekStart"
        static let greigModeEnabled = "settings.greigModeEnabled"
        static let showPremiumInsightsView = "settings.showPremiumInsightsView"

        static let eveningReflectionEnabled = "settings.eveningReflectionEnabled"
        static let eveningReflectionHour = "settings.eveningReflectionHour"
        static let eveningReflectionMinute = "settings.eveningReflectionMinute"
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
    }

    private enum LegacyKeys {
        static let dailyCheckInEnabled = "settings.dailyCheckInEnabled"
        static let dailyCheckInHour = "settings.dailyCheckInHour"
        static let dailyCheckInMinute = "settings.dailyCheckInMinute"
    }

    private let store: any SettingsKeyValueStore

    // MARK: Week Start

    @Published var weekStartPreference: WeekStartPreference {
        didSet {
            store.set(weekStartPreference.rawValue, forKey: Keys.weekStart)
        }
    }

    // MARK: Greig Mode

    @Published var greigModeEnabled: Bool {
        didSet {
            store.set(greigModeEnabled, forKey: Keys.greigModeEnabled)
        }
    }

    @Published var showPremiumInsightsView: Bool {
        didSet {
            store.set(showPremiumInsightsView, forKey: Keys.showPremiumInsightsView)
        }
    }

    // MARK: Evening Reflection

    @Published var eveningReflectionEnabled: Bool {
        didSet {
            store.set(eveningReflectionEnabled, forKey: Keys.eveningReflectionEnabled)
        }
    }

    @Published var eveningReflectionHour: Int {
        didSet {
            store.set(eveningReflectionHour, forKey: Keys.eveningReflectionHour)
        }
    }

    @Published var eveningReflectionMinute: Int {
        didSet {
            store.set(eveningReflectionMinute, forKey: Keys.eveningReflectionMinute)
        }
    }
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            store.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }
    
    

    // MARK: Init

    convenience init() {
        self.init(store: UserDefaultsSettingsStore())
    }

    init(store: any SettingsKeyValueStore) {

        self.store = store

        self.weekStartPreference =
            WeekStartPreference(rawValue: store.string(forKey: Keys.weekStart) ?? "") ?? .system

        self.greigModeEnabled =
            store.bool(forKey: Keys.greigModeEnabled) ?? true

        self.showPremiumInsightsView =
            store.bool(forKey: Keys.showPremiumInsightsView) ?? true

        self.eveningReflectionEnabled =
            store.bool(forKey: Keys.eveningReflectionEnabled)
            ?? store.bool(forKey: LegacyKeys.dailyCheckInEnabled)
            ?? false

        let storedHour =
            store.int(forKey: Keys.eveningReflectionHour)
            ?? store.int(forKey: LegacyKeys.dailyCheckInHour)
            ?? EveningReflection.defaultHour

        let storedMinute =
            store.int(forKey: Keys.eveningReflectionMinute)
            ?? store.int(forKey: LegacyKeys.dailyCheckInMinute)
            ?? EveningReflection.defaultMinute

        let normalized = EveningReflection.clamped(hour: storedHour, minute: storedMinute)
        self.eveningReflectionHour = normalized.hour
        self.eveningReflectionMinute = normalized.minute
        
        self.hasCompletedOnboarding =
            store.bool(forKey: Keys.hasCompletedOnboarding) ?? false

        store.set(eveningReflectionEnabled, forKey: Keys.eveningReflectionEnabled)
        store.set(eveningReflectionHour, forKey: Keys.eveningReflectionHour)
        store.set(eveningReflectionMinute, forKey: Keys.eveningReflectionMinute)
        store.set(showPremiumInsightsView, forKey: Keys.showPremiumInsightsView)
    }

    // MARK: Calendar Helpers

    func weekLayoutStrategy(base: Calendar = .autoupdatingCurrent) -> WeekLayoutStrategy {
        WeekLayoutStrategy(
            baseCalendar: base,
            weekStartPreference: weekStartPreference
        )
    }

    func effectiveFirstWeekday(in calendar: Calendar = .autoupdatingCurrent) -> Int {
        weekLayoutStrategy(base: calendar).calendarForCalculations().firstWeekday
    }

    func resolvedCalendar(base: Calendar = .autoupdatingCurrent) -> Calendar {
        weekLayoutStrategy(base: base).calendarForCalculations()
    }

    func calendarProvider(base: Calendar = .autoupdatingCurrent) -> CalendarProvider {
        weekLayoutStrategy(base: base).calendarProviderForCalculations()
    }

    // MARK: Evening Reflection Helpers

    var eveningReflectionDateComponents: DateComponents {
        DateComponents(hour: eveningReflectionHour, minute: eveningReflectionMinute)
    }
}
