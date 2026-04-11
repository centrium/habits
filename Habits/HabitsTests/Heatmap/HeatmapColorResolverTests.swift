import SwiftUI
import XCTest
@testable import Habits

final class HeatmapColorResolverTests: XCTestCase {
    func testZeroStateUsesFixedNeutralHexes() {
        XCTAssertEqual(
            HeatmapColorResolver.hex(for: 0, habitColor: .teal, scheme: .light),
            "#E8EBEE"
        )
        XCTAssertEqual(
            HeatmapColorResolver.hex(for: 0, habitColor: .teal, scheme: .dark),
            "#2A2D31"
        )
    }

    func testIntensityThresholdsRemainUnchanged() {
        let light = CadenceColorPalette.heatmapLight(for: HabitColor.teal.paletteToken)

        XCTAssertEqual(HeatmapColorResolver.hex(for: 0, habitColor: .teal, scheme: .light), "#E8EBEE")
        XCTAssertEqual(HeatmapColorResolver.hex(for: 1, habitColor: .teal, scheme: .light), light.scale1)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 2, habitColor: .teal, scheme: .light), light.scale2)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 3, habitColor: .teal, scheme: .light), light.scale3)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 4, habitColor: .teal, scheme: .light), light.scale4)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 5, habitColor: .teal, scheme: .light), light.scale5)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 9, habitColor: .teal, scheme: .light), light.scale5)
    }

    func testOneThreeAndFiveLogsMapToSinglePaletteInBothSchemes() {
        let light = CadenceColorPalette.heatmapLight(for: HabitColor.cobalt.paletteToken)
        let dark = CadenceColorPalette.heatmapDark(for: HabitColor.cobalt.paletteToken)

        XCTAssertEqual(HeatmapColorResolver.hex(for: 1, habitColor: .cobalt, scheme: .light), light.scale1)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 3, habitColor: .cobalt, scheme: .light), light.scale3)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 5, habitColor: .cobalt, scheme: .light), light.scale5)

        XCTAssertEqual(HeatmapColorResolver.hex(for: 1, habitColor: .cobalt, scheme: .dark), dark.scale1)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 3, habitColor: .cobalt, scheme: .dark), dark.scale3)
        XCTAssertEqual(HeatmapColorResolver.hex(for: 5, habitColor: .cobalt, scheme: .dark), dark.scale5)
    }
}
