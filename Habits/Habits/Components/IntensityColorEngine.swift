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
    private static let neutralLightFill = Color(hex: "#E7EBEF")
    private static let neutralLightBorder = Color.black.opacity(0.12)
    private static let neutralDarkFill = Color(hex: "#1B2128")
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
        let scaleHex = heatmapScale(for: habitColor)
        let neutralFill = colorScheme == .dark ? neutralDarkFill : neutralLightFill
        let scale = [
            neutralFill,
            Color(hex: scaleHex[1]),
            Color(hex: scaleHex[2]),
            Color(hex: scaleHex[3]),
            Color(hex: scaleHex[4]),
            Color(hex: scaleHex[5])
        ]

        return HeatmapPalette(
            levels: scale,
            borders: [
                colorScheme == .dark ? neutralDarkBorder : neutralLightBorder,
                borderColor(for: scaleHex[1], colorScheme: colorScheme),
                borderColor(for: scaleHex[2], colorScheme: colorScheme),
                borderColor(for: scaleHex[3], colorScheme: colorScheme),
                borderColor(for: scaleHex[4], colorScheme: colorScheme),
                borderColor(for: scaleHex[5], colorScheme: colorScheme)
            ]
        )
    }

    private static func heatmapScale(for habitColor: HabitColor) -> [String] {
        switch habitColor {
        case .fern, .sage:
            return [
                "#121E12",
                "#E4F1DE",
                "#C8E6BE",
                "#9FD173",
                "#73B34A",
                "#4F7A3F"
            ]
        case .cobalt, .sky:
            return [
                "#0D1C2A",
                "#E1EDFA",
                "#C4DCF3",
                "#8FBBE6",
                "#5C94D2",
                "#2F5F8A"
            ]
        case .iris, .amethyst:
            return [
                "#1A1426",
                "#ECE5F8",
                "#D5C4EF",
                "#B497DE",
                "#8C6BCB",
                "#5E3F8A"
            ]
        case .teal, .cyan:
            return [
                "#0F1F1E",
                "#E1F4F2",
                "#BFE9E3",
                "#84D2C7",
                "#49B7A8",
                "#176E68"
            ]
        case .rose, .coral:
            return [
                "#211517",
                "#F8E7EB",
                "#F1CBD5",
                "#E29DAF",
                "#C97186",
                "#7A3F47"
            ]
        case .amber:
            return [
                "#2A250C",
                "#F8F0D9",
                "#EEDFAE",
                "#E0C36A",
                "#C29A1F",
                "#8A6E14"
            ]
        case .apricot:
            return [
                "#2A1A0C",
                "#F9EBDD",
                "#F3D5BC",
                "#E8B186",
                "#D3874A",
                "#8A4A14"
            ]
        }
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
