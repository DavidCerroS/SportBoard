//
//  SportBoardThemeTests.swift
//  SportBoardAppTests
//

import XCTest
@testable import SportBoardApp

final class SportBoardThemeTests: XCTestCase {
    func testPremiumTokenContractKeepsLargeTouchableSurfaces() {
        XCTAssertGreaterThanOrEqual(SportBoardTheme.Radius.medium, 16)
        XCTAssertGreaterThanOrEqual(SportBoardTheme.Radius.card, 22)
        XCTAssertGreaterThanOrEqual(SportBoardTheme.Spacing.screen, 20)
        XCTAssertGreaterThanOrEqual(SportBoardTheme.Spacing.card, 16)
    }
}
