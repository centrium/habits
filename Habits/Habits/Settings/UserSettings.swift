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

    // MARK: Daily Check-In Reminder

    @Published var dailyCheckInEnabled: Bool {
        didSet {
            store.set(dailyCheckInEnabled, forKey: Keys.dailyCheckInEnabled)
        }
    }

    @Published var dailyCheckInHour: Int {
        didSet {
            store.set(dailyCheckInHour, forKey: Keys.dailyCheckInHour)
        }
    }

    @Published var dailyCheckInMinute: Int {
        didSet {
            store.set(dailyCheckInMinute, forKey: Keys.dailyCheckInMinute)
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

        self.dailyCheckInEnabled =
            store.bool(forKey: Keys.dailyCheckInEnabled) ?? false

        self.dailyCheckInHour =
            store.int(forKey: Keys.dailyCheckInHour) ?? 20

        self.dailyCheckInMinute =
            store.int(forKey: Keys.dailyCheckInMinute) ?? 0
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

    // MARK: Reminder Helpers

    var dailyCheckInDateComponents: DateComponents {
        DateComponents(hour: dailyCheckInHour, minute: dailyCheckInMinute)
    }
}
