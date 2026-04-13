import SwiftUI

struct CadenceAccentTokens {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let ambient: Color
    let highlight: Color
}

struct CadenceSemanticAccentTokens {
    let cadenceAccentPrimary: Color
    let cadenceAccentSecondary: Color
    let cadenceAccentSubtle: Color
}

enum CadenceTokens {
    enum Color {
        enum Background {
            static let primary = SwiftUI.Color(uiColor: .systemBackground)
            static let secondary = SwiftUI.Color(uiColor: .secondarySystemBackground)
            static let tertiary = SwiftUI.Color(uiColor: .tertiarySystemBackground)
        }

        enum Text {
            static let primary = SwiftUI.Color.primary
            static let secondary = SwiftUI.Color.primary.opacity(0.65)
            static let tertiary = SwiftUI.Color.primary.opacity(0.5)
        }

        enum State {
            static let success = HabitColor.fern.variants.strong
            static let warning = HabitColor.amber.variants.strong
            static let negative = HabitColor.coral.variants.strong
        }

        static func accent(for habit: Habit) -> CadenceAccentTokens {
            accent(from: habit.colorHex)
        }

        static func accent(from hex: String) -> CadenceAccentTokens {
            let variants = HabitColor.from(hex: hex).variants
            return CadenceAccentTokens(
                primary: variants.strong,
                secondary: variants.base,
                tertiary: variants.soft,
                ambient: variants.ambient,
                highlight: variants.highlight
            )
        }

        static func semanticAccent(
            for habit: Habit,
            colorScheme: ColorScheme
        ) -> CadenceSemanticAccentTokens {
            semanticAccent(from: habit.colorHex, colorScheme: colorScheme)
        }

        static func semanticAccent(
            from hex: String,
            colorScheme: ColorScheme
        ) -> CadenceSemanticAccentTokens {
            let accent = accent(from: hex)

            if colorScheme == .light {
                return CadenceSemanticAccentTokens(
                    cadenceAccentPrimary: accent.primary.opacity(0.9),
                    cadenceAccentSecondary: accent.secondary.opacity(0.78),
                    cadenceAccentSubtle: accent.tertiary.opacity(0.55)
                )
            }

            return CadenceSemanticAccentTokens(
                cadenceAccentPrimary: accent.primary.opacity(0.96),
                cadenceAccentSecondary: accent.secondary.opacity(0.86),
                cadenceAccentSubtle: accent.tertiary.opacity(0.64)
            )
        }
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let x2l: CGFloat = 24
        static let x3l: CGFloat = 32
    }

    enum Typography {
        static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let titleTracking: CGFloat = -0.2
        static let heroHeadline = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let sectionHeader = Font.system(size: 15, weight: .medium)
        static let primaryValue = Font.system(size: 28, weight: .semibold)
        static let body = Font.system(size: 14)
        static let supporting = Font.system(size: 14)
        static let microCopy = Font.system(size: 13, weight: .medium)
    }

    enum Surface {
        static let cardCornerRadius: CGFloat = 16
        static let elevatedCornerRadius: CGFloat = 18
        static let strokeLineWidth: CGFloat = 1
        static let shadowRadius: CGFloat = 6
        static let shadowYOffset: CGFloat = 2

        static func strokeColor(for colorScheme: ColorScheme) -> SwiftUI.Color {
            colorScheme == .dark
                ? SwiftUI.Color.white.opacity(0.1)
                : SwiftUI.Color.black.opacity(0.06)
        }

        static func shadowColor(for colorScheme: ColorScheme) -> SwiftUI.Color {
            colorScheme == .dark
                ? SwiftUI.Color.black.opacity(0.22)
                : SwiftUI.Color.black.opacity(0.06)
        }
    }

    enum Intensity {
        // Global visual tuning knobs.
        // 1.0 = current calibrated baseline.
        static let ambientSurface: CGFloat = 1.0
        static let heatmapGlow: CGFloat = 1.18
    }
}
