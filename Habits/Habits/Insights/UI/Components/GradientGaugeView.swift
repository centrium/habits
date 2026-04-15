import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GradientGaugeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: Double
    let labels: [String]
    var emphasizeActiveZone: Bool = false
    var activeBandLabel: String? = nil

    @State private var displayedValue = 0.0
    @State private var isActiveMarker = false

    private let barHeight: CGFloat = 12
    private let indicatorSize: CGFloat = 11.4
    private let markerStrokeWidth: CGFloat = 1.6
    private let markerHaloScale: CGFloat = 1.75
    private let markerShadowRadius: CGFloat = 4

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var targetSoftMarkerValue: Double {
        softMarkerValue(for: clampedValue)
    }

    private var activeLabelIndex: Int? {
        if emphasizeActiveZone,
           let activeBandLabel,
           let explicit = labels.firstIndex(of: activeBandLabel) {
            return explicit
        }
        guard labels.count > 1 else { return nil }
        let raw = Int(round(targetSoftMarkerValue * Double(labels.count - 1)))
        return min(max(raw, 0), labels.count - 1)
    }

    private var dividerPositions: [Double] {
        if emphasizeActiveZone, labels.count == 6 {
            return [0.20, 0.40, 0.60, 0.75, 0.90]
        }
        guard labels.count > 1 else { return [] }
        return (1..<labels.count).map { Double($0) / Double(labels.count) }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                HabitColor.cobalt.variants.strong.opacity(colorScheme == .dark ? 0.82 : 0.66),
                HabitColor.teal.variants.strong.opacity(colorScheme == .dark ? 0.82 : 0.66),
                HabitColor.amber.variants.strong.opacity(colorScheme == .dark ? 0.8 : 0.64),
                HabitColor.coral.variants.strong.opacity(colorScheme == .dark ? 0.8 : 0.64)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let renderedValue = renderedMarkerValue(for: displayedValue, width: width)
                let indicatorX = indicatorPosition(in: width, markerValue: renderedValue)

                ZStack(alignment: .topLeading) {
                    bar(width: width)
                        .offset(y: indicatorSize + 6)

                    Circle()
                        .fill(markerColor(for: renderedValue))
                        .overlay {
                            Circle()
                                .fill(markerColor(for: renderedValue).opacity(colorScheme == .dark ? 0.14 : 0.1))
                                .scaleEffect(markerHaloScale)
                        }
                        .frame(width: indicatorSize, height: indicatorSize)
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.white.opacity(colorScheme == .dark ? 0.9 : 0.72),
                                    lineWidth: markerStrokeWidth
                                )
                        )
                        .overlay {
                            Circle()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.92 : 0.8))
                                .frame(width: 2.8, height: 2.8)
                        }
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.56 : 0.2),
                            radius: 2,
                            y: 1
                        )
                        .shadow(
                            color: markerColor(for: renderedValue).opacity(colorScheme == .dark ? 0.12 : 0.08),
                            radius: markerShadowRadius,
                            y: 1
                        )
                        .scaleEffect(isActiveMarker ? 1.1 : 1.0)
                        .offset(x: indicatorX - (indicatorSize / 2))
                }
            }
            .frame(height: indicatorSize + barHeight + 14)

            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .opacity(labelOpacity(for: index))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
        }
        .onAppear {
            displayedValue = 0
            isActiveMarker = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.2)) {
                displayedValue = targetSoftMarkerValue
                isActiveMarker = true
            }
        }
        .onChange(of: clampedValue) { _, newValue in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.2)) {
                displayedValue = softMarkerValue(for: newValue)
            }
        }
    }

    @ViewBuilder
    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
            .fill(gradient)
            .frame(height: barHeight)
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    ForEach(Array(dividerPositions.enumerated()), id: \.offset) { index, divider in
                        let isNearestTick = activeLabelIndex == (index + 1) || activeLabelIndex == index
                        Rectangle()
                            .fill(
                                Color.primary.opacity(
                                    emphasizeActiveZone && isNearestTick
                                        ? (colorScheme == .dark ? 0.5 : 0.2)
                                        : (colorScheme == .dark ? 0.38 : 0.14)
                                )
                            )
                            .frame(width: 1, height: barHeight + 4)
                            .offset(x: (width * CGFloat(divider)) - 0.5)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.08))
            }
            .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04), radius: 8, y: 3)
    }

    private func indicatorPosition(in width: CGFloat, markerValue: Double) -> CGFloat {
        let rawPosition = CGFloat(markerValue) * width
        return min(max(rawPosition, indicatorSize / 2), width - (indicatorSize / 2))
    }

    private func softMarkerValue(for raw: Double) -> Double {
        guard emphasizeActiveZone, let band = resolvedIdentityBand(for: raw) else {
            return min(max(raw, 0), 1)
        }

        let clamped = min(max(raw, 0), 1)
        let centerAttraction: Double = activeBandLabel == nil ? 0.20 : 0.28
        var softened = clamped + ((band.center - clamped) * centerAttraction)
        softened = min(max(softened, band.lower), band.upper)

        if activeBandLabel != nil {
            // Keep state markers optically central so Steady/Strong do not feel ambiguous.
            let clarityInset = band.span * 0.30
            let clarityMin = band.lower + clarityInset
            let clarityMax = band.upper - clarityInset
            if clarityMin < clarityMax {
                softened = min(max(softened, clarityMin), clarityMax)
            }
        }

        return softened
    }

    private func renderedMarkerValue(for softValue: Double, width: CGFloat) -> Double {
        guard emphasizeActiveZone, let band = resolvedIdentityBand(for: softValue) else {
            return min(max(softValue, 0), 1)
        }

        let safeInset = max(markerVisibleRadiusNormalized(width: width) + 0.01, 0.02)
        var safeBandMin = band.lower + safeInset
        var safeBandMax = band.upper - safeInset

        if safeBandMin > safeBandMax {
            let center = band.center
            safeBandMin = center
            safeBandMax = center
        }

        var rendered = min(max(softValue, safeBandMin), safeBandMax)

        if band.kind != .rebuild {
            let rightInwardBias = band.kind == .strong ? 0.015 : 0.004
            rendered = min(rendered, safeBandMax - rightInwardBias)
            rendered = max(rendered, safeBandMin)
        }

        #if DEBUG
        debugValidateMarkerContainment(
            width: width,
            band: band,
            markerCenter: rendered,
            safeBandMin: safeBandMin,
            safeBandMax: safeBandMax
        )
        #endif

        return min(max(rendered, 0), 1)
    }

    private func markerVisibleRadiusNormalized(width: CGFloat) -> Double {
        let baseRadius = indicatorSize / 2
        let strokeRadius = baseRadius + (markerStrokeWidth / 2)
        let haloRadius = baseRadius * markerHaloScale
        let visibleRadius = max(strokeRadius, haloRadius) + markerShadowRadius + 0.5
        return Double(visibleRadius / max(width, 1))
    }

    private func markerColor(for normalized: Double) -> Color {
        let stops = [
            HabitColor.cobalt.variants.strong,
            HabitColor.teal.variants.strong,
            HabitColor.amber.variants.strong,
            HabitColor.coral.variants.strong
        ]

        #if canImport(UIKit)
        let position = min(max(normalized, 0), 1)
        let scaled = position * Double(stops.count - 1)
        let lowerIndex = Int(floor(scaled))
        let upperIndex = min(lowerIndex + 1, stops.count - 1)
        let t = CGFloat(scaled - Double(lowerIndex))

        let lower = UIColor(stops[lowerIndex])
        let upper = UIColor(stops[upperIndex])

        var lr: CGFloat = 0
        var lg: CGFloat = 0
        var lb: CGFloat = 0
        var la: CGFloat = 0
        var ur: CGFloat = 0
        var ug: CGFloat = 0
        var ub: CGFloat = 0
        var ua: CGFloat = 0

        guard lower.getRed(&lr, green: &lg, blue: &lb, alpha: &la),
              upper.getRed(&ur, green: &ug, blue: &ub, alpha: &ua) else {
            let fallback = min(max(Int(round(position * Double(stops.count - 1))), 0), stops.count - 1)
            return stops[fallback]
        }

        return Color(
            red: Double(lr + ((ur - lr) * t)),
            green: Double(lg + ((ug - lg) * t)),
            blue: Double(lb + ((ub - lb) * t))
        )
        #else
        let index = min(max(Int(round(normalized * Double(stops.count - 1))), 0), stops.count - 1)
        return stops[index]
        #endif
    }

    private func labelOpacity(for index: Int) -> Double {
        guard emphasizeActiveZone, let active = activeLabelIndex else {
            return 1
        }
        let distance = abs(index - active)
        if distance == 0 {
            return 1
        }
        if distance == 1 {
            return 0.68
        }
        return 0.45
    }

    private func resolvedIdentityBand(for value: Double) -> IdentityBand? {
        if let activeBandLabel,
           let byLabel = identityBand(forLabel: activeBandLabel) {
            return byLabel
        }
        return identityBand(for: value)
    }

    private func identityBand(forLabel label: String) -> IdentityBand? {
        switch label {
        case "Start":
            return IdentityBand(kind: .start, lower: 0.00, upper: 0.20)
        case "Build":
            return IdentityBand(kind: .build, lower: 0.20, upper: 0.40)
        case "Steady":
            return IdentityBand(kind: .steady, lower: 0.40, upper: 0.60)
        case "Strong":
            return IdentityBand(kind: .strong, lower: 0.60, upper: 0.75)
        case "Slip":
            return IdentityBand(kind: .slip, lower: 0.75, upper: 0.90)
        case "Rebuild":
            return IdentityBand(kind: .rebuild, lower: 0.90, upper: 1.00)
        default:
            return nil
        }
    }

    private func identityBand(for value: Double) -> IdentityBand {
        switch value {
        case ..<0.20:
            return IdentityBand(kind: .start, lower: 0.00, upper: 0.20)
        case ..<0.40:
            return IdentityBand(kind: .build, lower: 0.20, upper: 0.40)
        case ..<0.60:
            return IdentityBand(kind: .steady, lower: 0.40, upper: 0.60)
        case ..<0.75:
            return IdentityBand(kind: .strong, lower: 0.60, upper: 0.75)
        case ..<0.90:
            return IdentityBand(kind: .slip, lower: 0.75, upper: 0.90)
        default:
            return IdentityBand(kind: .rebuild, lower: 0.90, upper: 1.00)
        }
    }

    #if DEBUG
    private func debugValidateMarkerContainment(
        width: CGFloat,
        band: IdentityBand,
        markerCenter: Double,
        safeBandMin: Double,
        safeBandMax: Double
    ) {
        let visibleRadius = markerVisibleRadiusNormalized(width: width)
        let visibleMin = markerCenter - visibleRadius
        let visibleMax = markerCenter + visibleRadius
        let strongSlipDivider = 0.75
        let canFitInsideBand = (visibleRadius * 2) <= (band.upper - band.lower)

        guard canFitInsideBand else {
            print(
                "[SignalMarker] containment_skipped band=\(band.label) " +
                    "width=\(format(band.upper - band.lower)) required=\(format(visibleRadius * 2))"
            )
            return
        }

        let contained = visibleMin >= band.lower && visibleMax <= band.upper
        let strongContained = band.kind != .strong || visibleMax < strongSlipDivider

        if !(contained && strongContained) {
            print(
                "[SignalMarker] band=\(band.label) divider=[\(format(band.lower)),\(format(band.upper))] " +
                    "safe=[\(format(safeBandMin)),\(format(safeBandMax))] " +
                    "center=\(format(markerCenter)) visible=[\(format(visibleMin)),\(format(visibleMax))]"
            )
            assertionFailure("Marker footprint crossed band boundary")
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
    #endif

    private struct IdentityBand {
        enum Kind {
            case start
            case build
            case steady
            case strong
            case slip
            case rebuild
        }

        let kind: Kind
        let lower: Double
        let upper: Double

        var center: Double {
            (lower + upper) / 2
        }

        var span: Double {
            upper - lower
        }

        var label: String {
            switch kind {
            case .start:
                return "Start"
            case .build:
                return "Build"
            case .steady:
                return "Steady"
            case .strong:
                return "Strong"
            case .slip:
                return "Slip"
            case .rebuild:
                return "Rebuild"
            }
        }
    }
}
