//
//  WeekComparatorService.swift
//  SportBoardApp
//
//  Compara semanas por estructura (volumen, nº sesiones, distribución fácil/duro), no por calendario.
//

import Foundation
import SwiftData

/// Resumen de una semana para comparación
struct WeekSummary: Identifiable {
    var id: Date { weekStart }
    var weekStart: Date
    var totalDistanceKm: Double
    var totalTimeHours: Double
    var sessionCount: Int
    var easyRatio: Double
    var averagePaceSecPerKm: Double?
    var averageHeartrate: Double?
    
    var formattedDistance: String { String(format: "%.1f km", totalDistanceKm) }
    var formattedTime: String { String(format: "%.1f h", totalTimeHours) }
}

/// Criterio de equivalencia para buscar semana de referencia
enum WeekEquivalenceCriterion {
    case similarVolume      // ±15% volumen (km)
    case sameSessionCount  // Mismo nº de sesiones
    case similarEasyRatio  // Proporción fácil similar
}

/// Resultado de comparación entre dos semanas
struct WeekComparison {
    var current: WeekSummary
    var reference: WeekSummary
    var criterion: WeekEquivalenceCriterion
    var insights: [String]
}

/// Servicio que compara semanas equivalentes.
struct WeekComparatorService {
    
    private static let volumeTolerance = 0.15
    private static let easyRatioTolerance = 0.12
    private static let maxWeeksToSearch = 52
    
    /// Obtiene el resumen de la semana que contiene la fecha dada (Europe/Madrid, Lunes).
    static func weekSummary(
        for date: Date,
        activities: [Activity],
        profile: RunnerProfile?,
        calendar: Calendar = Calendar.sportBoardMadrid
    ) -> WeekSummary {
        let weekStart = date.startOfWeek(using: calendar)
        let weekEnd = date.startOfNextWeek(using: calendar)
        let inWeek = activities.filter { act in
            act.startDate >= weekStart && act.startDate < weekEnd
        }
        let runTypes = ["run", "virtualrun", "trailrun"]
        let runs = inWeek.filter { runTypes.contains($0.sportType.lowercased()) }
        
        let totalKm = runs.reduce(0.0) { $0 + $1.distance / 1000 }
        let totalSec = runs.reduce(0) { $0 + $1.movingTime }
        let totalHours = Double(totalSec) / 3600
        let easyPaceMs = profile?.easyPaceMs ?? 0
        let easyTime = runs.filter { easyPaceMs > 0 && $0.averageSpeed <= easyPaceMs * 1.02 }.reduce(0) { $0 + $1.movingTime }
        let easyRatio = totalSec > 0 ? Double(easyTime) / Double(totalSec) : 0.5
        
        var avgPace: Double? = nil
        var totalPaceSec = 0.0
        var paceCount = 0
        for act in runs where act.averageSpeed > 0 {
            totalPaceSec += 1000 / act.averageSpeed
            paceCount += 1
        }
        if paceCount > 0 {
            avgPace = totalPaceSec / Double(paceCount)
        }
        
        var avgHR: Double? = nil
        let withHR = runs.compactMap(\.averageHeartrate)
        if !withHR.isEmpty {
            avgHR = withHR.reduce(0, +) / Double(withHR.count)
        }
        
        return WeekSummary(
            weekStart: weekStart,
            totalDistanceKm: totalKm,
            totalTimeHours: totalHours,
            sessionCount: runs.count,
            easyRatio: easyRatio,
            averagePaceSecPerKm: avgPace,
            averageHeartrate: avgHR
        )
    }
    
    /// Busca una semana equivalente en el pasado según criterio.
    static func findEquivalentWeek(
        currentSummary: WeekSummary,
        pastSummaries: [WeekSummary],
        criterion: WeekEquivalenceCriterion
    ) -> WeekSummary? {
        switch criterion {
        case .similarVolume:
            let target = currentSummary.totalDistanceKm
            return pastSummaries.first { s in
                guard s.totalDistanceKm > 0 else { return false }
                let ratio = s.totalDistanceKm / target
                return ratio >= (1 - volumeTolerance) && ratio <= (1 + volumeTolerance)
            }
        case .sameSessionCount:
            return pastSummaries.first { $0.sessionCount == currentSummary.sessionCount }
        case .similarEasyRatio:
            return pastSummaries.first { s in
                abs(s.easyRatio - currentSummary.easyRatio) <= easyRatioTolerance
            }
        }
    }
    
    /// Genera insights comparando semana actual con referencia.
    static func compare(current: WeekSummary, reference: WeekSummary) -> [String] {
        var insights: [String] = []
        
        if reference.totalDistanceKm > 0 {
            let diff = ((current.totalDistanceKm - reference.totalDistanceKm) / reference.totalDistanceKm) * 100
            if abs(diff) >= 10 {
                insights.append(String(format: "Volumen %.0f%% %@ respecto a la semana de referencia.", abs(diff), diff > 0 ? "mayor" : "menor"))
            }
        }
        
        if current.sessionCount != reference.sessionCount {
            insights.append("Sesiones: \(current.sessionCount) vs \(reference.sessionCount) en la semana de referencia.")
        }
        
        if let cp = current.averagePaceSecPerKm, let rp = reference.averagePaceSecPerKm, rp > 0 {
            let diffSec = cp - rp
            if abs(diffSec) >= 10 {
                insights.append(String(format: "Ritmo medio %@ %.0f s/km.", diffSec > 0 ? "más lento" : "más rápido", abs(diffSec)))
            }
        }
        
        if abs(current.easyRatio - reference.easyRatio) >= 0.1 {
            insights.append(String(format: "Proporción fácil: %.0f%% vs %.0f%%.", current.easyRatio * 100, reference.easyRatio * 100))
        }
        
        return insights
    }
    
    /// Obtiene resúmenes de todas las semanas con actividad (para el comparador).
    static func fetchPastWeekSummaries(
        modelContext: ModelContext,
        profile: RunnerProfile?,
        upToWeeks: Int = maxWeeksToSearch,
        calendar: Calendar = Calendar.sportBoardMadrid
    ) throws -> [WeekSummary] {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        descriptor.fetchLimit = 500
        let all = try modelContext.fetch(descriptor)
        let runTypes = ["run", "virtualrun", "trailrun"]
        let runs = all.filter { runTypes.contains($0.sportType.lowercased()) }
        
        let byWeek = Dictionary(grouping: runs) { $0.startDate.startOfWeek(using: calendar) }
        let sortedWeeks = byWeek.keys.sorted(by: >)
        let weeksToTake = Array(sortedWeeks.prefix(upToWeeks))
        
        return weeksToTake.compactMap { weekStart in
            let acts = byWeek[weekStart] ?? []
            guard !acts.isEmpty else { return nil }
            return weekSummary(for: weekStart, activities: runs, profile: profile, calendar: calendar)
        }
    }
}
