import SwiftUI

struct TopAmbientGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = AmbientPalette.palette(for: colorScheme)
        let ambientHeight: CGFloat = colorScheme == .dark ? 376 : 332
        let maskSolidEnd: CGFloat = colorScheme == .dark ? 0.52 : 0.45
        let maskFeatherLocation: CGFloat = colorScheme == .dark ? 0.89 : 0.85
        let maskFeatherOpacity: Double = colorScheme == .dark ? 0.8 : 0.72

        return ZStack(alignment: .top) {
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
                endRadius: 270
            )
            .offset(y: 46)
            .blur(radius: colorScheme == .dark ? 58 : 50)

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
                topTint: Color(red: 0.115, green: 0.166, blue: 0.228),
                secondaryTint: Color(red: 0.092, green: 0.196, blue: 0.248),
                radialLift: Color(red: 0.30, green: 0.40, blue: 0.49),
                linearTopOpacity: 0.194,
                linearMidOpacity: 0.108,
                linearLowOpacity: 0.05,
                linearTailOpacity: 0.021,
                secondaryTopOpacity: 0.066,
                secondaryMidOpacity: 0.029,
                neutralBridge: Color(red: 0.04, green: 0.05, blue: 0.07),
                neutralBridgeOpacity: 0.2,
                radialPeakOpacity: 0.046,
                radialSoftOpacity: 0.02
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
