import SwiftData
import SwiftUI

@MainActor
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userSettings: UserSettings

    private let flowController: OnboardingFlowController
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showCustomHabitSheet = false
    @State private var heroIconScale: CGFloat = 0.94
    @State private var showQuickHabitError = false

    init(flowController: OnboardingFlowController? = nil) {
        self.flowController = flowController ?? OnboardingFlowController()
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            stepContent
                .id(currentStep.id)
                .transition(.opacity)

            Spacer()

            OnboardingPageIndicator(
                currentIndex: currentStep.rawValue,
                count: OnboardingStep.allCases.count
            )

            if let primaryButtonTitle = currentStep.primaryButtonTitle {
                Button {
                    Task {
                        currentStep = await flowController.handlePrimaryAction(from: currentStep)
                    }
                } label: {
                    Text(primaryButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }

            if let secondaryButtonTitle = currentStep.secondaryButtonTitle {
                Button(secondaryButtonTitle) {
                    currentStep = flowController.handleSecondaryAction(from: currentStep)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.onboardingSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.onboardingBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.24), value: currentStep.rawValue)
        .sheet(isPresented: $showCustomHabitSheet) {
            AddHabitSheet { _ in
                flowController.completeOnboarding(userSettings: userSettings)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .alert("Couldn’t create habit", isPresented: $showQuickHabitError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        .onAppear {
            animateHeroIcon()
        }
        .onChange(of: currentStep) { _, _ in
            animateHeroIcon()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .benefits:
            benefitsStep
        case .notifications:
            notificationsStep
        case .firstHabit:
            FirstHabitStepView(
                onSelectPreset: createQuickHabit,
                onCreateCustomHabit: { showCustomHabitSheet = true }
            )
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.onboardingAccent)
                .scaleEffect(heroIconScale)

            Text("Build habits that stick")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Track your routines, build streaks, and watch your progress grow day by day.")
                .font(.body)
                .foregroundStyle(Color.onboardingSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
    }

    private var benefitsStep: some View {
        VStack(spacing: 24) {
            Text("Small habits. Big results.")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                benefitRow(
                    symbolName: "calendar",
                    title: "Stay in rhythm",
                    message: "Visual progress keeps motivation high."
                )

                benefitRow(
                    symbolName: "flame",
                    title: "Build streaks",
                    message: "Small daily wins turn into long-term habits."
                )

                benefitRow(
                    symbolName: "chart.line.uptrend.xyaxis",
                    title: "Understand patterns",
                    message: "Insights reveal when you perform best."
                )
            }
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.onboardingAccent)
                .scaleEffect(heroIconScale)

            Text("Stay in rhythm")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Gentle reminders help you stay in rhythm with your habits.")
                .font(.body)
                .foregroundStyle(Color.onboardingSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
    }

    private func benefitRow(symbolName: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.onboardingAccent)
                .frame(width: 26)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.onboardingSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func createQuickHabit(_ preset: QuickHabitPreset) {
        do {
            try flowController.createQuickHabit(
                from: preset,
                modelContext: modelContext,
                userSettings: userSettings
            )
        } catch {
            showQuickHabitError = true
        }
    }

    private func animateHeroIcon() {
        heroIconScale = 0.94

        withAnimation(.easeOut(duration: 0.25)) {
            heroIconScale = 1
        }
    }
}
