import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct IntensityVisualStyle {
    let level: Int
    let fill: Color
    let border: Color
    let highlightOpacity: Double
    let peakScale: CGFloat
    let peakShadowColor: Color
    let peakShadowRadius: CGFloat
    let peakShadowYOffset: CGFloat
}

enum IntensityColorEngine {
    static func color(for intensity: Double, baseColor: Color, colorScheme: ColorScheme) -> Color {
        style(for: intensity, baseColor: baseColor, colorScheme: colorScheme).fill
    }

    static func style(for intensity: Double, baseColor: Color, colorScheme: ColorScheme) -> IntensityVisualStyle {
        let level = level(for: intensity)
        let peakOverflow = peakOverflowFactor(for: intensity)

        guard level > 0 else {
            return style(forLevel: 0, baseColor: baseColor, colorScheme: colorScheme)
        }

        let adjusted = tunedColor(
            baseColor: baseColor,
            level: level,
            colorScheme: colorScheme,
            peakOverflow: peakOverflow
        )
        let border = borderColor(
            from: adjusted,
            level: level,
            colorScheme: colorScheme,
            peakOverflow: peakOverflow
        )
        let highlight = highlightOpacity(
            for: level,
            colorScheme: colorScheme,
            peakOverflow: peakOverflow
        )
        let isPeak = level == 5

        return IntensityVisualStyle(
            level: level,
            fill: adjusted,
            border: border,
            highlightOpacity: highlight,
            peakScale: isPeak ? (1.03 + (0.02 * peakOverflow)) : 1,
            peakShadowColor: isPeak
                ? adjusted.opacity((colorScheme == .dark ? 0.17 : 0.12) + (0.05 * peakOverflow))
                : .clear,
            peakShadowRadius: isPeak ? (2.0 + (0.8 * peakOverflow)) : 0,
            peakShadowYOffset: isPeak ? (0.7 + (0.2 * peakOverflow)) : 0
        )
    }

    static func style(forLevel level: Int, baseColor: Color, colorScheme: ColorScheme) -> IntensityVisualStyle {
        let normalizedLevel = max(0, min(level, 5))

        guard normalizedLevel > 0 else {
            let neutralFill = Color.primary.opacity(colorScheme == .dark ? 0.085 : 0.058)
            let neutralBorder = Color.primary.opacity(colorScheme == .dark ? 0.115 : 0.074)
            return IntensityVisualStyle(
                level: 0,
                fill: neutralFill,
                border: neutralBorder,
                highlightOpacity: 0,
                peakScale: 1,
                peakShadowColor: .clear,
                peakShadowRadius: 0,
                peakShadowYOffset: 0
            )
        }

        let adjusted = tunedColor(baseColor: baseColor, level: normalizedLevel, colorScheme: colorScheme)
        let border = borderColor(from: adjusted, level: normalizedLevel, colorScheme: colorScheme)
        let highlight = highlightOpacity(for: normalizedLevel, colorScheme: colorScheme)
        let isPeak = normalizedLevel == 5

        return IntensityVisualStyle(
            level: normalizedLevel,
            fill: adjusted,
            border: border,
            highlightOpacity: highlight,
            peakScale: isPeak ? 1.04 : 1,
            peakShadowColor: isPeak ? adjusted.opacity(colorScheme == .dark ? 0.17 : 0.12) : .clear,
            peakShadowRadius: isPeak ? 2.0 : 0,
            peakShadowYOffset: isPeak ? 0.7 : 0
        )
    }

    static func level(for intensity: Double) -> Int {
        let clamped = min(max(intensity, 0), 1.0)
        guard clamped > 0.0001 else { return 0 }

        switch clamped {
        case ..<0.16: return 1
        case ..<0.34: return 2
        case ..<0.56: return 3
        case ..<0.78: return 4
        default: return 5
        }
    }

    private static func tunedColor(
        baseColor: Color,
        level: Int,
        colorScheme: ColorScheme,
        peakOverflow: Double = 0
    ) -> Color {
        #if canImport(UIKit)
        var adjusted = adjustedForScheme(baseColor, level: level, scheme: colorScheme)

        guard peakOverflow > 0 else {
            return adjusted
        }

        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let resolved = UIColor(adjusted).resolvedColor(with: traits)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return adjusted
        }

        let overflow = CGFloat(max(0, min(peakOverflow, 1)))
        saturation = clamp01(saturation + (colorScheme == .dark ? 0.04 : 0.03) * overflow)
        brightness = clamp01(brightness + (colorScheme == .dark ? 0.08 : 0.06) * overflow)

        adjusted = Color(
            UIColor(
                hue: hue,
                saturation: saturation,
                brightness: brightness,
                alpha: alpha
            )
        )
        return adjusted
        #else
        return baseColor.opacity(defaultOpacity(for: level, colorScheme: colorScheme))
        #endif
    }

    static func adjustedForScheme(_ color: Color, level: Int, scheme: ColorScheme) -> Color {
        #if canImport(UIKit)
        let idx = max(1, min(level, 5))
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: traits)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color.opacity(defaultOpacity(for: idx, colorScheme: scheme))
        }

        let darkBrightnessDelta: [CGFloat] = [0, -0.06, -0.03, 0.00, 0.04, 0.08]
        let lightBrightnessDelta: [CGFloat] = [0, -0.05, -0.02, 0.00, 0.02, 0.04]
        let darkSaturationScale: [CGFloat] = [0, 0.98, 1.00, 1.01, 1.02, 1.03]
        let lightSaturationScale: [CGFloat] = [0, 0.99, 1.00, 1.00, 1.01, 1.02]

        let brightnessDelta = (scheme == .dark ? darkBrightnessDelta : lightBrightnessDelta)[idx]
        let saturationScale = (scheme == .dark ? darkSaturationScale : lightSaturationScale)[idx]

        let outSaturation = clamp01(saturation * saturationScale)
        let outBrightness = clamp01(brightness + brightnessDelta)
        let outAlpha = CGFloat(defaultOpacity(for: idx, colorScheme: scheme))

        return Color(
            UIColor(
                hue: hue,
                saturation: outSaturation,
                brightness: outBrightness,
                alpha: outAlpha
            )
        )
        #else
        return color.opacity(defaultOpacity(for: max(1, min(level, 5)), colorScheme: scheme))
        #endif
    }

    private static func defaultOpacity(for level: Int, colorScheme: ColorScheme) -> Double {
        let light = [0.0, 0.62, 0.73, 0.84, 0.93, 1.0]
        let dark = [0.0, 0.68, 0.79, 0.89, 0.95, 1.0]
        return (colorScheme == .dark ? dark : light)[max(0, min(level, 5))]
    }

    private static func borderColor(
        from fill: Color,
        level: Int,
        colorScheme: ColorScheme,
        peakOverflow: Double = 0
    ) -> Color {
        let light = [0.0, 0.24, 0.32, 0.44, 0.58, 0.70]
        let dark = [0.0, 0.30, 0.40, 0.52, 0.64, 0.78]
        var opacity = (colorScheme == .dark ? dark : light)[max(0, min(level, 5))]
        if level == 5 {
            opacity += 0.08 * peakOverflow
        }
        return fill.opacity(min(opacity, 0.9))
    }

    private static func highlightOpacity(
        for level: Int,
        colorScheme: ColorScheme,
        peakOverflow: Double = 0
    ) -> Double {
        let light = [0.0, 0.20, 0.28, 0.38, 0.50, 0.62]
        let dark = [0.0, 0.14, 0.20, 0.28, 0.36, 0.48]
        var opacity = (colorScheme == .dark ? dark : light)[max(0, min(level, 5))]
        if level == 5 {
            opacity += (colorScheme == .dark ? 0.10 : 0.08) * peakOverflow
        }
        return min(opacity, colorScheme == .dark ? 0.62 : 0.74)
    }

    private static func peakOverflowFactor(for intensity: Double) -> Double {
        let overflow = max(0, intensity - 1)
        return min(overflow / 0.55, 1)
    }

    private static func clamp01(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
