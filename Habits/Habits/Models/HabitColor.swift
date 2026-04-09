import SwiftUI

struct HabitColorVariants {
    let base: Color
    let strong: Color
    let soft: Color
    let ambient: Color
    let highlight: Color

    // Backward-compatible alias used by existing call sites.
    var accent: Color { strong }
}

enum HabitColor: String, CaseIterable, Identifiable {
    case fern
    case sage
    case cobalt
    case sky
    case iris
    case amethyst
    case apricot
    case amber
    case coral
    case rose
    case teal
    case cyan

    var id: String { rawValue }
    var hex: String { CadenceColorPalette.light(for: paletteToken).base }

    var name: String {
        switch self {
        case .fern: return "Fern"
        case .sage: return "Sage"
        case .cobalt: return "Cobalt"
        case .sky: return "Sky"
        case .iris: return "Iris"
        case .amethyst: return "Amethyst"
        case .apricot: return "Apricot"
        case .amber: return "Amber"
        case .coral: return "Coral"
        case .rose: return "Rose"
        case .teal: return "Teal"
        case .cyan: return "Cyan"
        }
    }

    var color: Color {
        variants.base
    }

    var variants: HabitColorVariants {
        let light = CadenceColorPalette.light(for: paletteToken)
        return HabitColorVariants(
            base: Color(hex: light.base),
            strong: Color(hex: light.strong),
            soft: Color(hex: light.soft),
            ambient: Color(hex: light.soft),
            highlight: Color(hex: light.strong)
        )
    }

    static let `default`: HabitColor = .cobalt

    static func from(hex: String) -> HabitColor {
        let normalized = CadenceColorPalette.normalizeHex(hex)
        if let paletteToken = CadenceColorPalette.token(from: normalized) {
            return from(token: paletteToken)
        }

        let stripped = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
        if let tokenByName = CadencePaletteToken(rawValue: stripped) {
            return from(token: tokenByName)
        }

        return .default
    }

    // Compatibility helpers for legacy call sites.
    var accentHex: String { CadenceColorPalette.light(for: paletteToken).strong }
    var softHex: String { CadenceColorPalette.light(for: paletteToken).soft }
    var softOpacity: Double { 1.0 }

    private var paletteToken: CadencePaletteToken {
        switch self {
        case .fern: return .fern
        case .sage: return .sage
        case .cobalt: return .cobalt
        case .sky: return .sky
        case .iris: return .iris
        case .amethyst: return .amethyst
        case .apricot: return .apricot
        case .amber: return .amber
        case .coral: return .coral
        case .rose: return .rose
        case .teal: return .teal
        case .cyan: return .cyan
        }
    }

    private static func from(token: CadencePaletteToken) -> HabitColor {
        switch token {
        case .fern: return .fern
        case .sage: return .sage
        case .cobalt: return .cobalt
        case .sky: return .sky
        case .iris: return .iris
        case .amethyst: return .amethyst
        case .apricot: return .apricot
        case .amber: return .amber
        case .coral: return .coral
        case .rose: return .rose
        case .teal: return .teal
        case .cyan: return .cyan
        }
    }
}

extension Habit {
    var curatedColor: HabitColor {
        HabitColor.from(hex: colorHex)
    }

    var curatedAccentColor: Color {
        curatedColor.variants.base
    }

    var curatedColorVariants: HabitColorVariants {
        curatedColor.variants
    }
}
