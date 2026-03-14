//
//  CumulativeDayEntriesSheet.swift
//  Habits
//
//  Created by Codex on 01/03/2026.
//

import SwiftUI

struct CumulativeDayEntriesSheet: View {
    private struct EditorSession: Identifiable {
        let id = UUID()
        let entry: HabitLog?
        let initialValue: Double
    }

    @Environment(\.dismiss) private var dismiss

    @Bindable var habit: Habit
    let date: Date
    let service: HabitLogService

    @State private var editorSession: EditorSession?

    private var entries: [HabitLog] {
        service.entries(for: habit, on: date)
    }

    private var dayTotalText: String {
        service.formattedValue(for: habit, on: date) ?? habit.formatProgressValue(0)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Day total")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(totalLineText)
                            .font(.headline)
                    }
                }

                if entries.isEmpty {
                    Section {
                        Text("No entries for this day.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Entries") {
                        ForEach(entries) { entry in
                            Button {
                                editorSession = EditorSession(entry: entry, initialValue: entry.numericValue)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(service.formatValue(entry.numericValue, for: habit))
                                            .foregroundStyle(.primary)

                                        Text(entrySubtitle(for: entry))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(TactileButtonStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    _ = service.deleteEntry(entry, for: habit, on: date)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Add Entry") {
                        editorSession = EditorSession(entry: nil, initialValue: service.quickLogAmount(for: habit))
                    }

                    if !entries.isEmpty {
                        Button("Clear Day", role: .destructive) {
                            _ = service.clearEntries(for: habit, on: date)
                        }
                    }
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DismissButton()
                }
            }
        }
            .sheet(item: $editorSession) { session in
            NumericValueSheet(
                title: session.entry == nil ? "Add Entry" : "Edit Entry",
                initialValue: session.initialValue,
                formattingContext: service.valueFormattingContext(for: habit),
                inputContext: service.valueInputContext(for: habit),
                unitLabel: habit.trimmedUnit
            ) { newValue in
                if let entry = session.entry {
                    _ = service.updateEntry(entry, for: habit, on: date, value: max(0, newValue))
                } else {
                    _ = service.addLog(for: habit, on: date, value: max(0, newValue))
                }
            }
            .presentationDetents([.fraction(0.36)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private var totalLineText: String {
        let unitSuffix = service.displayUnitSuffix(for: habit)
        return "\(dayTotalText)\(unitSuffix)"
    }

    private func entrySubtitle(for entry: HabitLog) -> String {
        if entry.kind == .legacyDailyTotal {
            return "Imported total"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let timestamp = entry.effectiveTimestamp == entry.day ? entry.createdAt : entry.effectiveTimestamp
        return formatter.string(from: timestamp)
    }
}
