import CoreGraphics
import Foundation

enum StreakIndicatorPresentation {
    static let reservedWidth: CGFloat = 40

    static func shouldShow(streak: Int) -> Bool {
        streak >= 2
    }

    static func valueText(for streak: Int) -> String {
        "\(streak)"
    }
}
