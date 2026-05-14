//
//  InMemoryModelContainer.swift
//  SportBoardAppTests
//
//  Created by Codex on 10/3/25.
//

import Foundation
import SwiftData
@testable import SportBoardApp

enum InMemoryModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            Activity.self,
            ActivitySplit.self,
            ActivityLap.self,
            ActivityZoneDistribution.self,
            ActivityStreamSummary.self,
            StravaGear.self,
            ActivitySegmentEffort.self,
            ActivityTempoBlockSplit.self,
            RunnerProfile.self,
            TrainingGoal.self,
            PostActivityReflection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
