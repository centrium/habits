import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct HabitColorVariants {
    let base: Color
    let strong: Color
    let soft: Color

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
        let dark = CadenceColorPalette.dark(for: paletteToken)
        return HabitColorVariants(
            base: Color.dynamic(lightHex: light.base, darkHex: dark.base),
            strong: Color.dynamic(lightHex: light.strong, darkHex: dark.strong),
            soft: Color.dynamic(lightHex: light.soft, darkHex: dark.soft)
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

private extension Color {
    static func dynamic(lightHex: String, darkHex: String) -> Color {
        #if canImport(UIKit)
        return Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
            }
        )
        #elseif canImport(AppKit)
        let dynamic = NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: match == .darkAqua ? darkHex : lightHex)
        } ?? NSColor(hex: lightHex)
        return Color(dynamic)
        #else
        return Color(hex: lightHex)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 255) / 255
        let g = CGFloat((int >> 8) & 255) / 255
        let b = CGFloat(int & 255) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 255) / 255
        let g = CGFloat((int >> 8) & 255) / 255
        let b = CGFloat(int & 255) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif
