//
//  DataQualityTests.swift
//  SportBoardAppTests
//
//  Created by Codex on 10/3/25.
//

import XCTest
@testable import SportBoardApp

final class DataQualityTests: XCTestCase {
    func testEvaluateMissingDataFlags() throws {
        let fixture = try FixtureLoader.load(named: "empty_activity")
        let activity = FixtureLoader.makeActivity(from: fixture)
        
        let quality = DataQuality.evaluate(activity: activity, splits: nil)
        
        XCTAssertFalse(quality.hasHeartrate)
        XCTAssertFalse(quality.hasSplits)
        XCTAssertFalse(quality.hasEnoughDuration)
        XCTAssertFalse(quality.hasEnoughDistance)
        XCTAssertTrue(quality.isRun)
        XCTAssertFalse(quality.canClassify)
    }
    
    func testEvaluateRunWithSplitsAndHeartrate() throws {
        let fixture = try FixtureLoader.load(named: "easy_run_with_hr")
        let activity = FixtureLoader.makeActivity(from: fixture)
        let splits = activity.sortedSplits
        
        let quality = DataQuality.evaluate(activity: activity, splits: splits)
        
        XCTAssertTrue(quality.hasHeartrate)
        XCTAssertTrue(quality.hasSplits)
        XCTAssertTrue(quality.hasEnoughDuration)
        XCTAssertTrue(quality.hasEnoughDistance)
        XCTAssertTrue(quality.isRun)
        XCTAssertTrue(quality.canClassify)
        XCTAssertTrue(quality.canUseHeartrateMetrics)
        XCTAssertTrue(quality.canUseSplitMetrics)
    }
    
    func testEvaluateNonRunDisablesMetrics() throws {
        let fixture = try FixtureLoader.load(named: "non_run_ride")
        let activity = FixtureLoader.makeActivity(from: fixture)
        
        let quality = DataQuality.evaluate(activity: activity, splits: nil)
        
        XCTAssertFalse(quality.isRun)
        XCTAssertFalse(quality.canUseHeartrateMetrics)
        XCTAssertFalse(quality.canUseSplitMetrics)
        XCTAssertFalse(quality.canClassify)
        XCTAssertTrue(quality.missingReasons.contains(where: { $0.contains("carrera") }))
    }
}
