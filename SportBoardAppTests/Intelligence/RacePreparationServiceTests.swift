//
//  RacePreparationServiceTests.swift
//  SportBoardAppTests
//

import XCTest
import SwiftData
@testable import SportBoardApp

final class RacePreparationServiceTests: XCTestCase {
    func testEvaluateReturnsNilWithoutActiveGoal() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)

        let preparation = try RacePreparationService.evaluate(modelContext: context, readiness: readiness(.low))

        XCTAssertNil(preparation)
    }

    func testEvaluateUsesActiveTrainingGoal() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let now = FixtureLoader.dateInMadrid(year: 2026, month: 6, day: 1, hour: 9, minute: 0)
        let raceDate = FixtureLoader.dateInMadrid(year: 2026, month: 10, day: 4, hour: 9, minute: 0)
        let goal = TrainingGoal(
            name: "10K objetivo",
            distanceMeters: 10_000,
            raceDate: raceDate,
            targetTimeSeconds: 45 * 60,
            objective: "Bajar marca",
            preferredWeekdayOffsets: [0, 2, 5],
            sessionsPerWeek: 3
        )
        context.insert(goal)
        try context.save()

        let preparation = try RacePreparationService.evaluate(modelContext: context, readiness: readiness(.low), now: now)

        XCTAssertEqual(preparation?.goal.name, "10K objetivo")
        XCTAssertEqual(preparation?.goal.distanceName, "10 km")
        XCTAssertEqual(preparation?.goal.targetTimeText, "45m")
        XCTAssertEqual(preparation?.goal.targetPaceText, "4:30/km")
        XCTAssertEqual(preparation?.weekPlan.count, 3)
        XCTAssertEqual(preparation?.source, .activeGoal)
    }

    func testTrainingGoalSupportsFiveKAndCustomDistance() {
        let fiveK = TrainingGoal(
            name: "5K",
            distanceMeters: 5_000,
            raceDate: Date(),
            objective: "Rapido"
        )
        let custom = TrainingGoal(
            name: "Rodaje test",
            distanceMeters: 6_800,
            raceDate: Date(),
            targetTimeSeconds: 30 * 60 + 15,
            objective: "Personalizado"
        )

        XCTAssertEqual(fiveK.distanceName, "5 km")
        XCTAssertEqual(custom.distanceName, "6.8 km")
        XCTAssertEqual(custom.targetTimeText, "30m 15s")
        XCTAssertEqual(custom.targetPaceText, "4:27/km")
    }

    func testHighReadinessRiskAdaptsKeyWorkoutToEasyRun() {
        let now = FixtureLoader.dateInMadrid(year: 2026, month: 6, day: 1, hour: 9, minute: 0)
        let raceDate = FixtureLoader.dateInMadrid(year: 2026, month: 10, day: 4, hour: 9, minute: 0)
        let goal = RaceGoal(name: "Media", distanceName: "21,1 km", raceDate: raceDate, targetTimeText: "1h 35m", targetPaceText: "4:30/km", objective: "Llegar bien")

        let preparation = RacePreparationService.evaluateFromActivities(
            [],
            readiness: readiness(.high),
            goal: goal,
            preferredWeekdayOffsets: [0, 1, 3, 5],
            source: .activeGoal,
            now: now,
            calendar: .sportBoardMadrid
        )

        let adapted = preparation.weekPlan.filter { $0.adaptation != nil }
        XCTAssertFalse(adapted.isEmpty)
        XCTAssertTrue(adapted.allSatisfy { $0.type == .recovery })
        XCTAssertTrue(preparation.decision.severity == .red)
    }

    func testAdherenceMarksCompletedWorkoutWithActualSummary() {
        let now = FixtureLoader.dateInMadrid(year: 2026, month: 6, day: 3, hour: 9, minute: 0)
        let raceDate = FixtureLoader.dateInMadrid(year: 2026, month: 10, day: 4, hour: 9, minute: 0)
        let monday = FixtureLoader.dateInMadrid(year: 2026, month: 6, day: 1, hour: 7, minute: 0)
        let activity = Activity(
            id: 99,
            name: "Rodaje",
            sportType: "Run",
            startDate: monday,
            distance: 8_000,
            movingTime: 42 * 60,
            elapsedTime: 42 * 60,
            totalElevationGain: 40,
            averageSpeed: 3.1,
            maxSpeed: 3.5,
            averageHeartrate: 142,
            hasHeartrate: true
        )
        let goal = RaceGoal(name: "Media", distanceName: "21,1 km", raceDate: raceDate, targetTimeText: "1h 35m", targetPaceText: "4:30/km", objective: "Llegar bien")

        let preparation = RacePreparationService.evaluateFromActivities(
            [activity],
            readiness: readiness(.low),
            goal: goal,
            preferredWeekdayOffsets: [0, 1, 3, 5],
            source: .activeGoal,
            now: now,
            calendar: .sportBoardMadrid
        )

        XCTAssertTrue(preparation.completedWorkoutIDs.contains(where: { $0.contains("recovery") }))
        XCTAssertTrue(preparation.adherence.contains(where: { $0.status == .completed && $0.actualSummary != nil }))
    }

    private func readiness(_ risk: ReadinessRiskLevel) -> TrainingReadiness {
        let state: ReadinessState = risk == .high ? .recover : (risk == .moderate ? .caution : .ready)
        return TrainingReadiness(
            state: state,
            score: risk == .high ? 25 : (risk == .moderate ? 55 : 85),
            recommendation: nil,
            riskLevel: risk,
            signals: [],
            explanation: ["Test readiness"]
        )
    }
}
