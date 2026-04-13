import Charts
import SwiftUI

struct RhythmLineChart: View {
    let data: [HourValue]
    let accent: Color
    @Binding var selectedHour: Int?
    var selectionEnabled: Bool = true
    var nowHour: Int? = nil
    var showNowMarker: Bool = false
    var showTrailingIncompletenessFade: Bool = false

    private var selectedPoint: HourValue? {
        guard let selectedHour else { return nil }
        return data.first(where: { $0.hour == selectedHour })
    }

    private var nowPoint: HourValue? {
        guard let nowHour else { return nil }
        return data.first(where: { $0.hour == nowHour })
    }

    var body: some View {
        Chart {
            ForEach(data) { point in
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
                                let frame = geometry[proxy.plotAreaFrame]
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
    }

    private func axisLabel(for hour: Int) -> String {
        switch hour {
        case 6:
            return "6am"
        case 12:
            return "12pm"
        case 18:
            return "6pm"
        default:
            return "\(hour)"
        }
    }
}
