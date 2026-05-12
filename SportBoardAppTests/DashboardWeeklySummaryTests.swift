//
//  DashboardWeeklySummaryTests.swift
//  SportBoardAppTests
//

import XCTest
import SwiftData
@testable import SportBoardApp

@MainActor
final class DashboardWeeklySummaryTests: XCTestCase {
    func testFormattedWeeklySummaryMetricsUseExistingFormattingContracts() {
        let viewModel = DashboardViewModel()
        viewModel.thisWeekDistance = 42_195
        viewModel.thisWeekTime = 12_780
        viewModel.thisWeekAverageHeartrate = 148.4
        viewModel.thisWeekAveragePower = 261.2
        viewModel.fatigueDiagnosis = FatigueDiagnosis(
            level: .medium,
            scorePercent: 35,
            causes: ["Carga reciente elevada"],
            recommendedAction: "Prioriza rodajes fáciles."
        )

        XCTAssertEqual(viewModel.formattedThisWeekDistance, "42.20 km")
        XCTAssertEqual(viewModel.formattedThisWeekTime, "3h 33m")
        XCTAssertEqual(viewModel.formattedThisWeekAverageHeartrate, "148 bpm")
        XCTAssertEqual(viewModel.formattedThisWeekAveragePower, "261 W")
        XCTAssertEqual(viewModel.formattedCurrentLegFatigue, "35%")
    }

    func testLoadStats_ordersThisWeekRunsAscendingByStartDate() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let viewModel = DashboardViewModel()
        viewModel.configure(modelContext: context)

        let weekStart = Date().startOfWeekMadrid
        let earlier = weekStart.addingTimeInterval(3_600)
        let later = weekStart.addingTimeInterval(7_200)

        context.insert(
            Activity(
                id: 201,
                name: "Martes rodaje",
                sportType: "Run",
                startDate: later,
                distance: 5000,
                movingTime: 1800,
                elapsedTime: 1800
            )
        )
        context.insert(
            Activity(
                id: 202,
                name: "Lunes tirada larga",
                sportType: "run",
                startDate: earlier,
                distance: 10_000,
                movingTime: 3300,
                elapsedTime: 3300
            )
        )
        context.insert(
            Activity(
                id: 203,
                name: "Mountain bike fuera",
                sportType: "Ride",
                startDate: weekStart.addingTimeInterval(400),
                distance: 35_000,
                movingTime: 5400,
                elapsedTime: 5400
            )
        )

        try context.save()

        viewModel.loadStats()

        XCTAssertEqual(viewModel.thisWeekActivities, 2)
        XCTAssertEqual(viewModel.thisWeekRunsSorted.map(\.id), [202, 201])
        XCTAssertEqual(viewModel.thisWeekRunsSorted.first?.distance, 10_000)
    }
}
