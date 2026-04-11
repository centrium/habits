import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CadenceInk {
    static func ink(
        for base: Color,
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
            let newBrightness = max(0.12, b - (0.35 + (intensity * 0.25)))
            let newSaturation = min(1.0, s * 0.9)

            return Color(
                UIColor(
                    hue: h,
                    saturation: newSaturation,
                    brightness: newBrightness,
                    alpha: 1
                )
            )

        case .dark:
            let newBrightness = min(0.95, b + (0.35 + (intensity * 0.25)))
            let newSaturation = max(0.6, s * 0.85)

            return Color(
                UIColor(
                    hue: h,
                    saturation: newSaturation,
                    brightness: newBrightness,
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
}
