//
//  FatigueDiagnosisExplanationModelTests.swift
//  SportBoardAppTests
//

import XCTest
@testable import SportBoardApp

final class FatigueDiagnosisExplanationModelTests: XCTestCase {
    func testFatigueDiagnosisSuppliesExplanationFieldsForExpandedCard() {
        let diagnosis = FatigueDiagnosis(
            level: .medium,
            scorePercent: 45,
            causes: ["Carga aguda alta", "Sesiones intensas"],
            recommendedAction: "Prioriza recuperación.",
        )

        XCTAssertEqual(diagnosis.state, LegFatigueState(scorePercent: 45))
        XCTAssertEqual(diagnosis.causes.count, 2)
        XCTAssertFalse(diagnosis.recommendedAction.isEmpty)
        XCTAssertEqual(diagnosis.formattedScorePercent, "45%")
    }
}
