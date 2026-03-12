import Combine
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @State private var previewIndex = 0
    private let previewTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    private var eveningReflectionTime: Binding<Date> {
        Binding<Date>(
            get: {
                EveningReflection.date(
                    hour: userSettings.eveningReflectionHour,
                    minute: userSettings.eveningReflectionMinute,
                    on: Date(),
                    calendar: .current
                )
            },
            set: { newDate in
                let normalized = EveningReflection.clamped(date: newDate, calendar: .current)
                let components = Calendar.current.dateComponents([.hour, .minute], from: normalized)
                userSettings.eveningReflectionHour = components.hour ?? EveningReflection.defaultHour
                userSettings.eveningReflectionMinute = components.minute ?? EveningReflection.defaultMinute
            }
        )
    }

    private var eveningTimeRange: ClosedRange<Date> {
        EveningReflection.timeRange(for: Date(), calendar: .current)
    }

    private var previewMessage: String {
        let messages = EveningReflection.previewMessages
        guard !messages.isEmpty else { return "" }
        return messages[previewIndex % messages.count]
    }

    private var eveningReflectionToggle: Binding<Bool> {
        Binding(
            get: { userSettings.eveningReflectionEnabled },
            set: { isEnabled in
                withAnimation(.easeInOut(duration: 0.22)) {
                    userSettings.eveningReflectionEnabled = isEnabled
                }
            }
        )
    }

    var body: some View {
        Form {
            Section("General") {
                Picker("Week starts on", selection: $userSettings.weekStartPreference) {
                    ForEach(WeekStartPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
            }

            Section("Insights") {
                Toggle(isOn: $userSettings.greigModeEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Greig Mode")
                            .font(.body)
                        Text("Show potential insights based on your strongest performance.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("Greig Mode")
                .accessibilityHint("Show potential insights based on your strongest performance.")
            }

            Section("Evening Reflection") {
                Text(EveningReflection.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Enable Evening Reflection", isOn: eveningReflectionToggle)

                if userSettings.eveningReflectionEnabled {
                    DatePicker(
                        "Time",
                        selection: eveningReflectionTime,
                        in: eveningTimeRange,
                        displayedComponents: .hourAndMinute
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(EveningReflection.title)
                                .font(.headline)
                            Text(previewMessage)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .onReceive(previewTimer) { _ in
                let messages = EveningReflection.previewMessages
                guard messages.count > 1 else { return }
                previewIndex = (previewIndex + 1) % messages.count
            }
            .onChange(of: userSettings.eveningReflectionEnabled) { _, isEnabled in
                Task {
                    guard isEnabled else {
                        NotificationService.shared.removeEveningReflection()
                        return
                    }

                    let status = await NotificationService.shared.notificationStatus()

                    if status == .denied {
                        userSettings.eveningReflectionEnabled = false
                        return
                    }

                    if status == .notDetermined {
                        let granted = await NotificationService.shared.requestPermission()

                        if !granted {
                            userSettings.eveningReflectionEnabled = false
                            return
                        }
                    }

                    await NotificationService.shared.scheduleEveningReflection(
                        hour: userSettings.eveningReflectionHour,
                        minute: userSettings.eveningReflectionMinute
                    )
                }
            }
            .onChange(of: userSettings.eveningReflectionHour) { _, _ in
                rescheduleReminder()
            }

            .onChange(of: userSettings.eveningReflectionMinute) { _, _ in
                rescheduleReminder()
            }
        }
        .navigationTitle("Settings")
    }
    
    func rescheduleReminder() {
        Task {
            NotificationService.shared.removeEveningReflection()

            if userSettings.eveningReflectionEnabled {
                await NotificationService.shared.scheduleEveningReflection(
                    hour: userSettings.eveningReflectionHour,
                    minute: userSettings.eveningReflectionMinute
                )
            }
        }
    }
}
