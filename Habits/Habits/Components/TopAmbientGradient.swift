import SwiftUI

struct TopAmbientGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = AmbientPalette.palette(for: colorScheme)
        let ambientHeight: CGFloat = colorScheme == .dark ? 428 : 332
        let maskSolidEnd: CGFloat = colorScheme == .dark ? 0.52 : 0.45
        let maskFeatherLocation: CGFloat = colorScheme == .dark ? 0.89 : 0.85
        let maskFeatherOpacity: Double = colorScheme == .dark ? 0.8 : 0.72

        return ZStack(alignment: .top) {
            if colorScheme == .dark {
                // Dark mode uses two soft, asymmetrical edge-biased zones.
                // This avoids a full-screen haze and keeps cards/text visually dominant.
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.032), location: 0.0),
                        .init(color: Color.white.opacity(0.016), location: 0.24),
                        .init(color: .clear, location: 0.72)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: palette.topTint.opacity(0.088), location: 0.0),
                        .init(color: palette.topTint.opacity(0.054), location: 0.42),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: .topLeading,
                    startRadius: 72,
                    endRadius: 640
                )
                .offset(x: -236, y: -212)
                .blur(radius: 198)

                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: palette.secondaryTint.opacity(0.058), location: 0.0),
                        .init(color: palette.secondaryTint.opacity(0.034), location: 0.44),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: UnitPoint(x: 0.98, y: 0.78),
                    startRadius: 64,
                    endRadius: 620
                )
                .offset(x: 148, y: 166)
                .blur(radius: 186)
            } else {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: palette.topTint.opacity(palette.linearTopOpacity), location: 0.0),
                        .init(color: palette.topTint.opacity(palette.linearMidOpacity), location: 0.16),
                        .init(color: palette.topTint.opacity(palette.linearLowOpacity), location: 0.36),
                        .init(color: palette.topTint.opacity(palette.linearTailOpacity), location: 0.67),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: palette.secondaryTint.opacity(palette.secondaryTopOpacity), location: 0.0),
                        .init(color: palette.secondaryTint.opacity(palette.secondaryMidOpacity), location: 0.24),
                        .init(color: .clear, location: 0.76)
                    ]),
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: palette.radialLift.opacity(palette.radialPeakOpacity), location: 0.0),
                        .init(color: palette.radialLift.opacity(palette.radialSoftOpacity), location: 0.42),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: .top,
                    startRadius: 12,
                    endRadius: 340
                )
                .offset(y: 46)
                .blur(radius: 50)

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: palette.neutralBridge.opacity(palette.neutralBridgeOpacity), location: 0.74),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: ambientHeight, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white, location: maskSolidEnd),
                    .init(color: .white.opacity(maskFeatherOpacity), location: maskFeatherLocation),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowsHitTesting(false)
    }
}

private enum AmbientPalette {
    struct Values {
        let topTint: Color
        let secondaryTint: Color
        let radialLift: Color
        let linearTopOpacity: Double
        let linearMidOpacity: Double
        let linearLowOpacity: Double
        let linearTailOpacity: Double
        let secondaryTopOpacity: Double
        let secondaryMidOpacity: Double
        let neutralBridge: Color
        let neutralBridgeOpacity: Double
        let radialPeakOpacity: Double
        let radialSoftOpacity: Double
    }

    static func palette(for colorScheme: ColorScheme) -> Values {
        if colorScheme == .dark {
            return Values(
                topTint: Color(red: 0.15, green: 0.18, blue: 0.22),
                secondaryTint: Color(red: 0.14, green: 0.20, blue: 0.23),
                radialLift: Color(red: 0.30, green: 0.40, blue: 0.49),
                linearTopOpacity: 0.22,
                linearMidOpacity: 0.128,
                linearLowOpacity: 0.068,
                linearTailOpacity: 0.036,
                secondaryTopOpacity: 0.088,
                secondaryMidOpacity: 0.046,
                neutralBridge: Color(red: 0.04, green: 0.05, blue: 0.07),
                neutralBridgeOpacity: 0.28,
                radialPeakOpacity: 0.076,
                radialSoftOpacity: 0.041
            )
        }

        return Values(
            topTint: Color(red: 0.58, green: 0.67, blue: 0.77),
            secondaryTint: Color(red: 0.546, green: 0.716, blue: 0.746),
            radialLift: Color(red: 0.81, green: 0.87, blue: 0.93),
            linearTopOpacity: 0.138,
            linearMidOpacity: 0.09,
            linearLowOpacity: 0.034,
            linearTailOpacity: 0.015,
            secondaryTopOpacity: 0.056,
            secondaryMidOpacity: 0.026,
            neutralBridge: Color(red: 0.96, green: 0.95, blue: 0.93),
            neutralBridgeOpacity: 0.16,
            radialPeakOpacity: 0.046,
            radialSoftOpacity: 0.021
        )
    }
}
