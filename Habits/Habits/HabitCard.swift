//
//  HabitCard.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI
import SwiftData

struct HabitCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var habit: Habit

    private let daysBack = 180
    private let columnsCount = 18 // tweak for density on phone
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 4
    private let monthLabelHeight: CGFloat = 14
    private let headerHeight: CGFloat = 40

    private var gridHeight: CGFloat {
        // 7 rows + spacing
        (cellSize * 7) + (cellSpacing * 6)
    }

    private var heatmapHeight: CGFloat {
        monthLabelHeight + gridHeight
    }
    
    var body: some View {
        let accent = Color(hex: habit.colorHex)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent.opacity(0.9))
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.headline)

                    Text("Tap today to log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(height: headerHeight)

            GeometryReader { geo in
                let availableWidth = geo.size.width
                let weekWidth = cellSize + cellSpacing

                let numberOfWeeks = min(
                    20,
                    Int(availableWidth / weekWidth)
                )

                let weeks = HeatmapCalendar.makeWeeks(
                    endingAt: Date(),
                    numberOfWeeks: numberOfWeeks
                )

                GitHubHeatmapGrid(
                    accent: accent,
                    weeks: weeks,
                    intensityFor: { day in intensity(for: day) },
                    onTapDay: { day in increment(for: day) }
                )
            }
            .frame(height: heatmapHeight)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Days

    private func makeDays(daysBack: Int) -> [Date] {
        let cal = Calendar.current
        let today = Date().startOfDay(in: cal)
        return (0..<daysBack).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today)
        }
    }

    // MARK: - Intensity

    private func intensity(for day: Date) -> Double {
        let d = day.startOfDay()
        let count = habit.logs.first(where: { $0.day.startOfDay() == d })?.count ?? 0

        // Normalise: 0..5 -> 0..1 (cap at 1)
        let maxCount = 5.0
        let norm = min(Double(count) / maxCount, 1.0)

        // Keep low values visible but subtle
        return count == 0 ? 0.10 : (0.20 + 0.80 * norm)
    }

    // MARK: - Logging

    private func increment(for day: Date) {
        let d = day.startOfDay()

        if let log = habit.logs.first(where: { $0.day.startOfDay() == d }) {
            log.count += 1
        } else {
            habit.logs.append(HabitLog(day: d, count: 1))
        }

        try? modelContext.save()
    }
}
