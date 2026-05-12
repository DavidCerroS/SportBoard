//
//  ActivityComparisonServiceTests.swift
//  SportBoardAppTests
//
//  Created by Cursor on 11/5/26.
//

import XCTest
@testable import SportBoardApp

final class ActivityComparisonServiceTests: XCTestCase {
    func testDefaultSelectionUsesAllComparableRunsWhenPreviousSelectionIsUnavailable() {
        let recentTenK = makeRun(id: 3, distance: 10_000)
        let olderFiveK = makeRun(id: 2, distance: 5_000)
        let ride = makeRun(id: 1, distance: 21_100)
        ride.sportType = "Ride"

        let activities = ActivityComparisonService.sortedComparableActivities(from: [olderFiveK, ride, recentTenK])
        let selection = ActivityComparisonService.defaultSelectionIDs(
            in: activities,
            currentFirstID: 99,
            currentSecondID: 100
        )

        XCTAssertEqual(activities.map(\.id), [3, 2])
        XCTAssertEqual(selection.firstID, 3)
        XCTAssertEqual(selection.secondID, 2)
    }

    func testCompareReportsAveragePaceDifferenceInSecondsPerKm() {
        let first = makeRun(id: 1, distance: 10_000, movingTime: 3_000, averageSpeed: 1000.0 / 300.0)
        let second = makeRun(id: 2, distance: 10_000, movingTime: 2_850, averageSpeed: 1000.0 / 285.0)

        let comparison = ActivityComparisonService.compare(first, second)
        let paceMetric = comparison.metrics.first { $0.id == "averagePace" }

        XCTAssertEqual(paceMetric?.firstValue, "5:00 /km")
        XCTAssertEqual(paceMetric?.secondValue, "4:45 /km")
        XCTAssertEqual(paceMetric?.differenceValue, "-15s /km")
        XCTAssertNotNil(paceMetric?.rawDifference)
        XCTAssertEqual(paceMetric?.rawDifference ?? 0, -15, accuracy: 0.1)
        XCTAssertEqual(paceMetric?.trend, .better)
        XCTAssertTrue(comparison.insights.contains { $0.contains("15s más rápido") })
    }

    func testCompareHandlesOptionalHeartRateAndPowerWithoutInventingDifferences() {
        let first = makeRun(
            id: 1,
            distance: 8_000,
            movingTime: 2_880,
            averageSpeed: 1000.0 / 360.0,
            averageHeartrate: 142,
            averageWatts: nil
        )
        let second = makeRun(
            id: 2,
            distance: 8_000,
            movingTime: 2_900,
            averageSpeed: 1000.0 / 362.5,
            averageHeartrate: nil,
            averageWatts: 240
        )

        let comparison = ActivityComparisonService.compare(first, second)
        let heartRateMetric = comparison.metrics.first { $0.id == "averageHeartRate" }
        let powerMetric = comparison.metrics.first { $0.id == "averagePower" }

        XCTAssertEqual(heartRateMetric?.firstValue, "142 bpm")
        XCTAssertEqual(heartRateMetric?.secondValue, "--")
        XCTAssertEqual(heartRateMetric?.differenceValue, "--")
        XCTAssertNil(heartRateMetric?.rawDifference)
        XCTAssertEqual(powerMetric?.firstValue, "--")
        XCTAssertEqual(powerMetric?.secondValue, "240 W")
        XCTAssertEqual(powerMetric?.differenceValue, "--")
        XCTAssertNil(powerMetric?.rawDifference)
    }

    func testCompareAlignsSplitsByIndexAndUsesMinimumCommonCount() {
        let firstSplits = [
            ActivitySplit(splitIndex: 0, distance: 1000, movingTime: 300, elapsedTime: 300, averageSpeed: 1000.0 / 300.0, averageHeartrate: 140, elevationDifference: 4),
            ActivitySplit(splitIndex: 1, distance: 1000, movingTime: 305, elapsedTime: 305, averageSpeed: 1000.0 / 305.0, averageHeartrate: 144, elevationDifference: 8),
            ActivitySplit(splitIndex: 2, distance: 1000, movingTime: 310, elapsedTime: 310, averageSpeed: 1000.0 / 310.0, averageHeartrate: 146, elevationDifference: 2)
        ]
        let secondSplits = [
            ActivitySplit(splitIndex: 0, distance: 1000, movingTime: 295, elapsedTime: 295, averageSpeed: 1000.0 / 295.0, averageHeartrate: 142, elevationDifference: 5),
            ActivitySplit(splitIndex: 1, distance: 1000, movingTime: 315, elapsedTime: 315, averageSpeed: 1000.0 / 315.0, averageHeartrate: 148, elevationDifference: 9)
        ]
        let first = makeRun(id: 1, splits: firstSplits)
        let second = makeRun(id: 2, splits: secondSplits)

        let comparison = ActivityComparisonService.compare(first, second)

        XCTAssertEqual(comparison.segmentSource, .splits)
        XCTAssertEqual(comparison.segments.count, 2)
        XCTAssertEqual(comparison.segments[0].title, "Km 1")
        XCTAssertEqual(comparison.segments[0].paceDifference, "-5s /km")
        XCTAssertEqual(comparison.segments[0].trend, .better)
        XCTAssertEqual(comparison.segments[1].paceDifference, "+10s /km")
        XCTAssertEqual(comparison.segments[1].trend, .worse)
    }

    func testComparePrefersLapsWhenBothActivitiesHaveLaps() {
        let first = makeRun(
            id: 1,
            laps: [
                ActivityLap(lapIndex: 0, name: "Tempo 1", distance: 2000, movingTime: 720, averageSpeed: 2000.0 / 720.0),
                ActivityLap(lapIndex: 1, name: "Tempo 2", distance: 2000, movingTime: 700, averageSpeed: 2000.0 / 700.0)
            ],
            splits: [
                ActivitySplit(splitIndex: 0, distance: 1000, movingTime: 360, elapsedTime: 360, averageSpeed: 1000.0 / 360.0)
            ]
        )
        let second = makeRun(
            id: 2,
            laps: [
                ActivityLap(lapIndex: 0, name: "Tempo 1", distance: 2000, movingTime: 700, averageSpeed: 2000.0 / 700.0),
                ActivityLap(lapIndex: 1, name: "Tempo 2", distance: 2000, movingTime: 690, averageSpeed: 2000.0 / 690.0)
            ],
            splits: [
                ActivitySplit(splitIndex: 0, distance: 1000, movingTime: 350, elapsedTime: 350, averageSpeed: 1000.0 / 350.0)
            ]
        )

        let comparison = ActivityComparisonService.compare(first, second)

        XCTAssertEqual(comparison.segmentSource, .laps)
        XCTAssertEqual(comparison.segments.count, 2)
        XCTAssertEqual(comparison.segments[0].title, "Tempo 1")
        XCTAssertEqual(comparison.segments[0].paceDifference, "-10s /km")
    }

    private func makeRun(
        id: Int64,
        distance: Double = 10_000,
        movingTime: Int = 3_000,
        elapsedTime: Int? = nil,
        averageSpeed: Double = 1000.0 / 300.0,
        averageHeartrate: Double? = 145,
        averageWatts: Double? = 250,
        laps: [ActivityLap]? = nil,
        splits: [ActivitySplit]? = nil
    ) -> Activity {
        let activity = Activity(
            id: id,
            name: "Run \(id)",
            sportType: "Run",
            startDate: Date(timeIntervalSince1970: TimeInterval(id * 1000)),
            distance: distance,
            movingTime: movingTime,
            elapsedTime: elapsedTime ?? movingTime,
            totalElevationGain: 80,
            averageSpeed: averageSpeed,
            maxSpeed: averageSpeed * 1.2,
            averageHeartrate: averageHeartrate,
            maxHeartrate: averageHeartrate.map { $0 + 20 },
            averageWatts: averageWatts,
            maxWatts: averageWatts.map { $0 + 80 },
            kilojoules: averageWatts.map { $0 * Double(movingTime) / 1000 },
            hasHeartrate: averageHeartrate != nil,
            hasPowerMeter: averageWatts != nil,
            hasLaps: laps != nil,
            hasSplitsMetric: splits != nil,
            laps: laps,
            splitsMetric: splits
        )
        laps?.forEach { $0.activity = activity }
        splits?.forEach { $0.activity = activity }
        return activity
    }
}
