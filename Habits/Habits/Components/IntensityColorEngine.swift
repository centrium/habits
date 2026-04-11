import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    private static let intensityCurve: [Double] = [
        0.0,
        0.12,
        0.32,
        0.55,
        0.75,
        0.92
    ]

    static func color(forLogCount logCount: Int, habitColor: HabitColor, colorScheme: ColorScheme) -> Color {
        style(forLogCount: logCount, habitColor: habitColor, colorScheme: colorScheme).fill
    }

    static func style(forLogCount logCount: Int, habitColor: HabitColor, colorScheme: ColorScheme) -> IntensityVisualStyle {
        style(forLevel: level(forLogCount: logCount), habitColor: habitColor, colorScheme: colorScheme)
    }

    static func style(forLevel level: Int, habitColor: HabitColor, colorScheme: ColorScheme) -> IntensityVisualStyle {
        let normalizedLevel = max(0, min(level, 5))
        let palette = palette(for: habitColor, colorScheme: colorScheme)

        return IntensityVisualStyle(
            level: normalizedLevel,
            fill: palette.levels[normalizedLevel],
            border: palette.borders[normalizedLevel],
            peakScale: 1,
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
        let base = habitColor.variants.base
        let scale: [Color] = (0...5).map { level in
            if level == 0 {
                return zeroColor(for: colorScheme)
            }

            return heatmapColor(
                base: base,
                intensity: intensityCurve[level],
                colorScheme: colorScheme
            )
        }

        return HeatmapPalette(
            levels: scale,
            borders: [
                colorScheme == .dark ? neutralDarkBorder : neutralLightBorder,
                borderColor(for: scale[1], colorScheme: colorScheme),
                borderColor(for: scale[2], colorScheme: colorScheme),
                borderColor(for: scale[3], colorScheme: colorScheme),
                borderColor(for: scale[4], colorScheme: colorScheme),
                borderColor(for: scale[5], colorScheme: colorScheme)
            ]
        )
    }

    private static func zeroColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    private static func heatmapColor(
        base: Color,
        intensity: Double,
        colorScheme: ColorScheme
    ) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(base)

        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        switch colorScheme {
        case .light:
            return Color(
                UIColor(
                    hue: h,
                    saturation: max(0.65, s),
                    brightness: 1.0 - (0.65 * (1 - intensity)),
                    alpha: 1
                )
            )

        case .dark:
            return Color(
                UIColor(
                    hue: h,
                    saturation: max(0.55, s),
                    brightness: 0.25 + (0.7 * intensity),
                    alpha: 1
                )
            )

        @unknown default:
            return base
        }
        #else
        return base
        #endif
    }

    private static func borderColor(for fillColor: Color, colorScheme: ColorScheme) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(fillColor)

        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        switch colorScheme {
        case .light:
            return Color(
                UIColor(
                    hue: h,
                    saturation: max(0.4, s * 0.95),
                    brightness: max(0.0, b - 0.08),
                    alpha: 1
                )
            )
        case .dark:
            return Color(
                UIColor(
                    hue: h,
                    saturation: max(0.4, s * 0.9),
                    brightness: min(1.0, b + 0.08),
                    alpha: 1
                )
            )
        @unknown default:
            return fillColor
        }
        #else
        return fillColor
        #endif
    }
}
