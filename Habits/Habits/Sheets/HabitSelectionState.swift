import Combine
import Foundation

final class HabitSelectionState: ObservableObject {
    private let calendar: Calendar
    private let navigator: CalendarMonthNavigator

    @Published private(set) var selectedDate: Date
    @Published private(set) var visibleMonth: Date

    init(
        selectedDate: Date = Date(),
        visibleMonth: Date? = nil,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        let navigator = CalendarMonthNavigator(calendar: calendar)
        self.navigator = navigator

        let normalizedSelectedDate = calendar.startOfDay(for: selectedDate)
        self.selectedDate = normalizedSelectedDate
        self.visibleMonth = visibleMonth.map { navigator.visibleMonth(for: $0) } ?? navigator.visibleMonth(for: normalizedSelectedDate)
    }

    func select(date: Date) {
        let normalizedSelectedDate = calendar.startOfDay(for: date)
        selectedDate = normalizedSelectedDate
        visibleMonth = navigator.visibleMonth(for: normalizedSelectedDate)
    }

    func select(heatmapDate: Date) {
        select(date: heatmapDate)
    }

    func selectCalendarMonth(_ month: Date, today: Date = Date()) {
        let normalizedMonth = navigator.visibleMonth(for: month)
        visibleMonth = normalizedMonth

        if calendar.isDate(selectedDate, equalTo: normalizedMonth, toGranularity: .month) {
            return
        }

        if navigator.isCurrentMonth(normalizedMonth, today: today) {
            selectedDate = calendar.startOfDay(for: today)
        } else {
            selectedDate = normalizedMonth
        }
    }

    func selectToday(today: Date = Date()) {
        select(date: today)
    }
}
