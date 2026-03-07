import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var userSettings: UserSettings

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
        }
        .navigationTitle("Settings")
    }
}
