import SwiftUI

enum HeatmapColorResolver {
    static let zeroLightHex = "#E8EBEE"
    static let zeroDarkHex = "#2A2D31"

    static func color(
        for logCount: Int,
        habitColor: HabitColor,
        scheme: ColorScheme
    ) -> Color {
        Color(hex: hex(for: logCount, habitColor: habitColor, scheme: scheme))
    }

    static func hex(
        for logCount: Int,
        habitColor: HabitColor,
        scheme: ColorScheme
    ) -> String {
        let intensity = intensityLevel(for: logCount)
        return hex(forLevel: intensity, habitColor: habitColor, scheme: scheme)
    }

    private static func intensityLevel(for logCount: Int) -> Int {
        switch logCount {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 3
        case 4: return 4
        default: return 5
        }
    }

    private static func hex(
        forLevel level: Int,
        habitColor: HabitColor,
        scheme: ColorScheme
    ) -> String {
        let palette = scheme == .dark
            ? CadenceColorPalette.heatmapDark(for: habitColor.paletteToken)
            : CadenceColorPalette.heatmapLight(for: habitColor.paletteToken)

        switch level {
        case 0:
            return scheme == .dark ? zeroDarkHex : zeroLightHex
        case 1:
            return palette.scale1
        case 2:
            return palette.scale2
        case 3:
            return palette.scale3
        case 4:
            return palette.scale4
        default:
            return palette.scale5
        }
    }
}
