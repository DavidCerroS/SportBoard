//
//  RunClassifierTests.swift
//  SportBoardAppTests
//
//  Created by Codex on 10/3/25.
//

import XCTest
@testable import SportBoardApp

final class RunClassifierTests: XCTestCase {
    func testClassifyIntervalsFromStructuredLaps() throws {
        let fixture = try FixtureLoader.load(named: "intervals_with_laps_splits")
        let activity = FixtureLoader.makeActivity(from: fixture)
        let laps = activity.sortedLaps
        let splits = activity.sortedSplits
        
        let result = RunClassifier.classify(activity: activity, splits: splits, laps: laps)
        
        XCTAssertEqual(result.type, .intervals)
        XCTAssertTrue(result.shouldShow)
        XCTAssertTrue(result.reasons.contains(where: { $0.contains("intervalos") }))
    }
    
    func testClassifyLongRunByDuration() throws {
        let fixture = try FixtureLoader.load(named: "long_run")
        let activity = FixtureLoader.makeActivity(from: fixture)
        
        let result = RunClassifier.classify(activity: activity)
        
        XCTAssertEqual(result.type, .long)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.6)
    }
    
    func testClassifyRecoveryFromSlowPaceHighHr() throws {
        let fixture = try FixtureLoader.load(named: "slow_high_hr")
        let activity = FixtureLoader.makeActivity(from: fixture)
        
        let result = RunClassifier.classify(activity: activity)
        
        XCTAssertEqual(result.type, .recovery)
        XCTAssertTrue(result.shouldShow)
        XCTAssertTrue(result.reasons.contains(where: { $0.contains("FC elevada") }))
    }
}
