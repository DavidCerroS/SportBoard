//
//  ElevationBreakdownCalculatorTests.swift
//  SportBoardAppTests
//

import XCTest
@testable import SportBoardApp

final class ElevationBreakdownCalculatorTests: XCTestCase {
    func testCalculateSequentialBreakdownsWithInterpolation() {
        let distanceStream = [0.0, 400.0, 800.0, 1200.0]
        let altitudeStream = [100.0, 110.0, 90.0, 100.0]

        let breakdowns = ElevationBreakdownCalculator.calculateSequentialBreakdowns(
            segmentDistances: [600.0, 600.0],
            distanceStream: distanceStream,
            altitudeStream: altitudeStream
        )

        XCTAssertEqual(breakdowns?.count, 2)
        XCTAssertEqual(breakdowns?[0], ElevationBreakdown(positive: 10, negative: 10))
        XCTAssertEqual(breakdowns?[1], ElevationBreakdown(positive: 10, negative: 10))
    }

    func testCalculateSequentialPowerBreakdownsUsesWattsStream() {
        let distanceStream = [0.0, 500.0, 1000.0, 1500.0, 2000.0]
        let timeStream = [0, 120, 240, 360, 480]
        let wattsStream = [200, 220, 240, 260, 300]

        let breakdowns = PowerBreakdownCalculator.calculateSequentialBreakdowns(
            segmentDistances: [1000.0, 1000.0],
            distanceStream: distanceStream,
            timeStream: timeStream,
            wattsStream: wattsStream
        )

        XCTAssertEqual(breakdowns?.count, 2)
        XCTAssertEqual(breakdowns?[0].average ?? 0, 220, accuracy: 0.1)
        XCTAssertEqual(breakdowns?[0].max, 240)
        XCTAssertEqual(breakdowns?[1].average ?? 0, 265, accuracy: 0.1)
        XCTAssertEqual(breakdowns?[1].max, 300)
    }
}
