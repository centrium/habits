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
    var calibrationProfile: SignalMarkerCalibration.Profile = .none

    @State private var displayedValue = 0.0
    @State private var isActiveMarker = false

    private let barHeight: CGFloat = 12
    private let indicatorSize: CGFloat = 11.4
    private let markerStrokeWidth: CGFloat = 1.6
    private let markerHaloScale: CGFloat = 1.75
    private let markerShadowRadius: CGFloat = 4
    private let activeMarkerScale: CGFloat = 1.1

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var targetSoftMarkerValue: Double {
        clampedValue
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
        calibrationProfile.dividerPositions(labelCount: labels.count)
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
                        .scaleEffect(isActiveMarker ? activeMarkerScale : 1.0)
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
                displayedValue = min(max(newValue, 0), 1)
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

    private func renderedMarkerValue(for rawValue: Double, width: CGFloat) -> Double {
        let safeInset = max(markerVisibleRadiusNormalized(width: width) + 0.01, 0.02)
        guard let calibration = SignalMarkerCalibration.calibrate(
            rawPosition: rawValue,
            labels: labels,
            activeBandLabel: activeBandLabel,
            safeInset: safeInset,
            profile: calibrationProfile
        ) else {
            return min(max(rawValue, 0), 1)
        }

        #if DEBUG
        debugValidateMarkerContainment(
            calibration,
            width: width
        )
        #endif

        return min(max(calibration.adjustedPosition, 0), 1)
    }

    private func markerVisibleRadiusNormalized(width: CGFloat) -> Double {
        let baseRadius = (indicatorSize * activeMarkerScale) / 2
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

    #if DEBUG
    private func debugValidateMarkerContainment(
        _ calibration: SignalMarkerCalibration.Result,
        width: CGFloat
    ) {
        let visibleRadius = markerVisibleRadiusNormalized(width: width)
        let canFitInsideBand = (visibleRadius * 2) <= calibration.activeBand.span

        guard canFitInsideBand else {
            print(
                "[SignalMarker] containment_skipped profile=\(calibration.profile.name) " +
                    "band=\(calibration.activeBand.label) width=\(format(calibration.activeBand.span)) " +
                    "required=\(format(visibleRadius * 2))"
            )
            return
        }

        let contained = calibration.visibleMin >= calibration.activeBand.lower &&
            calibration.visibleMax <= calibration.activeBand.upper

        if !contained {
            print(
                "[SignalMarker] containment_failure profile=\(calibration.profile.name) " +
                    "band=\(calibration.activeBand.label) divider=[\(format(calibration.activeBand.lower)),\(format(calibration.activeBand.upper))] " +
                    "safe=[\(format(calibration.safeBandMin)),\(format(calibration.safeBandMax))] " +
                    "raw=\(format(calibration.rawPosition)) adjusted=\(format(calibration.adjustedPosition)) " +
                    "nearestDividerDistance=\(format(calibration.nearestDividerDistance)) " +
                    "bias=\(format(calibration.biasStrength)) visible=[\(format(calibration.visibleMin)),\(format(calibration.visibleMax))]"
            )
            assertionFailure("Marker footprint crossed band boundary")
        }

        if ProcessInfo.processInfo.environment["HABITS_DEBUG_SIGNAL_MARKERS"] == "1" {
            print(
                "[SignalMarker] profile=\(calibration.profile.name) band=\(calibration.activeBand.label) " +
                    "raw=\(format(calibration.rawPosition)) adjusted=\(format(calibration.adjustedPosition)) " +
                    "nearestDividerDistance=\(format(calibration.nearestDividerDistance)) " +
                    "bias=\(format(calibration.biasStrength)) " +
                    "safe=[\(format(calibration.safeBandMin)),\(format(calibration.safeBandMax))] " +
                    "visible=[\(format(calibration.visibleMin)),\(format(calibration.visibleMax))]"
            )
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
    #endif

}

struct SignalMarkerCalibration {
    enum Profile: Equatable {
        case none
        case identity
        case risk
        case strength

        var name: String {
            switch self {
            case .none:
                return "none"
            case .identity:
                return "identity"
            case .risk:
                return "risk"
            case .strength:
                return "strength"
            }
        }

        func dividerPositions(labelCount: Int) -> [Double] {
            switch self {
            case .identity:
                return [0.20, 0.40, 0.60, 0.75, 0.90]
            case .none, .risk, .strength:
                guard labelCount > 1 else { return [] }
                return (1..<labelCount).map { Double($0) / Double(labelCount) }
            }
        }
    }

    struct Band: Equatable {
        let index: Int
        let label: String
        let lower: Double
        let upper: Double

        var center: Double { (lower + upper) / 2 }
        var span: Double { upper - lower }
        var isFirst: Bool { index == 0 }
        var isLast: Bool { upper >= 1 }
    }

    struct Result: Equatable {
        let profile: Profile
        let activeBand: Band
        let rawPosition: Double
        let adjustedPosition: Double
        let nearestDividerDistance: Double
        let biasStrength: Double
        let safeBandMin: Double
        let safeBandMax: Double
        let visibleMin: Double
        let visibleMax: Double
    }

    static func calibrate(
        rawPosition: Double,
        labels: [String],
        activeBandLabel: String?,
        safeInset: Double,
        profile: Profile
    ) -> Result? {
        guard profile != .none else { return nil }
        let bands = makeBands(labels: labels, profile: profile)
        guard !bands.isEmpty else { return nil }

        let raw = clamp(rawPosition, lower: 0, upper: 1)
        guard let band = resolveBand(for: raw, activeBandLabel: activeBandLabel, bands: bands) else {
            return nil
        }

        let safeBounds = safeBounds(for: band, safeInset: safeInset)
        let edgeDistance = max(min(raw - band.lower, band.upper - raw), 0)
        let centerDistance = band.span / 2
        let proximityToDivider = 1 - clamp(edgeDistance / max(centerDistance, 0.0001), lower: 0, upper: 1)
        let terminalOuterEdgeProximity: Double = {
            if band.isFirst {
                return 1 - clamp((raw - band.lower) / max(band.span, 0.0001), lower: 0, upper: 1)
            }
            if band.isLast {
                return 1 - clamp((band.upper - raw) / max(band.span, 0.0001), lower: 0, upper: 1)
            }
            return 0
        }()
        let adaptiveBias = clamp(
            0.12 + (0.08 * proximityToDivider) + (0.02 * terminalOuterEdgeProximity),
            lower: 0.12,
            upper: 0.22
        )
        let softCenteredPosition = raw + ((band.center - raw) * adaptiveBias)
        let adjusted = clamp(softCenteredPosition, lower: safeBounds.min, upper: safeBounds.max)

        return Result(
            profile: profile,
            activeBand: band,
            rawPosition: raw,
            adjustedPosition: adjusted,
            nearestDividerDistance: edgeDistance,
            biasStrength: adaptiveBias,
            safeBandMin: safeBounds.min,
            safeBandMax: safeBounds.max,
            visibleMin: adjusted - safeInset,
            visibleMax: adjusted + safeInset
        )
    }

    static func makeBands(labels: [String], profile: Profile) -> [Band] {
        let dividers = profile.dividerPositions(labelCount: labels.count)
        guard labels.count >= 2, dividers.count == labels.count - 1 else { return [] }

        var lower = 0.0
        return labels.enumerated().map { index, label in
            let upper = index < dividers.count ? dividers[index] : 1.0
            defer { lower = upper }
            return Band(index: index, label: label, lower: lower, upper: upper)
        }
    }

    private static func resolveBand(
        for rawPosition: Double,
        activeBandLabel: String?,
        bands: [Band]
    ) -> Band? {
        if let activeBandLabel,
           let explicit = bands.first(where: { $0.label == activeBandLabel }) {
            return explicit
        }

        return bands.first(where: { rawPosition < $0.upper || $0.isLast })
    }

    private static func safeBounds(for band: Band, safeInset: Double) -> (min: Double, max: Double) {
        var safeBandMin = band.lower + safeInset
        var safeBandMax = band.upper - safeInset

        if safeBandMin > safeBandMax {
            safeBandMin = band.center
            safeBandMax = band.center
        }

        return (safeBandMin, safeBandMax)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
