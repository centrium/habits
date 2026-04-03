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
            AnyShapeStyle(CadenceTokens.Color.Background.primary)
        } else {
            AnyShapeStyle(.thinMaterial)
        }
    }

    private var previewCardBorderOpacity: Double {
        colorScheme == .light ? 0.06 : 0.18
    }

    var body: some View {
        Form {
            Section {
                Picker("Week starts on", selection: $userSettings.weekStartPreference) {
                    ForEach(WeekStartPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
            } header: {
                SettingsSectionHeader("General")
            }

            Section {
                Text(EveningReflection.description)
                    .font(CadenceTokens.Typography.supporting)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)

                Toggle("Enable Evening Reflection", isOn: eveningReflectionToggle)

                if userSettings.eveningReflectionEnabled {
                    DatePicker(
                        "Time",
                        selection: eveningReflectionTime,
                        in: eveningTimeRange,
                        displayedComponents: .hourAndMinute
                    )

                    VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                        Text("Preview")
                            .font(CadenceTokens.Typography.sectionHeader)
                            .fontWeight(.semibold)
                            .foregroundStyle(CadenceTokens.Color.Text.primary)

                        VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                            Text(EveningReflection.title)
                                .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                                .foregroundStyle(CadenceTokens.Color.Text.primary)
                            Text(previewMessage)
                                .font(CadenceTokens.Typography.body)
                                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        }
                        .padding(CadenceTokens.Space.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CadenceTokens.Space.md)
                                .fill(previewCardBackgroundStyle)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: CadenceTokens.Space.md)
                                .stroke(CadenceTokens.Color.Text.primary.opacity(previewCardBorderOpacity), lineWidth: CadenceTokens.Surface.strokeLineWidth)
                        }
                    }
                    .padding(.vertical, CadenceTokens.Space.xs / 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } header: {
                SettingsSectionHeader("Notifications")
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

            Section {
                Toggle("Tap to Log", isOn: $userSettings.tapToLogEnabled)
            } header: {
                SettingsSectionHeader("Behaviour")
            }

            Section {
                ProSettingsCard(
                    premiumStatus: purchaseService.premiumStatus,
                    showProView: $userSettings.showPremiumInsightsView,
                    greigModeEnabled: $userSettings.greigModeEnabled,
                    exportAction: handleExportDataTap,
                    unlockAction: {
                        guard purchaseService.premiumStatus == .free else { return }
                        activePaywall = .advancedInsights
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                SettingsSectionHeader("Premium")
            }

            #if DEBUG
            Section {
                Button("Toggle Premium (Debug)") {
                    purchaseService.premiumStatus =
                        purchaseService.premiumStatus == .premium ? .free : .premium
                }
            } header: {
                SettingsSectionHeader("Debug")
            }
            #endif
        }
        .listSectionSpacing(22)
        .scrollContentBackground(.hidden)
        .background(CadenceTokens.Color.Background.primary)
        .environment(\.defaultMinListRowHeight, 54)
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
    let exportAction: () -> Void
    let unlockAction: () -> Void

    private let accentColor = CadenceTokens.Color.accent(from: HabitColor.default.hex).primary

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
            switch premiumStatus {
            case .premium:
                proSummaryContent

                settingsToggle(
                    title: "Show Pro View",
                    message: "Show the Pro insights card on your Cadence home screen.",
                    isOn: $showProView
                )

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

            ExportDataRow(
                premiumStatus: premiumStatus,
                action: exportAction
            )
            .padding(.horizontal, CadenceTokens.Space.md)
            .padding(.top, CadenceTokens.Space.xs / 2)
        }
        .padding(.bottom, CadenceTokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
    }

    private func settingsToggle(title: String, message: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                Text(title)
                    .font(CadenceTokens.Typography.body)
                    .foregroundStyle(CadenceTokens.Color.Text.primary)
                Text(message)
                    .font(CadenceTokens.Typography.supporting)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
            }
            .padding(.trailing, CadenceTokens.Space.md)
        }
        .padding(.vertical, CadenceTokens.Space.sm + 2)
        .padding(.horizontal, CadenceTokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: CadenceTokens.Space.md)
                .fill(CadenceTokens.Color.Background.tertiary)
        )
        .padding(.horizontal, CadenceTokens.Space.md)
    }

    private var proSummaryContent: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.sm - 2) {
            CadenceProWordmark(size: .small)

            Text("Thank you for supporting Cadence.")
                .font(CadenceTokens.Typography.supporting)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, CadenceTokens.Space.md + 2)
        .padding(.bottom, CadenceTokens.Space.xs)
        .padding(.horizontal, CadenceTokens.Space.lg)
    }

    private var lockedContent: some View {
        Button(action: unlockAction) {
            HStack(alignment: .top, spacing: CadenceTokens.Space.md) {
                Image(systemName: "lock.fill")
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.top, CadenceTokens.Space.xs / 2)

                VStack(alignment: .leading, spacing: CadenceTokens.Space.sm - 2) {
                    CadenceProWordmark(size: .small)

                    Text("Unlock insights, Greig Mode, and data export.")
                        .font(CadenceTokens.Typography.supporting)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, CadenceTokens.Space.md + 2)
            .padding(.horizontal, CadenceTokens.Space.lg)
        }
        .buttonStyle(.plain)
    }

    private var neutralContent: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.sm - 2) {
            CadenceProWordmark(size: .small)

            Text("Checking subscription status...")
                .font(CadenceTokens.Typography.supporting)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, CadenceTokens.Space.md + 2)
        .padding(.horizontal, CadenceTokens.Space.lg)
    }
}

private struct ExportDataRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let premiumStatus: PremiumStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CadenceTokens.Space.md) {
                Image(systemName: "square.and.arrow.up")
                    .font(CadenceTokens.Typography.body)
                    .premiumIconStyle(
                        isPremiumUnlocked: premiumStatus == .premium,
                        isFeatureLocked: premiumStatus == .free
                    )

                VStack(alignment: .leading, spacing: CadenceTokens.Space.xs / 2) {
                    Text("Export Data")
                        .font(CadenceTokens.Typography.body)
                        .foregroundStyle(CadenceTokens.Color.Text.primary)

                    Text("Download your data as CSV")
                        .font(CadenceTokens.Typography.supporting)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                }

                Spacer()

                if premiumStatus == .free {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)

                        Text("Included in Pro")
                            .font(.caption2)
                    }
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, CadenceTokens.Space.sm + 2)
            .padding(.horizontal, CadenceTokens.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: CadenceTokens.Space.md)
                    .fill(CadenceTokens.Color.Background.tertiary)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(CadenceTokens.Typography.supporting)
            .fontWeight(.semibold)
            .foregroundStyle(CadenceTokens.Color.Text.secondary)
            .textCase(.uppercase)
            .tracking(0.3)
            .padding(.bottom, CadenceTokens.Space.xs)
    }
}
