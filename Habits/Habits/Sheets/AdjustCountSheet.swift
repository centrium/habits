//
//  AdjustCountSheet.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//


import SwiftUI

struct AdjustCountSheet: View {

    @Environment(\.dismiss) private var dismiss

    let date: Date
    let habit: Habit
    let service: HabitLogService

    @State private var value: Int

    init(date: Date, habit: Habit, service: HabitLogService) {
        self.date = date
        self.habit = habit
        self.service = service
        _value = State(initialValue: service.count(for: habit, on: date))
    }

    var body: some View {

        VStack(spacing: 24) {

            Text("Adjust count")
                .font(.headline)

            HStack(spacing: 24) {

                Button {
                    value = max(0, value - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                }

                Text("\(value)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(minWidth: 60)

                Button {
                    value += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                }
            }

            Divider()

            Button(role: .destructive) {
                service.setCount(for: habit, on: date, to: 0)
                dismiss()
            } label: {
                Text("Clear day")
            }

            Button("Done") {
                service.setCount(for: habit, on: date, to: value)
                dismiss()
            }
        }
        .padding(24)
        .presentationDetents([.height(280)])
    }
}