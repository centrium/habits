import SwiftUI

struct IntensityVisualStyle {
    let level: Int
    let fill: Color
    let border: Color
    let peakScale: CGFloat
    let peakShadowColor: Color
    let peakShadowRadius: CGFloat
    let peakShadowYOffset: CGFloat
}

struct HeatmapPalette {
    let levels: [Color]
    let borders: [Color]
}

enum IntensityColorEngine {
    private static let neutralLightFill = Color.black.opacity(0.055)
    private static let neutralLightBorder = Color.black.opacity(0.12)
    private static let neutralDarkFill = Color.white.opacity(0.08)
    private static let neutralDarkBorder = Color.white.opacity(0.16)

    static func color(forLogCount logCount: Int, habitColor: HabitColor, colorScheme: ColorScheme) -> Color {
        style(forLogCount: logCount, habitColor: habitColor, colorScheme: colorScheme).fill
    }

    static func style(forLogCount logCount: Int, habitColor: HabitColor, colorScheme: ColorScheme) -> IntensityVisualStyle {
        style(forLevel: level(forLogCount: logCount), habitColor: habitColor, colorScheme: colorScheme)
    }

    static func style(forLevel level: Int, habitColor: HabitColor, colorScheme: ColorScheme) -> IntensityVisualStyle {
        let normalizedLevel = max(0, min(level, 5))
        let isPeak = normalizedLevel == 5
        let palette = palette(for: habitColor, colorScheme: colorScheme)

        return IntensityVisualStyle(
            level: normalizedLevel,
            fill: palette.levels[normalizedLevel],
            border: palette.borders[normalizedLevel],
            peakScale: isPeak ? 1.03 : 1,
            peakShadowColor: .clear,
            peakShadowRadius: 0,
            peakShadowYOffset: 0
        )
    }

    static func level(forLogCount logCount: Int) -> Int {
        min(max(logCount, 0), 5)
    }

    static func style(forLevel level: Int, colorScheme: ColorScheme) -> IntensityVisualStyle {
        style(forLevel: level, habitColor: .default, colorScheme: colorScheme)
    }

    static func level(for intensity: Double) -> Int {
        switch intensity {
        case ..<0.001:
            return 0
        case ..<0.2:
            return 1
        case ..<0.4:
            return 2
        case ..<0.7:
            return 3
        case ..<1.0:
            return 4
        default:
            return 5
        }
    }

    private static func palette(for habitColor: HabitColor, colorScheme: ColorScheme) -> HeatmapPalette {
        let token = cadenceToken(for: habitColor)
        let tones = CadenceColorPalette.light(for: token)
        let base = tones.base

        if colorScheme == .dark {
            // Monotonic dark-mode ramp: each level gets brighter and more chromatic.
            let lv1 = CadenceColorPalette.mix(hex: base, with: "#11151A", towardSecond: 0.78)
            let lv2 = CadenceColorPalette.mix(hex: base, with: "#11151A", towardSecond: 0.64)
            let lv3 = CadenceColorPalette.mix(hex: base, with: "#11151A", towardSecond: 0.50)
            let lv4 = CadenceColorPalette.mix(hex: base, with: "#11151A", towardSecond: 0.34)
            let lv5 = CadenceColorPalette.mix(hex: base, with: "#11151A", towardSecond: 0.16)

            return HeatmapPalette(
                levels: [
                    neutralDarkFill,
                    Color(hex: lv1),
                    Color(hex: lv2),
                    Color(hex: lv3),
                    Color(hex: lv4),
                    Color(hex: lv5)
                ],
                borders: [
                    neutralDarkBorder,
                    Color(hex: CadenceColorPalette.mix(hex: lv1, with: "#FFFFFF", towardSecond: 0.14)),
                    Color(hex: CadenceColorPalette.mix(hex: lv2, with: "#FFFFFF", towardSecond: 0.16)),
                    Color(hex: CadenceColorPalette.mix(hex: lv3, with: "#FFFFFF", towardSecond: 0.18)),
                    Color(hex: CadenceColorPalette.mix(hex: lv4, with: "#FFFFFF", towardSecond: 0.20)),
                    Color(hex: CadenceColorPalette.mix(hex: lv5, with: "#FFFFFF", towardSecond: 0.24))
                ]
            )
        }

        // Monotonic light-mode ramp: each level gets deeper and more chromatic.
        let lv1 = CadenceColorPalette.mix(hex: base, with: "#FFFFFF", towardSecond: 0.78)
        let lv2 = CadenceColorPalette.mix(hex: base, with: "#FFFFFF", towardSecond: 0.64)
        let lv3 = CadenceColorPalette.mix(hex: base, with: "#FFFFFF", towardSecond: 0.50)
        let lv4 = CadenceColorPalette.mix(hex: base, with: "#FFFFFF", towardSecond: 0.36)
        let lv5 = CadenceColorPalette.mix(hex: base, with: "#FFFFFF", towardSecond: 0.22)

        return HeatmapPalette(
            levels: [
                neutralLightFill,
                Color(hex: lv1),
                Color(hex: lv2),
                Color(hex: lv3),
                Color(hex: lv4),
                Color(hex: lv5)
            ],
            borders: [
                neutralLightBorder,
                Color(hex: CadenceColorPalette.mix(hex: lv1, with: "#000000", towardSecond: 0.10)),
                Color(hex: CadenceColorPalette.mix(hex: lv2, with: "#000000", towardSecond: 0.12)),
                Color(hex: CadenceColorPalette.mix(hex: lv3, with: "#000000", towardSecond: 0.14)),
                Color(hex: CadenceColorPalette.mix(hex: lv4, with: "#000000", towardSecond: 0.16)),
                Color(hex: CadenceColorPalette.mix(hex: lv5, with: "#000000", towardSecond: 0.18))
            ]
        )
    }

    private static func cadenceToken(for habitColor: HabitColor) -> CadencePaletteToken {
        switch habitColor {
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
