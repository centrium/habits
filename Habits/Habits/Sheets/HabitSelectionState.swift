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
        let newVisibleMonth = navigator.visibleMonth(for: normalizedSelectedDate)

        let selectedDateChanged = !calendar.isDate(selectedDate, inSameDayAs: normalizedSelectedDate)
        let visibleMonthChanged = !calendar.isDate(visibleMonth, equalTo: newVisibleMonth, toGranularity: .month)

        guard selectedDateChanged || visibleMonthChanged else {
            return
        }

        if selectedDateChanged {
            selectedDate = normalizedSelectedDate
        }

        if visibleMonthChanged {
            visibleMonth = newVisibleMonth
        }
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
            selectedDate = lastDayOfMonth(for: normalizedMonth)
        }
    }

    func selectToday(today: Date = Date()) {
        select(date: today)
    }

    private func lastDayOfMonth(for month: Date) -> Date {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)
        else {
            return month
        }

        return calendar.startOfDay(for: lastDay)
    }
}
