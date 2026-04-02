import SwiftUI

enum HabitColor: String, CaseIterable, Identifiable {
    case fern = "#65C874"
    case sage = "#89C296"
    case cobalt = "#5689EB"
    case sky = "#5DA8EA"
    case iris = "#8B74E2"
    case amethyst = "#A87FDE"
    case apricot = "#E39B58"
    case amber = "#D7AA4F"
    case coral = "#D87976"
    case rose = "#CC6A8A"
    case teal = "#56BBAD"
    case cyan = "#59BFD0"

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

    static let `default`: HabitColor = .iris

    static func from(hex: String) -> HabitColor {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return allCases.first { $0.rawValue == normalized } ?? .default
    }
}

extension Habit {
    var curatedColor: HabitColor {
        HabitColor.from(hex: colorHex)
    }

    var curatedAccentColor: Color {
        curatedColor.color
    }
}
