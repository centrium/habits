import SwiftUI

struct HabitColorVariants {
    let base: Color
    let accent: Color
    let soft: Color
}

enum HabitColor: String, CaseIterable, Identifiable {
    case fern = "#59BE67"
    case sage = "#76B987"
    case cobalt = "#4B7FDF"
    case sky = "#4E9DDF"
    case iris = "#7E68D8"
    case amethyst = "#9B72D3"
    case apricot = "#D88F45"
    case amber = "#C99A3F"
    case coral = "#CD6A67"
    case rose = "#C15D82"
    case teal = "#48B0A2"
    case cyan = "#4DB3C5"

    var id: String { rawValue }
    var hex: String { rawValue }

    var name: String {
        switch self {
        case .fern: return "Fern"
        case .sage: return "Sage"
        case .cobalt: return "Cobalt"
        case .sky: return "Sky"
        case .iris: return "Iris"
        case .amethyst: return "Amethyst"
        case .apricot: return "Apricot"
        case .amber: return "Amber"
        case .coral: return "Coral"
        case .rose: return "Rose"
        case .teal: return "Teal"
        case .cyan: return "Cyan"
        }
    }

    var color: Color {
        Color(hex: rawValue)
    }

    var variants: HabitColorVariants {
        return HabitColorVariants(
            base: color,
            accent: Color(hex: accentHex),
            soft: Color(hex: softHex).opacity(softOpacity)
        )
    }

    static let `default`: HabitColor = .iris

    static func from(hex: String) -> HabitColor {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return allCases.first { $0.rawValue == normalized } ?? .default
    }

    var accentHex: String {
        switch self {
        case .fern: return "#60C96F"
        case .sage: return "#7FC590"
        case .cobalt: return "#568CEB"
        case .sky: return "#5AAAE9"
        case .iris: return "#8A73E4"
        case .amethyst: return "#A77FDE"
        case .apricot: return "#E59A4F"
        case .amber: return "#D7A64A"
        case .coral: return "#DA7673"
        case .rose: return "#CD688D"
        case .teal: return "#52BCAD"
        case .cyan: return "#58BFD0"
        }
    }

    var softHex: String {
        switch self {
        case .fern: return "#5FA86A"
        case .sage: return "#7AA88A"
        case .cobalt: return "#5A83C6"
        case .sky: return "#5A99C7"
        case .iris: return "#8774C2"
        case .amethyst: return "#9B7DBF"
        case .apricot: return "#C48B55"
        case .amber: return "#B69352"
        case .coral: return "#B86E6C"
        case .rose: return "#AD6481"
        case .teal: return "#57A094"
        case .cyan: return "#5AABBA"
        }
    }

    var softOpacity: Double {
        0.78
    }
}

extension Habit {
    var curatedColor: HabitColor {
        HabitColor.from(hex: colorHex)
    }

    var curatedAccentColor: Color {
        curatedColor.color
    }

    var curatedColorVariants: HabitColorVariants {
        curatedColor.variants
    }
}
