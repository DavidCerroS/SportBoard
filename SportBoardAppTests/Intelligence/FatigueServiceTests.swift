//
//  FatigueServiceTests.swift
//  SportBoardAppTests
//

import XCTest
@testable import SportBoardApp

final class FatigueServiceTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testComputeWorkoutLoadUsesDurationAndInferredIntensity() {
        let profile = RunnerProfile(easyPaceMs: 3.0, thresholdPaceMs: 4.0, confidence: 0.8)
        let easyRun = makeRun(id: 1, daysAgo: 0, minutes: 45, speed: 3.0)
        let tempoRun = makeRun(id: 2, daysAgo: 0, minutes: 45, speed: 3.9)

        let easyLoad = FatigueService.computeWorkoutLoad(activity: easyRun, profile: profile)
        let tempoLoad = FatigueService.computeWorkoutLoad(activity: tempoRun, profile: profile)

        XCTAssertEqual(easyLoad, 45, accuracy: 0.1)
        XCTAssertEqual(tempoLoad, 67.5, accuracy: 0.1)
        XCTAssertGreaterThan(tempoLoad, easyLoad)
    }

    func testMechanicalImpactIncreasesWithElevationPaceAndIntensity() {
        let profile = RunnerProfile(easyPaceMs: 3.0, thresholdPaceMs: 4.0, confidence: 0.8)
        let flatEasy = makeRun(id: 1, daysAgo: 0, minutes: 45, elevation: 20, speed: 3.0)
        let hillyFast = makeRun(id: 2, daysAgo: 0, minutes: 45, elevation: 700, speed: 4.3)

        let flatImpact = FatigueService.computeMechanicalImpact(activity: flatEasy, profile: profile)
        let hillyImpact = FatigueService.computeMechanicalImpact(activity: hillyFast, profile: profile)

        XCTAssertGreaterThan(hillyImpact, flatImpact)
        XCTAssertLessThanOrEqual(hillyImpact, 100)
    }

    func testAcuteAndChronicLoadsAreNormalizedSeparately() {
        let profile = RunnerProfile(easyPaceMs: 3.0, thresholdPaceMs: 4.0, confidence: 0.8)
        let activities = [
            makeRun(id: 1, daysAgo: 0, minutes: 60, speed: 3.8),
            makeRun(id: 2, daysAgo: 3, minutes: 50, speed: 3.2),
            makeRun(id: 3, daysAgo: 12, minutes: 45, speed: 3.0),
            makeRun(id: 4, daysAgo: 24, minutes: 40, speed: 3.0)
        ]

        let acute = FatigueService.computeAcuteLoad(activities: activities, profile: profile, now: now)
        let chronic = FatigueService.computeChronicLoad(activities: activities, profile: profile, now: now)

        XCTAssertGreaterThan(acute, 0)
        XCTAssertGreaterThan(chronic, 0)
        XCTAssertLessThanOrEqual(acute, 100)
        XCTAssertLessThanOrEqual(chronic, 100)
    }

    func testComputeFromActivitiesExposesNormalizedLegFatiguePercentage() {
        let activities = [
            makeRun(id: 1, daysAgo: 0, minutes: 55, elevation: 420, speed: 4.2),
            makeRun(id: 2, daysAgo: 1, minutes: 50, elevation: 260, speed: 3.9),
            makeRun(id: 3, daysAgo: 2, minutes: 45, elevation: 120, speed: 3.5),
            makeRun(id: 4, daysAgo: 3, minutes: 40, elevation: 60, speed: 3.2)
        ]
        let profile = RunnerProfile(easyPaceMs: 3.0, thresholdPaceMs: 4.0, confidence: 0.8)

        let diagnosis = FatigueService.computeFromActivities(activities, profile: profile, now: now)

        XCTAssertGreaterThan(diagnosis.scorePercent, 0)
        XCTAssertLessThanOrEqual(diagnosis.scorePercent, 100)
        XCTAssertEqual(diagnosis.formattedScorePercent, "\(diagnosis.scorePercent)%")
        XCTAssertEqual(diagnosis.state, LegFatigueState(scorePercent: diagnosis.scorePercent))
    }

    func testComputeFromActivitiesHasZeroLegFatigueWhenNoSignalsExist() {
        let diagnosis = FatigueService.computeFromActivities([], profile: nil, now: now)

        XCTAssertEqual(diagnosis.scorePercent, 0)
        XCTAssertEqual(diagnosis.formattedScorePercent, "0%")
        XCTAssertEqual(diagnosis.level, .low)
    }

    private func makeRun(
        id: Int64,
        daysAgo: Int,
        minutes: Int,
        elevation: Double = 50,
        speed: Double,
        heartRate: Double? = nil
    ) -> Activity {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return Activity(
            id: id,
            name: "Run \(id)",
            sportType: "Run",
            startDate: date,
            distance: speed * Double(minutes * 60),
            movingTime: minutes * 60,
            elapsedTime: minutes * 60,
            totalElevationGain: elevation,
            averageSpeed: speed,
            maxSpeed: speed * 1.15,
            averageHeartrate: heartRate,
            hasHeartrate: heartRate != nil
        )
    }
}
