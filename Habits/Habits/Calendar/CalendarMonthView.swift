//
//  CalendarMonthView.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

struct CalendarMonthView: View {
    private enum SlideDirection {
        case left
        case right
    }

    @Binding var month: Date
    let habit: Habit
    let service: HabitLogService
    let selectedDate: Date
    let onSelectDay: (Date) -> Void

    @State private var slideDirection: SlideDirection?
    @State private var slideResetToken = UUID()

    private let swipeIntentLock: CGFloat = 20
    private let swipeCommitThreshold: CGFloat = 44
    private let horizontalSpacing: CGFloat = 8
    private let verticalSpacing: CGFloat = 8
    private let weekdayRowHeight: CGFloat = 18
    private let headerHeight: CGFloat = 44
    private let edgePadding: CGFloat = 4
    private let navHitSize: CGFloat = 44
    private let navVisualSize: CGFloat = 34
    private let monthAnimationDuration: Double = 0.22
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let days = service.daysForMonth(displayedMonth)
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: horizontalSpacing),
            count: 7
        )

        VStack(alignment: .leading, spacing: 12) {
            header

            ZStack {
                VStack(spacing: verticalSpacing) {
                    LazyVGrid(columns: columns, spacing: horizontalSpacing) {
                        ForEach(Array(weekdays.enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: weekdayRowHeight)

                    LazyVGrid(columns: columns, spacing: verticalSpacing) {
                        ForEach(days.indices, id: \.self) { index in
                            let day = days[index]
                            let isInDisplayedMonth = isDisplayedMonth(day)

                            CalendarDayCell(
                                date: day,
                                intensity: service.intensity(for: habit, on: day),
                                accent: Color(hex: habit.colorHex),
                                isInDisplayedMonth: isInDisplayedMonth,
                                isDisabled: !isInDisplayedMonth || isFutureDate(day),
                                isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(day),
                                onTap: {
                                    onSelectDay(day)
                                    service.increment(for: habit, on: day)
                                }
                            )
                        }
                    }
                }
                .id(monthIdentity)
                .transition(calendarTransition)
            }
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
        }
        .padding(.horizontal, edgePadding)
    }

    private var header: some View {
        HStack(spacing: 8) {
            monthArrow(systemName: "chevron.left") {
                navigateMonth(by: -1)
            }

            Spacer()

            HStack(spacing: 8) {
                Text(monthLabel)
                    .font(.headline)

                if shouldShowToday {
                    Button("Today") {
                        jumpToCurrentMonth()
                    }
                    .font(.subheadline)
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
                insertion: .move(edge: .leading).combined(with: fade),
                removal: .move(edge: .trailing).combined(with: fade)
            )
        case .right:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: fade),
                removal: .move(edge: .leading).combined(with: fade)
            )
        case .none:
            return .identity
        }
    }

    private var monthAnimation: Animation {
        .easeOut(duration: monthAnimationDuration)
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
                        .fill(Color.secondary.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .frame(width: navHitSize, height: navHitSize)
        .contentShape(Circle())
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLL yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var calendar: Calendar {
        Calendar.current
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

    private var canGoForward: Bool {
        compareMonth(monthComponents, currentMonthComponents) < 0
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

        guard let candidateMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }
        let normalizedNewMonth = normalizedMonth(candidateMonth)
        let newComponents = calendar.dateComponents([.year, .month], from: normalizedNewMonth)
        guard compareMonth(newComponents, currentMonthComponents) <= 0 else {
            return
        }

        slideDirection = value < 0 ? .left : .right
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
        slideDirection = nil
        slideResetToken = UUID()
        month = normalizedMonth(Date())
    }
}
