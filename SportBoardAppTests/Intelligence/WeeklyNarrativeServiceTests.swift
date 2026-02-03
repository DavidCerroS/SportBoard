//
//  WeeklyNarrativeServiceTests.swift
//  SportBoardAppTests
//
//  Created by Codex on 10/3/25.
//

import XCTest
import SwiftData
@testable import SportBoardApp

final class WeeklyNarrativeServiceTests: XCTestCase {
    func testFetchThisWeekRunsHandlesDstStart() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let calendar = FixtureLoader.makeMadridCalendar()
        let now = FixtureLoader.dateInMadrid(year: 2024, month: 3, day: 28, hour: 12, minute: 0)
        let provider = FixedDateProvider(now: now, calendar: calendar)
        
        let mondayRun = makeRun(id: 1, date: FixtureLoader.dateInMadrid(year: 2024, month: 3, day: 25, hour: 6, minute: 0))
        let sundayRun = makeRun(id: 2, date: FixtureLoader.dateInMadrid(year: 2024, month: 3, day: 31, hour: 23, minute: 30))
        let nextWeekRun = makeRun(id: 3, date: FixtureLoader.dateInMadrid(year: 2024, month: 4, day: 1, hour: 0, minute: 30))
        
        context.insert(mondayRun)
        context.insert(sundayRun)
        context.insert(nextWeekRun)
        try context.save()
        
        let results = try WeeklyNarrativeService.fetchThisWeekRuns(
            modelContext: context,
            dateProvider: provider,
            calendar: calendar
        )
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains(where: { $0.id == 1 }))
        XCTAssertTrue(results.contains(where: { $0.id == 2 }))
    }
    
    func testFetchThisWeekRunsHandlesDstEnd() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let calendar = FixtureLoader.makeMadridCalendar()
        let now = FixtureLoader.dateInMadrid(year: 2024, month: 10, day: 24, hour: 12, minute: 0)
        let provider = FixedDateProvider(now: now, calendar: calendar)
        
        let mondayRun = makeRun(id: 10, date: FixtureLoader.dateInMadrid(year: 2024, month: 10, day: 21, hour: 7, minute: 0))
        let sundayRun = makeRun(id: 11, date: FixtureLoader.dateInMadrid(year: 2024, month: 10, day: 27, hour: 2, minute: 30))
        let nextWeekRun = makeRun(id: 12, date: FixtureLoader.dateInMadrid(year: 2024, month: 10, day: 28, hour: 0, minute: 10))
        
        context.insert(mondayRun)
        context.insert(sundayRun)
        context.insert(nextWeekRun)
        try context.save()
        
        let results = try WeeklyNarrativeService.fetchThisWeekRuns(
            modelContext: context,
            dateProvider: provider,
            calendar: calendar
        )
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains(where: { $0.id == 10 }))
        XCTAssertTrue(results.contains(where: { $0.id == 11 }))
    }
    
    func testFetchThisWeekRunsHandlesYearBoundary() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let calendar = FixtureLoader.makeMadridCalendar()
        let now = FixtureLoader.dateInMadrid(year: 2023, month: 12, day: 31, hour: 12, minute: 0)
        let provider = FixedDateProvider(now: now, calendar: calendar)
        
        let sundayRun = makeRun(id: 20, date: FixtureLoader.dateInMadrid(year: 2023, month: 12, day: 31, hour: 9, minute: 0))
        let nextWeekRun = makeRun(id: 21, date: FixtureLoader.dateInMadrid(year: 2024, month: 1, day: 1, hour: 0, minute: 0))
        
        context.insert(sundayRun)
        context.insert(nextWeekRun)
        try context.save()
        
        let results = try WeeklyNarrativeService.fetchThisWeekRuns(
            modelContext: context,
            dateProvider: provider,
            calendar: calendar
        )
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, 20)
    }
    
    private func makeRun(id: Int64, date: Date) -> Activity {
        Activity(
            id: id,
            name: "Run \(id)",
            sportType: "Run",
            startDate: date,
            distance: 5000,
            movingTime: 1800,
            elapsedTime: 1800,
            totalElevationGain: 30,
            averageSpeed: 2.7,
            maxSpeed: 3.2,
            averageHeartrate: 150,
            maxHeartrate: 170,
            hasHeartrate: true
        )
    }
}
