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
        }
        .navigationTitle("Settings")
    }
}
