//
//  RunnerProfileServiceTests.swift
//  SportBoardAppTests
//
//  Created by Codex on 10/3/25.
//

import XCTest
import SwiftData
@testable import SportBoardApp

final class RunnerProfileServiceTests: XCTestCase {
    func testComputeFromActivitiesProducesExpectedProfile() throws {
        let fixtures = try [
            "easy_run_with_hr",
            "tempo_run",
            "long_run",
            "slow_high_hr",
            "steady_run"
        ].map { try FixtureLoader.load(named: $0) }
        
        let activities = fixtures.map { FixtureLoader.makeActivity(from: $0) }
        let calendar = FixtureLoader.makeMadridCalendar()
        let profile = RunnerProfileService.computeFromActivities(activities, calendar: calendar)
        
        XCTAssertGreaterThan(profile.easyPaceMs, 0)
        XCTAssertGreaterThan(profile.thresholdPaceMs, 0)
        XCTAssertGreaterThanOrEqual(profile.confidence, 0.1)
        XCTAssertGreaterThanOrEqual(profile.weeklyVariability, 0)
        XCTAssertGreaterThan(profile.easyHardRatio, 0)
        XCTAssertLessThanOrEqual(profile.easyHardRatio, 1)
    }
    
    func testComputeAndSaveStoresProfileWithFixedDate() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let fixtures = try [
            "easy_run_with_hr",
            "tempo_run",
            "long_run",
            "slow_high_hr",
            "steady_run"
        ].map { try FixtureLoader.load(named: $0) }
        fixtures
            .map { FixtureLoader.makeActivity(from: $0) }
            .forEach { context.insert($0) }
        try context.save()
        
        let fixedDate = FixtureLoader.dateInMadrid(year: 2024, month: 3, day: 25, hour: 10, minute: 0)
        let provider = FixedDateProvider(now: fixedDate, calendar: FixtureLoader.makeMadridCalendar())
        try RunnerProfileService.computeAndSave(modelContext: context, dateProvider: provider)
        
        let profile = try RunnerProfileService.fetchProfile(modelContext: context)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.lastComputedAt, fixedDate)
    }
    
    func testShouldRecomputeUsesDateProvider() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let pastDate = FixtureLoader.dateInMadrid(year: 2024, month: 1, day: 1, hour: 10, minute: 0)
        let profile = RunnerProfile(
            easyPaceMs: 3.2,
            thresholdPaceMs: 3.8,
            weeklyVariability: 0.2,
            easyHardRatio: 0.7,
            confidence: 0.5,
            lastComputedAt: pastDate,
            sportType: "Run"
        )
        context.insert(profile)
        try context.save()
        
        let now = FixtureLoader.dateInMadrid(year: 2024, month: 1, day: 20, hour: 10, minute: 0)
        let provider = FixedDateProvider(now: now, calendar: FixtureLoader.makeMadridCalendar())
        
        XCTAssertTrue(try RunnerProfileService.shouldRecompute(modelContext: context, dateProvider: provider))
    }
}
