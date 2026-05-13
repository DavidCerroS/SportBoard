//
//  ConsistencyServiceTests.swift
//  SportBoardAppTests
//

import XCTest
@testable import SportBoardApp

final class ConsistencyServiceTests: XCTestCase {
    func testStreakUsesYearWindowNotOnlyRecentScoreWindow() {
        let calendar = FixtureLoader.makeMadridCalendar()
        let now = FixtureLoader.dateInMadrid(year: 2026, month: 5, day: 13, hour: 12, minute: 0)
        let weekStart = now.startOfWeek(using: calendar)
        let activities = (0..<20).compactMap { weekOffset -> Activity? in
            guard let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: weekStart) else {
                return nil
            }
            return makeRun(id: Int64(weekOffset + 1), date: date)
        }

        let result = ConsistencyService.computeFromActivities(activities, profile: nil, now: now, calendar: calendar)

        XCTAssertEqual(result.consecutiveWeeks, 20)
        XCTAssertTrue(result.reasons.contains(where: { $0.contains("Racha activa: 20 semanas") }))
    }

    func testCurrentWeekWithoutRunKeepsStreakFromPreviousWeek() {
        let calendar = FixtureLoader.makeMadridCalendar()
        let now = FixtureLoader.dateInMadrid(year: 2026, month: 5, day: 13, hour: 12, minute: 0)
        let weekStart = now.startOfWeek(using: calendar)
        let activities = (1..<8).compactMap { weekOffset -> Activity? in
            guard let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: weekStart) else {
                return nil
            }
            return makeRun(id: Int64(weekOffset), date: date)
        }

        let result = ConsistencyService.computeFromActivities(activities, profile: nil, now: now, calendar: calendar)

        XCTAssertEqual(result.consecutiveWeeks, 7)
    }

    private func makeRun(id: Int64, date: Date) -> Activity {
        Activity(
            id: id,
            name: "Run \(id)",
            sportType: "Run",
            startDate: date,
            distance: 8_000,
            movingTime: 2_700,
            elapsedTime: 2_700,
            totalElevationGain: 40,
            averageSpeed: 2.96,
            maxSpeed: 3.4,
            averageHeartrate: 145,
            hasHeartrate: true
        )
    }
}
