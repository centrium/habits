import SwiftUI

struct TopAmbientGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = AmbientPalette.palette(for: colorScheme)
        let ambientHeight: CGFloat = colorScheme == .dark ? 348 : 304
        let maskSolidEnd: CGFloat = colorScheme == .dark ? 0.48 : 0.4
        let maskFeatherLocation: CGFloat = colorScheme == .dark ? 0.83 : 0.78
        let maskFeatherOpacity: Double = colorScheme == .dark ? 0.74 : 0.66

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
            .blur(radius: colorScheme == .dark ? 54 : 46)

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: palette.neutralBridge.opacity(palette.neutralBridgeOpacity), location: 0.68),
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
                topTint: Color(red: 0.11, green: 0.16, blue: 0.22),
                secondaryTint: Color(red: 0.09, green: 0.19, blue: 0.24),
                radialLift: Color(red: 0.30, green: 0.40, blue: 0.49),
                linearTopOpacity: 0.18,
                linearMidOpacity: 0.10,
                linearLowOpacity: 0.045,
                linearTailOpacity: 0.018,
                secondaryTopOpacity: 0.06,
                secondaryMidOpacity: 0.026,
                neutralBridge: Color(red: 0.04, green: 0.05, blue: 0.07),
                neutralBridgeOpacity: 0.24,
                radialPeakOpacity: 0.042,
                radialSoftOpacity: 0.018
            )
        }

        return Values(
            topTint: Color(red: 0.57, green: 0.66, blue: 0.76),
            secondaryTint: Color(red: 0.54, green: 0.71, blue: 0.74),
            radialLift: Color(red: 0.81, green: 0.87, blue: 0.93),
            linearTopOpacity: 0.13,
            linearMidOpacity: 0.082,
            linearLowOpacity: 0.03,
            linearTailOpacity: 0.012,
            secondaryTopOpacity: 0.052,
            secondaryMidOpacity: 0.024,
            neutralBridge: Color(red: 0.96, green: 0.95, blue: 0.93),
            neutralBridgeOpacity: 0.18,
            radialPeakOpacity: 0.042,
            radialSoftOpacity: 0.019
        )
    }
}
