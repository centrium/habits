import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var userSettings: UserSettings

    private var checkInTime: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = userSettings.dailyCheckInHour
                components.minute = userSettings.dailyCheckInMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                userSettings.dailyCheckInHour = components.hour ?? 20
                userSettings.dailyCheckInMinute = components.minute ?? 0
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

            Section("Notifications") {
                Toggle("Daily Check-In Reminder", isOn: $userSettings.dailyCheckInEnabled)

                DatePicker(
                    "Time",
                    selection: checkInTime,
                    displayedComponents: .hourAndMinute
                )
            }
            .onChange(of: userSettings.dailyCheckInEnabled) { _, isEnabled in
                Task {

                    let status = await NotificationService.shared.notificationStatus()

                    if status == .notDetermined {
                        let granted = await NotificationService.shared.requestPermission()

                        if !granted {
                            userSettings.dailyCheckInEnabled = false
                            return
                        }
                    }

                    if isEnabled {
                        await NotificationService.shared.scheduleDailyCheckIn(
                            hour: userSettings.dailyCheckInHour,
                            minute: userSettings.dailyCheckInMinute
                        )
                    } else {
                        NotificationService.shared.removeDailyCheckIn()
                    }
                }
            }
            .onChange(of: userSettings.dailyCheckInHour) { _, _ in
                rescheduleReminder()
            }

            .onChange(of: userSettings.dailyCheckInMinute) { _, _ in
                rescheduleReminder()
            }
        }
        .navigationTitle("Settings")
    }
    
    func rescheduleReminder() {
        Task {
            NotificationService.shared.removeDailyCheckIn()

            if userSettings.dailyCheckInEnabled {
                await NotificationService.shared.scheduleDailyCheckIn(
                    hour: userSettings.dailyCheckInHour,
                    minute: userSettings.dailyCheckInMinute
                )
            }
        }
    }
}
