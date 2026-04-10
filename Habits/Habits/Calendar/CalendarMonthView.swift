//
//  CalendarMonthView.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

struct CalendarMonthView: View {
    @EnvironmentObject private var uiStateStore: HabitUIStateStore

    private enum SlideDirection {
        case left
        case right
    }

    private struct AdjustingDate: Identifiable {
        let id: Date
        let date: Date
    }

    @Binding var month: Date
    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let selectedDate: Date
    let monthSummaryText: String?
    let premiumHistoryGate: PremiumHistoryGate.Context
    let earliestVisibleDate: Date?
    let isTapToLogEnabled: Bool
    let onSelectDay: (Date) -> Void
    let onTapDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    @State private var slideDirection: SlideDirection?
    @State private var slideResetToken = UUID()
    @State private var adjustingDate: AdjustingDate? = nil

    private let swipeIntentLock: CGFloat = 20
    private let swipeCommitThreshold: CGFloat = 44
    private let horizontalSpacing: CGFloat = 4
    private let verticalSpacing: CGFloat = 8
    private let weekdayRowHeight: CGFloat = 18
    private let headerHeight: CGFloat = 44
    private let edgePadding: CGFloat = 4
    private let navHitSize: CGFloat = 44
    private let navVisualSize: CGFloat = 34
    private let monthAnimationDuration: Double = 0.28
    private let headerFadeDuration: Double = 0.22

    init(
        month: Binding<Date>,
        habit: Habit,
        service: HabitLogService,
        calendarProvider: CalendarProvider,
        selectedDate: Date,
        monthSummaryText: String? = nil,
        premiumHistoryGate: PremiumHistoryGate.Context,
        earliestVisibleDate: Date? = nil,
        isTapToLogEnabled: Bool = true,
        onSelectDay: @escaping (Date) -> Void,
        onTapDay: @escaping (Date) -> Void,
        onTapLockedDay: @escaping (Date) -> Void = { _ in }
    ) {
        self._month = month
        self.habit = habit
        self.service = service
        self.calendarProvider = calendarProvider
        self.selectedDate = selectedDate
        self.monthSummaryText = monthSummaryText
        self.premiumHistoryGate = premiumHistoryGate
        self.earliestVisibleDate = earliestVisibleDate
        self.isTapToLogEnabled = isTapToLogEnabled
        self.onSelectDay = onSelectDay
        self.onTapDay = onTapDay
        self.onTapLockedDay = onTapLockedDay
    }

    var body: some View {
        let _ = uiStateStore.progressByHabitAndDate.count
        let days = CalendarGridHelper.daysForMonth(displayedMonth, calendarProvider: calendarProvider)
        let dayMetrics = service.dayMetrics(for: habit, on: days)
        let logsByDay = Dictionary(grouping: habit.logs) { log in
            calendar.startOfDay(for: log.day)
        }

        let columns = Array(
            repeating: GridItem(.flexible(), spacing: horizontalSpacing),
            count: 7
        )

        VStack(alignment: .leading, spacing: 12) {
            header

            ZStack {
                VStack(spacing: verticalSpacing) {
                    LazyVGrid(columns: columns, spacing: horizontalSpacing) {
                        ForEach(Array(calendarProvider.orderedVeryShortStandaloneWeekdaySymbols.enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.78))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: weekdayRowHeight)

                    LazyVGrid(columns: columns, spacing: verticalSpacing) {
                        ForEach(days, id: \.self) { day in
                            let normalizedDay = calendar.startOfDay(for: day)
                            let metrics = dayMetrics[normalizedDay] ?? .zero
                            let isInDisplayedMonth = isDisplayedMonth(day)
                            let isDisabledDay = isFutureDate(day)
                            let isLockedDay = premiumHistoryGate.isLocked(date: day)
                            let count = isLockedDay ? 0 : (logsByDay[normalizedDay]?.count ?? 0)
                            let indicatorText = isLockedDay || habit.goalType != .cumulative || metrics.value <= 0
                                ? nil
                                : service.formatValue(metrics.value, for: habit)

                            CalendarDayCell(
                                date: day,
                                count: count,
                                indicatorText: indicatorText,
                                habitColor: habit.curatedColor,
                                selectedAccent: habit.curatedColorVariants.strong,
                                isInDisplayedMonth: isInDisplayedMonth,
                                isDisabled: isDisabledDay,
                                isLocked: isLockedDay,
                                isSelected: !isDisabledDay && !isLockedDay && calendar.isDate(day, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(day),
                                calendar: calendar,
                                onTap: {
                                    if isLockedDay {
                                        onTapLockedDay(day)
                                    } else if isTapToLogEnabled {
                                        tapDay(day)
                                    } else {
                                        selectDay(day)
                                    }
                                },
                                onLongPress: {
                                    if isLockedDay {
                                        onTapLockedDay(day)
                                    } else {
                                        openDayActions(for: day)
                                    }
                                }
                            )
                        }
                    }
                }
                .id(monthIdentity)
                .transition(calendarTransition)
            }
            .animation(monthAnimation, value: monthIdentity)
            .sheet(item: $adjustingDate) { date in
                Group {
                    if habit.goalType == .frequency {
                        AdjustCountSheet(
                            date: date.date,
                            habit: habit,
                            service: service
                        )
                    } else {
                        CumulativeDayEntriesSheet(
                            habit: habit,
                            date: date.date,
                            service: service
                        )
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
        }
        .padding(.horizontal, edgePadding)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if canGoBackward {
                monthArrow(systemName: "chevron.left") {
                    navigateMonth(by: -1)
                }
            } else {
                Color.clear
                    .frame(width: navHitSize, height: navHitSize)
                    .accessibilityHidden(true)
            }

            Spacer()

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    headerFadingText(
                        monthLabel,
                        id: "month-label-\(monthIdentity)",
                        font: .subheadline.weight(.semibold)
                    )

                    if habit.goalType == .cumulative {
                        headerFadingText(
                            monthSummaryText ?? displayedMonthSummaryText,
                            id: "month-summary-\(monthIdentity)-\(monthSummaryText ?? displayedMonthSummaryText)",
                            font: .caption2
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                if shouldShowToday {
                    Button("Today") {
                        jumpToCurrentMonth()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to today")
                }
            }

            Spacer()

            if canGoForward {
                monthArrow(systemName: "chevron.right") {
                    navigateMonth(by: 1)
                }
            } else {
                Color.clear
                    .frame(width: navHitSize, height: navHitSize)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: headerHeight)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: swipeIntentLock, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical) else { return }
                guard abs(horizontal) >= swipeCommitThreshold else { return }

                if horizontal < 0 {
                    navigateMonth(by: 1)
                } else {
                    navigateMonth(by: -1)
                }
            }
    }

    private var calendarTransition: AnyTransition {
        let fade = AnyTransition.opacity
        switch slideDirection {
        case .left:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: fade),
                removal: .move(edge: .leading).combined(with: fade)
            )
        case .right:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: fade),
                removal: .move(edge: .trailing).combined(with: fade)
            )
        case .none:
            return .identity
        }
    }

    private var monthAnimation: Animation {
        .easeInOut(duration: monthAnimationDuration)
    }

    private var monthIdentity: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return "\(year)-\(month)"
    }

    private func monthArrow(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: navVisualSize, height: navVisualSize)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.10))
                )
        }
        .buttonStyle(TactileButtonStyle())
        .frame(width: navHitSize, height: navHitSize)
        .contentShape(Circle())
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLL yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var calendar: Calendar {
        calendarProvider.calendar
    }

    private var currentMonthComponents: DateComponents {
        calendar.dateComponents([.year, .month], from: Date())
    }

    private var monthComponents: DateComponents {
        calendar.dateComponents([.year, .month], from: displayedMonth)
    }

    private var displayedMonth: Date {
        normalizedMonth(month)
    }

    private var displayedMonthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval(start: displayedMonth, end: displayedMonth)
    }

    private var displayedMonthSummaryText: String {
        let totalText = service.formattedValue(for: habit, in: displayedMonthInterval) ?? habit.formatProgressValue(0)
        let unitSuffix = service.displayUnitSuffix(for: habit)
        return "\(totalText)\(unitSuffix) shown"
    }

    private func selectDay(_ day: Date) {
        let normalizedDate = calendar.startOfDay(for: day)
        onSelectDay(normalizedDate)
        focusMonthIfNeeded(for: normalizedDate)
    }

    private func tapDay(_ day: Date) {
        let normalizedDate = calendar.startOfDay(for: day)
        onTapDay(normalizedDate)
        focusMonthIfNeeded(for: normalizedDate)
    }

    private func openDayActions(for day: Date) {
        selectDay(day)
        adjustingDate = AdjustingDate(id: day, date: day)
    }

    private func focusMonthIfNeeded(for day: Date) {
        guard !isDisplayedMonth(day) else { return }

        let targetMonth = normalizedMonth(day)
        let targetComponents = calendar.dateComponents([.year, .month], from: targetMonth)

        switch compareMonth(targetComponents, monthComponents) {
        case let comparison where comparison < 0:
            slideDirection = .right
        case let comparison where comparison > 0:
            slideDirection = .left
        default:
            slideDirection = nil
        }

        month = targetMonth
    }

    private var canGoForward: Bool {
        compareMonth(monthComponents, currentMonthComponents) < 0
    }

    private var canGoBackward: Bool {
        guard let earliestVisibleMonthComponents else {
            return true
        }

        return compareMonth(monthComponents, earliestVisibleMonthComponents) > 0
    }

    private var shouldShowToday: Bool {
        compareMonth(monthComponents, currentMonthComponents) != 0
    }

    private func isFutureDate(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) > todayStart
    }

    private func isDisplayedMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    private func normalizedMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private var earliestVisibleMonthComponents: DateComponents? {
        guard let earliestVisibleDate else {
            return nil
        }

        return calendar.dateComponents([.year, .month], from: normalizedMonth(earliestVisibleDate))
    }

    private func compareMonth(_ lhs: DateComponents, _ rhs: DateComponents) -> Int {
        let lhsYear = lhs.year ?? 0
        let rhsYear = rhs.year ?? 0
        if lhsYear != rhsYear {
            return lhsYear < rhsYear ? -1 : 1
        }
        let lhsMonth = lhs.month ?? 0
        let rhsMonth = rhs.month ?? 0
        if lhsMonth == rhsMonth {
            return 0
        }
        return lhsMonth < rhsMonth ? -1 : 1
    }

    private func navigateMonth(by value: Int) {
        guard value != 0 else { return }
        if value > 0 && !canGoForward { return }
        if value < 0 && !canGoBackward { return }

        guard let candidateMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }
        let normalizedNewMonth = normalizedMonth(candidateMonth)
        let newComponents = calendar.dateComponents([.year, .month], from: normalizedNewMonth)
        guard compareMonth(newComponents, currentMonthComponents) <= 0 else {
            return
        }
        if let earliestVisibleMonthComponents,
           compareMonth(newComponents, earliestVisibleMonthComponents) < 0 {
            return
        }

        slideDirection = value < 0 ? .right : .left
        let token = UUID()
        slideResetToken = token

        withAnimation(monthAnimation) {
            month = normalizedNewMonth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + monthAnimationDuration) {
            guard slideResetToken == token else { return }
            slideDirection = nil
        }
    }

    private func jumpToCurrentMonth() {
        let target = normalizedMonth(Date())
        let targetComponents = calendar.dateComponents([.year, .month], from: target)
        let comparison = compareMonth(monthComponents, targetComponents)
        if comparison < 0 {
            slideDirection = .left
        } else if comparison > 0 {
            slideDirection = .right
        } else {
            slideDirection = nil
        }
        slideResetToken = UUID()
        withAnimation(monthAnimation) {
            month = target
        }
    }

    private func headerFadingText(
        _ text: String,
        id: String,
        font: Font
    ) -> some View {
        ZStack {
            Text(text)
                .id(id)
                .font(font)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: headerFadeDuration), value: id)
    }
}
