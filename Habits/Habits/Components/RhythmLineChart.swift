import Charts
import Foundation
import SwiftUI

struct RhythmLineChart: View {
    let data: [HourValue]
    let accent: Color
    @Binding var selectedHour: Int?
    var selectionEnabled: Bool = true
    var nowHour: Int? = nil
    var peakHour: Int? = nil
    var showNowMarker: Bool = false
    var showPeakMarker: Bool = false
    var showTrailingIncompletenessFade: Bool = false
    private let smoothingSigma: Double = 1.75
    private let peakPlateauBlend: Double = 0.18

    private var renderedData: [HourValue] {
        smoothedData(from: data, sigma: smoothingSigma, preferredPeakHour: peakHour)
    }

    private var selectedPoint: HourValue? {
        guard let selectedHour else { return nil }
        return renderedData.first(where: { $0.hour == selectedHour })
    }

    private var nowPoint: HourValue? {
        guard let nowHour else { return nil }
        return renderedData.first(where: { $0.hour == nowHour })
    }

    private var peakPoint: HourValue? {
        guard let peakHour else { return nil }
        return renderedData.first(where: { $0.hour == peakHour })
    }

    var body: some View {
        Chart {
            ForEach(renderedData) { point in
                AreaMark(
                    x: .value("Hour", point.hour),
                    yStart: .value("Baseline", 0),
                    yEnd: .value("Intensity", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            accent.opacity(0.1),
                            accent.opacity(0.025),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Hour", point.hour),
                    y: .value("Intensity", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 2.3,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .foregroundStyle(accent)
            }

            if showNowMarker, let nowPoint {
                RuleMark(x: .value("Now", nowPoint.hour))
                    .foregroundStyle(accent.opacity(0.24))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                PointMark(
                    x: .value("Now", nowPoint.hour),
                    y: .value("Now Value", nowPoint.value)
                )
                .symbolSize(26)
                .foregroundStyle(accent.opacity(0.8))
            }

            if showPeakMarker, let peakPoint {
                RuleMark(x: .value("Peak", peakPoint.hour))
                    .foregroundStyle(accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 3]))

                PointMark(
                    x: .value("Peak", peakPoint.hour),
                    y: .value("Peak Value", peakPoint.value)
                )
                .symbolSize(52)
                .foregroundStyle(accent)
            }

            if selectionEnabled, let selectedPoint {
                RuleMark(x: .value("Selected Hour", selectedPoint.hour))
                    .foregroundStyle(accent.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Selected Hour", selectedPoint.hour),
                    y: .value("Selected Value", selectedPoint.value)
                )
                .symbolSize(46)
                .foregroundStyle(accent)
            }
        }
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: [6, 12, 18]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(axisLabel(for: hour))
                            .font(CadenceTokens.Typography.microCopy)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    }
                }
                AxisTick(stroke: StrokeStyle(lineWidth: 0.6))
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.25))
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                    .foregroundStyle(.clear)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard selectionEnabled else { return }
                                guard let plotFrame = proxy.plotFrame else { return }
                                let frame = geometry[plotFrame]
                                let xPosition = value.location.x - frame.origin.x

                                guard xPosition >= 0,
                                      xPosition <= frame.width,
                                      let hourValue = proxy.value(atX: xPosition, as: Double.self) else {
                                    return
                                }

                                selectedHour = min(23, max(0, Int(hourValue.rounded())))
                            }
                            .onEnded { _ in
                                guard selectionEnabled else { return }
                                selectedHour = nil
                            }
                    )
            }
        }
        .frame(height: 130)
        .overlay(alignment: .trailing) {
            if showTrailingIncompletenessFade {
                LinearGradient(
                    colors: [
                        .clear,
                        CadenceTokens.Color.Background.primary.opacity(0.12),
                        CadenceTokens.Color.Background.primary.opacity(0.24)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 120)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            #if DEBUG
            guard let peakHour else { return }
            if renderedData.contains(where: { $0.hour == peakHour }) == false {
                print("[RhythmChart][WARNING] peakHour \(peakHour) not present in chart data")
            }
            #endif
        }
    }

    private func axisLabel(for hour: Int) -> String {
        switch hour {
        case 6:
            return "6AM"
        case 12:
            return "Noon"
        case 18:
            return "6PM"
        default:
            return "\(hour)"
        }
    }

    private func smoothedData(from source: [HourValue], sigma: Double, preferredPeakHour: Int?) -> [HourValue] {
        guard source.isEmpty == false else { return source }

        let input = (0..<24).map { hour in
            source.first(where: { $0.hour == hour })?.value ?? 0
        }

        let sigmaValue = max(0.1, sigma)
        let twoSigmaSquared = 2 * sigmaValue * sigmaValue
        var smoothed = Array(repeating: 0.0, count: 24)

        for hour in 0..<24 {
            var weightedTotal = 0.0
            var weightSum = 0.0

            for index in 0..<24 {
                let distance = wrappedHourDistance(hour, index)
                let exponent = -(Double(distance * distance)) / twoSigmaSquared
                let weight = Foundation.exp(exponent)
                weightedTotal += input[index] * weight
                weightSum += weight
            }

            smoothed[hour] = weightSum > 0 ? (weightedTotal / weightSum) : 0
        }

        let peakIndex: Int
        if let preferredPeakHour {
            peakIndex = ((preferredPeakHour % 24) + 24) % 24
        } else {
            peakIndex = smoothed.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        }

        let previous = smoothed[(peakIndex + 23) % 24]
        let next = smoothed[(peakIndex + 1) % 24]
        let neighborAverage = (previous + next) / 2.0
        smoothed[peakIndex] = (smoothed[peakIndex] * (1 - peakPlateauBlend)) + (neighborAverage * peakPlateauBlend)

        let maxValue = smoothed.max() ?? 0
        if maxValue > 0 {
            smoothed = smoothed.map { $0 / maxValue }
        }

        return (0..<24).map { hour in
            HourValue(hour: hour, value: smoothed[hour])
        }
    }

    private func wrappedHourDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let delta = abs(lhs - rhs)
        return min(delta, 24 - delta)
    }
}
