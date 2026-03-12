import SwiftUI

struct OnboardingPageIndicator: View {
    let currentIndex: Int
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.onboardingAccent : Color.onboardingSecondary.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentIndex ? 1.2 : 1)
                    .animation(.easeInOut(duration: 0.22), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentIndex + 1) of \(count)")
    }
}
