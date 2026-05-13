//
//  SplashScreenContentTests.swift
//  SportBoardAppTests
//

import XCTest
@testable import SportBoardApp

final class SplashScreenContentTests: XCTestCase {
    func testSportBoardSplashContentMatchesLaunchExperience() {
        let content = SplashScreenContent.sportBoard

        XCTAssertEqual(content.title, "SportBoard")
        XCTAssertEqual(content.subtitle, "Coach adaptativo para correr mejor")
        XCTAssertEqual(content.highlights, ["READINESS", "PLAN", "RITMO"])
        XCTAssertEqual(content.minimumDisplayDuration, 2.1, accuracy: 0.001)
        XCTAssertEqual(content.minimumDisplayNanoseconds, 2_100_000_000)
        XCTAssertEqual(content.accessibilityLabel, "SportBoard. Coach adaptativo para correr mejor. READINESS, PLAN, RITMO.")
    }
}
