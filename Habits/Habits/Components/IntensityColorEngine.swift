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
    private static let neutralLightBorder = Color.black.opacity(0.12)
    private static let neutralDarkBorder = Color.white.opacity(0.16)

    static func color(forLogCount logCount: Int, habitColor: HabitColor, colorScheme: ColorScheme) -> Color {
        HeatmapColorResolver.color(
            for: logCount,
            habitColor: habitColor,
            scheme: colorScheme
        )
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
        let paletteScale = colorScheme == .dark
            ? CadenceColorPalette.heatmapDark(for: habitColor.paletteToken)
            : CadenceColorPalette.heatmapLight(for: habitColor.paletteToken)
        let scale = [
            HeatmapColorResolver.color(for: 0, habitColor: habitColor, scheme: colorScheme),
            Color(hex: paletteScale.scale1),
            Color(hex: paletteScale.scale2),
            Color(hex: paletteScale.scale3),
            Color(hex: paletteScale.scale4),
            Color(hex: paletteScale.scale5)
        ]

        return HeatmapPalette(
            levels: scale,
            borders: [
                colorScheme == .dark ? neutralDarkBorder : neutralLightBorder,
                borderColor(for: paletteScale.scale1, colorScheme: colorScheme),
                borderColor(for: paletteScale.scale2, colorScheme: colorScheme),
                borderColor(for: paletteScale.scale3, colorScheme: colorScheme),
                borderColor(for: paletteScale.scale4, colorScheme: colorScheme),
                borderColor(for: paletteScale.scale5, colorScheme: colorScheme)
            ]
        )
    }

    private static func borderColor(for fillHex: String, colorScheme: ColorScheme) -> Color {
        let mixTarget = colorScheme == .dark ? "#FFFFFF" : "#000000"
        let mixAmount = colorScheme == .dark ? 0.16 : 0.14
        return Color(
            hex: CadenceColorPalette.mix(
                hex: fillHex,
                with: mixTarget,
                towardSecond: mixAmount
            )
        )
    }
}
