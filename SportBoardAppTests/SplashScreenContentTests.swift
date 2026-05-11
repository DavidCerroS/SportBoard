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
        XCTAssertEqual(content.subtitle, "Tu motor de entrenamiento")
        XCTAssertEqual(content.highlights, ["RITMO", "CARGA", "PROGRESO"])
        XCTAssertEqual(content.minimumDisplayDuration, 1.9, accuracy: 0.001)
        XCTAssertEqual(content.minimumDisplayNanoseconds, 1_900_000_000)
        XCTAssertEqual(content.accessibilityLabel, "SportBoard. Tu motor de entrenamiento. RITMO, CARGA, PROGRESO.")
    }
}
