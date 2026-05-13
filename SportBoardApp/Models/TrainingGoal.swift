//
//  TrainingGoal.swift
//  SportBoardApp
//
//  Objetivo activo para que el Coach genere y adapte una semana de trabajo.
//

import Foundation
import SwiftData

@Model
final class TrainingGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var distanceMeters: Double
    var raceDate: Date
    var targetTimeSeconds: Int?
    var objective: String
    /// Offsets desde lunes: 0 = lunes, 1 = martes...
    var preferredWeekdayOffsets: [Int]
    var sessionsPerWeek: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        distanceMeters: Double,
        raceDate: Date,
        targetTimeSeconds: Int? = nil,
        objective: String,
        preferredWeekdayOffsets: [Int] = [0, 1, 3, 5],
        sessionsPerWeek: Int = 4,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.distanceMeters = distanceMeters
        self.raceDate = raceDate
        self.targetTimeSeconds = targetTimeSeconds
        self.objective = objective
        self.preferredWeekdayOffsets = TrainingGoal.normalizedWeekdayOffsets(preferredWeekdayOffsets, sessionsPerWeek: sessionsPerWeek)
        self.sessionsPerWeek = min(6, max(2, sessionsPerWeek))
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var distanceName: String {
        if abs(distanceMeters - 21_100) < 250 {
            return "21,1 km"
        }
        if abs(distanceMeters - 5_000) < 150 {
            return "5 km"
        }
        if abs(distanceMeters - 10_000) < 250 {
            return "10 km"
        }
        if abs(distanceMeters - 42_195) < 500 {
            return "42,2 km"
        }
        return String(format: "%.1f km", distanceMeters / 1000)
    }

    var targetTimeText: String? {
        guard let targetTimeSeconds, targetTimeSeconds > 0 else { return nil }
        let hours = targetTimeSeconds / 3600
        let minutes = (targetTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }

    func update(
        name: String,
        distanceMeters: Double,
        raceDate: Date,
        targetTimeSeconds: Int?,
        objective: String,
        preferredWeekdayOffsets: [Int],
        sessionsPerWeek: Int
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.distanceMeters = max(1_000, distanceMeters)
        self.raceDate = raceDate
        self.targetTimeSeconds = targetTimeSeconds
        self.objective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sessionsPerWeek = min(6, max(2, sessionsPerWeek))
        self.preferredWeekdayOffsets = TrainingGoal.normalizedWeekdayOffsets(
            preferredWeekdayOffsets,
            sessionsPerWeek: self.sessionsPerWeek
        )
        self.updatedAt = Date()
    }

    static func normalizedWeekdayOffsets(_ offsets: [Int], sessionsPerWeek: Int) -> [Int] {
        let unique = Array(Set(offsets.filter { (0...6).contains($0) })).sorted()
        let targetCount = min(6, max(2, sessionsPerWeek))
        if unique.count >= targetCount {
            return Array(unique.prefix(targetCount))
        }

        let defaults = [0, 1, 3, 5, 2, 6]
        let merged = unique + defaults.filter { !unique.contains($0) }
        return Array(merged.prefix(targetCount)).sorted()
    }
}

extension TrainingGoal {
    static func suggestedRaceDate(calendar: Calendar = .sportBoardMadrid, now: Date = Date()) -> Date {
        calendar.date(byAdding: .month, value: 4, to: now) ?? now
    }

    static func makeSuggested(calendar: Calendar = .sportBoardMadrid, now: Date = Date()) -> TrainingGoal {
        TrainingGoal(
            name: "Media maraton",
            distanceMeters: 21_100,
            raceDate: suggestedRaceDate(calendar: calendar, now: now),
            targetTimeSeconds: 95 * 60,
            objective: "Llegar fuerte y sano",
            preferredWeekdayOffsets: [0, 1, 3, 5],
            sessionsPerWeek: 4
        )
    }
}
