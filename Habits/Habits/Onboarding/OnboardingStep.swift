import SwiftData
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case benefits
    case notifications
    case firstHabit

    var id: Int { rawValue }

    var primaryButtonTitle: String? {
        switch self {
        case .welcome:
            return "Get Started"
        case .benefits:
            return "Continue"
        case .notifications:
            return "Enable Reminders"
        case .firstHabit:
            return nil
        }
    }

    var secondaryButtonTitle: String? {
        switch self {
        case .notifications:
            return "Not Now"
        default:
            return nil
        }
    }
}

enum QuickHabitPreset: String, CaseIterable, Identifiable {
    case walk
    case read
    case drinkWater

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .walk:
            return "figure.walk"
        case .read:
            return "book"
        case .drinkWater:
            return "drop.fill"
        }
    }

    var name: String {
        switch self {
        case .walk:
            return "Walk"
        case .read:
            return "Read"
        case .drinkWater:
            return "Drink Water"
        }
    }

    var cadence: String {
        "Daily"
    }

    var colorHex: String {
        switch self {
        case .walk:
            return "#3B82F6"
        case .read:
            return "#14B8A6"
        case .drinkWater:
            return "#0EA5E9"
        }
    }
}

protocol OnboardingNotificationPermissionRequesting {
    func requestPermission() async -> Bool
}

protocol OnboardingCompletionStateStore: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
}

extension UserSettings: OnboardingCompletionStateStore {}

struct OnboardingNotificationPermissionRequester: OnboardingNotificationPermissionRequesting {
    func requestPermission() async -> Bool {
        await NotificationService.shared.requestPermission()
    }
}

struct OnboardingFlowController {
    private let notificationPermissionRequester: any OnboardingNotificationPermissionRequesting

    init(notificationPermissionRequester: any OnboardingNotificationPermissionRequesting = OnboardingNotificationPermissionRequester()) {
        self.notificationPermissionRequester =
            notificationPermissionRequester
    }

    func handlePrimaryAction(from step: OnboardingStep) async -> OnboardingStep {
        switch step {
        case .welcome, .benefits:
            return nextStep(after: step)
        case .notifications:
            _ = await notificationPermissionRequester.requestPermission()
            return nextStep(after: step)
        case .firstHabit:
            return .firstHabit
        }
    }

    func handleSecondaryAction(from step: OnboardingStep) -> OnboardingStep {
        guard step == .notifications else { return step }
        return nextStep(after: step)
    }

    @discardableResult
    func createQuickHabit(
        from preset: QuickHabitPreset,
        modelContext: ModelContext,
        userSettings: any OnboardingCompletionStateStore
    ) throws -> Habit {
        let habit = Habit(
            name: preset.name,
            colorHex: preset.colorHex,
            iconName: preset.symbolName,
            hasStreakGoal: true,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1
        )

        modelContext.insert(habit)
        try modelContext.save()

        completeOnboarding(userSettings: userSettings)
        return habit
    }

    func completeOnboarding(userSettings: any OnboardingCompletionStateStore) {
        userSettings.hasCompletedOnboarding = true
    }

    private func nextStep(after step: OnboardingStep) -> OnboardingStep {
        let nextIndex = step.rawValue + 1
        guard nextIndex < OnboardingStep.allCases.count,
              let nextStep = OnboardingStep(rawValue: nextIndex) else {
            return step
        }

        return nextStep
    }
}

extension Color {
    static let onboardingBackground = Color(.systemBackground)
    static let onboardingAccent = Color.accentColor.opacity(0.9)
    static let onboardingSecondary = Color.secondary.opacity(0.8)
}
