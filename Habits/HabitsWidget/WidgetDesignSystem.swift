//
//  WidgetDesignSystem.swift
//  HabitsWidget
//

import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private enum WidgetLayout {
    static let containerPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 20
    static let stackSpacing: CGFloat = 6
}

struct WidgetContainer<Content: View>: View {
    let title: String
    let trailingValue: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetLayout.stackSpacing) {
            WidgetHeader(title: title, trailingValue: trailingValue)

            Spacer(minLength: 4)

            content

            Spacer(minLength: 0)
        }
        .padding(WidgetLayout.containerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: WidgetLayout.cornerRadius)
                .fill(Color.clear)
        )
    }
}

struct WidgetHeader: View {
    let title: String
    let trailingValue: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.systemAccent)
                .lineLimit(1)

            Spacer()

            if let trailingValue, !trailingValue.isEmpty {
                Text(trailingValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

struct TodayRow: View {
    let name: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                .background {
                    if isCompleted {
                        Circle().fill(Color.primary.opacity(0.16))
                    }
                }
                .frame(width: 16, height: 16)

            Text(name)
                .font(.system(size: 15))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .opacity(isCompleted ? 0.5 : 1.0)
    }
}

struct MicroGraph: View {
    let days: [WidgetHeatmapDay]

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days, id: \.date) { day in
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(fillOpacity(for: day.intensity)))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight(for: day.intensity), alignment: .bottom)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .bottomLeading)
        .accessibilityLabel("Last 7 days activity")
    }

    private func barHeight(for intensity: Int) -> CGFloat {
        switch intensity {
        case 1:
            return 7
        case 2:
            return 11
        case 3:
            return 16
        case 4...:
            return 22
        default:
            return 4
        }
    }

    private func fillOpacity(for intensity: Int) -> Double {
        switch intensity {
        case 1:
            return 0.25
        case 2:
            return 0.40
        case 3:
            return 0.58
        case 4...:
            return 0.78
        default:
            return 0.12
        }
    }
}

private struct WidgetSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            content
        }
    }
}

extension View {
    func widgetSurface() -> some View {
        modifier(WidgetSurfaceModifier())
    }
}

extension WidgetHabit {
    var deepLinkURL: URL {
        URL(string: "habits://habit/\(id.uuidString)")!
    }
}

extension Color {
    static let systemAccent = Color.dynamic(
        lightHex: CadenceColorPalette.light(for: .cobalt).strong,
        darkHex: CadenceColorPalette.dark(for: .cobalt).strong
    )
}

private extension Color {
    static func dynamic(lightHex: String, darkHex: String) -> Color {
        #if canImport(UIKit)
        return Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
            }
        )
        #elseif canImport(AppKit)
        let dynamic = NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: match == .darkAqua ? darkHex : lightHex)
        } ?? NSColor(hex: lightHex)
        return Color(dynamic)
        #else
        return colorFromHex(lightHex)
        #endif
    }

    static func colorFromHex(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 255) / 255
        let g = Double((value >> 8) & 255) / 255
        let b = Double(value & 255) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 255) / 255
        let g = CGFloat((int >> 8) & 255) / 255
        let b = CGFloat(int & 255) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 255) / 255
        let g = CGFloat((int >> 8) & 255) / 255
        let b = CGFloat(int & 255) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif
