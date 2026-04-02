import Combine
import SwiftUI

struct SettingsView: View {
    private struct SharePayload: Identifiable {
        let id = UUID()
        let urls: [URL]
    }

    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(\.modelContext) private var modelContext
    @State private var sharePayload: SharePayload?
    @State private var previewIndex = 0
    @State private var activePaywall: PremiumFeature?
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

    private var previewCardBackgroundStyle: AnyShapeStyle {
        if colorScheme == .light {
            AnyShapeStyle(Color.appBackground)
        } else {
            AnyShapeStyle(.thinMaterial)
        }
    }

    private var previewCardBorderOpacity: Double {
        colorScheme == .light ? 0.06 : 0.18
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
                                .foregroundStyle(.primary)
                            Text(previewMessage)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(previewCardBackgroundStyle)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(previewCardBorderOpacity), lineWidth: 1)
                        }
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
            
            #if DEBUG
            Section("Debug") {
                Button("Toggle Premium (Debug)") {
                    purchaseService.premiumStatus =
                        purchaseService.premiumStatus == .premium ? .free : .premium
                }
            }
            #endif

            Section {
                ProSettingsCard(
                    premiumStatus: purchaseService.premiumStatus,
                    showProView: $userSettings.showPremiumInsightsView,
                    greigModeEnabled: $userSettings.greigModeEnabled,
                    unlockAction: {
                        guard purchaseService.premiumStatus == .free else { return }
                        activePaywall = .advancedInsights
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Data") {
                ExportDataRow(
                    premiumStatus: purchaseService.premiumStatus,
                    action: handleExportDataTap
                )
            }

        }
        .navigationTitle("Settings")
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.urls)
        }
        .sheet(item: $activePaywall) { feature in
            PaywallView(feature: feature)
        }
    }
    
    func exportCSV() {
        do {
            let service = CSVExportService(modelContext: modelContext)
            let urls = try service.export().filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !urls.isEmpty else { return }
            sharePayload = SharePayload(urls: urls)
        } catch { }
    }

    func handleExportDataTap() {
        switch purchaseService.premiumStatus {
        case .unknown:
            return
        case .premium:
            exportCSV()
        case .free:
            Haptics.impactLight()
            activePaywall = .dataExport
        }
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

private struct ProSettingsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let premiumStatus: PremiumStatus
    @Binding var showProView: Bool
    @Binding var greigModeEnabled: Bool
    let unlockAction: () -> Void

    private let accentColor = Color.systemAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch premiumStatus {
            case .premium:
                proSummaryContent

                divider

                settingsToggle(
                    title: "Show Pro View",
                    message: "Show the Pro insights card on your Cadence home screen.",
                    isOn: $showProView
                )

                divider

                settingsToggle(
                    title: "Greig Mode",
                    message: "Show potential insights based on your strongest performance.",
                    isOn: $greigModeEnabled
                )
                .accessibilityLabel("Greig Mode")
                .accessibilityHint("Show potential insights based on your strongest performance.")
            case .free:
                lockedContent
            case .unknown:
                neutralContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(level: .highlighted, accent: accentColor, tinted: colorScheme == .light, cornerRadius: 16)
    }

    private var divider: some View {
        Divider()
            .padding(.horizontal, 16)
    }

    private func settingsToggle(title: String, message: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private var proSummaryContent: some View {
        HStack(alignment: .top, spacing: 12) {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.28),
                    accentColor.opacity(0.12),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 5)
            .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 6) {
                CadenceProWordmark(size: .small)

                Text("Thank you for supporting Cadence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private var lockedContent: some View {
        Button(action: unlockAction) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    CadenceProWordmark(size: .small)

                    Text("Unlock insights, Greig Mode, and data export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private var neutralContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            CadenceProWordmark(size: .small)

            Text("Checking subscription status...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

private struct ExportDataRow: View {
    let premiumStatus: PremiumStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
                    .premiumIconStyle(
                        isPremiumUnlocked: premiumStatus == .premium,
                        isFeatureLocked: premiumStatus == .free
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Data")
                        .foregroundStyle(.primary)

                    Text("Download your data as CSV")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if premiumStatus == .free {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)

                        Text("Included in Pro")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
