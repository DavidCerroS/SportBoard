//
//  SuspiciousPeakDetector.swift
//  SportBoardApp
//
//  Detecta mejoras demasiado rápidas para ser adaptación real.
//  Mensaje no alarmista.
//

import Foundation
import SwiftData

/// Resultado de detección de pico sospechoso
struct SuspiciousPeakResult {
    var detected: Bool
    var message: String
    var improvementSecPerKm: Double?
    var windowWeeks: Int
}

/// Detector de picos sospechosos (mejora demasiado rápida).
struct SuspiciousPeakDetector {
    
    private static let windowWeeks = 2
    private static let improvementThresholdSecPerKm = 20.0
    private static let minActivitiesPerWindow = 2
    
    /// Evalúa si hay mejora sospechosa en ventanas recientes.
    static func evaluate(
        modelContext: ModelContext,
        profile: RunnerProfile?
    ) throws -> SuspiciousPeakResult {
        let activities = try fetchRunActivities(modelContext: modelContext)
        return evaluateFromActivities(activities, profile: profile)
    }
    
    static func evaluateFromActivities(
        _ activities: [Activity],
        profile: RunnerProfile?
    ) -> SuspiciousPeakResult {
        let now = Date()
        let calendar = Calendar.current
        let weekStart = now.startOfWeek
        let runTypes = ["run", "virtualrun", "trailrun"]
        let runs = activities.filter { runTypes.contains($0.sportType.lowercased()) }
            .filter { $0.movingTime >= 20 * 60 && $0.averageSpeed > 0 }
        
        let currentWeekStart = weekStart
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
        let twoWeeksAgoStart = calendar.date(byAdding: .weekOfYear, value: -2, to: weekStart) ?? weekStart
        
        let currentWeekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        
        let inCurrent = runs.filter { $0.startDate >= currentWeekStart && $0.startDate < currentWeekEnd }
        let inTwoWeeksAgo = runs.filter { $0.startDate >= twoWeeksAgoStart && $0.startDate < previousWeekStart }
        
        guard inCurrent.count >= minActivitiesPerWindow, inTwoWeeksAgo.count >= minActivitiesPerWindow else {
            return SuspiciousPeakResult(
                detected: false,
                message: "",
                improvementSecPerKm: nil,
                windowWeeks: Self.windowWeeks
            )
        }
        
        let currentMedianPace = median(inCurrent.map { 1000 / $0.averageSpeed })
        let olderMedianPace = median(inTwoWeeksAgo.map { 1000 / $0.averageSpeed })
        
        guard let cur = currentMedianPace, let old = olderMedianPace, old > 0 else {
            return SuspiciousPeakResult(detected: false, message: "", improvementSecPerKm: nil, windowWeeks: Self.windowWeeks)
        }
        
        let improvement = old - cur
        if improvement >= Self.improvementThresholdSecPerKm {
            return SuspiciousPeakResult(
                detected: true,
                message: String(format: "Has mejorado unos %.0f s/km en 2 semanas. Puede ser efecto del descanso o de las condiciones, no solo adaptación.", improvement),
                improvementSecPerKm: improvement,
                windowWeeks: Self.windowWeeks
            )
        }
        
        return SuspiciousPeakResult(
            detected: false,
            message: "",
            improvementSecPerKm: improvement,
            windowWeeks: Self.windowWeeks
        )
    }
    
    private static func fetchRunActivities(modelContext: ModelContext) throws -> [Activity] {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let all = try modelContext.fetch(descriptor)
        let runTypes = ["run", "virtualrun", "trailrun"]
        return all.filter { runTypes.contains($0.sportType.lowercased()) }
    }
    
    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let mid = s.count / 2
        if s.count.isMultiple(of: 2) {
            return (s[mid - 1] + s[mid]) / 2
        }
        return s[mid]
    }
}
