//
//  WeekComparatorServiceTests.swift
//  SportBoardAppTests
//
//  Created by Cursor on 12/5/26.
//

import XCTest
import SwiftData
@testable import SportBoardApp

final class WeekComparatorServiceTests: XCTestCase {
    func testSortedUniqueWeekSummariesForSelectionOrdersNewestFirst() {
        let oldest = makeSummary(year: 2024, month: 4, day: 1)
        let newest = makeSummary(year: 2024, month: 4, day: 15)
        let middle = makeSummary(year: 2024, month: 4, day: 8)
        let duplicateNewest = makeSummary(year: 2024, month: 4, day: 15)

        let summaries = WeekComparatorService.sortedUniqueWeekSummariesForSelection([
            oldest,
            newest,
            middle,
            duplicateNewest
        ])

        XCTAssertEqual(summaries.map(\.weekStart), [
            newest.weekStart,
            middle.weekStart,
            oldest.weekStart
        ])
    }

    func testFetchPastWeekSummariesKeepsNewestWeeksWhenActivityFetchIsLimited() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let calendar = FixtureLoader.makeMadridCalendar()
        let newestRunDate = FixtureLoader.dateInMadrid(year: 2026, month: 5, day: 4, hour: 7, minute: 0)

        context.insert(makeRun(id: 1, date: newestRunDate))

        for offset in 1...501 {
            let date = calendar.date(byAdding: .weekOfYear, value: -offset, to: newestRunDate)!
            context.insert(makeRun(id: Int64(offset + 1), date: date))
        }
        try context.save()

        let summaries = try WeekComparatorService.fetchPastWeekSummaries(
            modelContext: context,
            profile: nil,
            upToWeeks: 52,
            calendar: calendar
        )

        XCTAssertEqual(summaries.first?.weekStart, newestRunDate.startOfWeek(using: calendar))
        XCTAssertTrue(summaries.dropFirst().allSatisfy { $0.weekStart < summaries[0].weekStart })
    }

    private func makeSummary(year: Int, month: Int, day: Int) -> WeekSummary {
        WeekSummary(
            weekStart: FixtureLoader.dateInMadrid(year: year, month: month, day: day, hour: 0, minute: 0),
            totalDistanceKm: 10,
            totalTimeHours: 1,
            sessionCount: 1,
            easyRatio: 0.5,
            averagePaceSecPerKm: 300,
            averageHeartrate: 145
        )
    }

    private func makeRun(id: Int64, date: Date) -> Activity {
        Activity(
            id: id,
            name: "Run \(id)",
            sportType: "Run",
            startDate: date,
            distance: 5_000,
            movingTime: 1_800,
            elapsedTime: 1_800,
            totalElevationGain: 30,
            averageSpeed: 2.7,
            maxSpeed: 3.2,
            averageHeartrate: 150,
            maxHeartrate: 170,
            hasHeartrate: true
        )
    }
}
