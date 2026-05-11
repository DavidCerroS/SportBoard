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
}
