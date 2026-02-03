//
//  WeeklyNarrativeService.swift
//  SportBoardApp
//
//  Resumen textual corto y honesto de la semana.
//  Síntesis real; más útil que solo gráficos.
//

import Foundation
import SwiftData

/// Genera narrativa semanal automática desde datos locales.
struct WeeklyNarrativeService {
    
    /// Genera el texto de la semana para actividades de carrera.
    static func generate(
        modelContext: ModelContext,
        profile: RunnerProfile?,
        consistency: ConsistencyBreakdown?,
        fatigue: FatigueDiagnosis?,
        efficiencyTrend: EfficiencyTrendDirection? = nil,
        dateProvider: DateProviding = SystemDateProvider()
    ) throws -> String {
        let activities = try fetchThisWeekRuns(modelContext: modelContext, dateProvider: dateProvider)
        return generateFromData(
            weekActivities: activities,
            profile: profile,
            consistency: consistency,
            fatigue: fatigue,
            efficiencyTrend: efficiencyTrend
        )
    }
    
    static func generateFromData(
        weekActivities: [Activity],
        profile: RunnerProfile?,
        consistency: ConsistencyBreakdown?,
        fatigue: FatigueDiagnosis?,
        efficiencyTrend: EfficiencyTrendDirection? = nil
    ) -> String {
        var parts: [String] = []
        
        if weekActivities.isEmpty {
            return "Sin actividades de carrera esta semana."
        }
        
        // Resumen básico: número de sesiones y distancia
        let sessionCount = weekActivities.count
        let totalDistanceKm = weekActivities.reduce(0.0) { $0 + $1.distance / 1000 }
        let totalTimeHours = Double(weekActivities.reduce(0) { $0 + $1.movingTime }) / 3600.0
        
        var summaryParts: [String] = []
        summaryParts.append(sessionCount == 1 ? "1 sesión" : "\(sessionCount) sesiones")
        if totalDistanceKm > 0 {
            summaryParts.append(String(format: "%.1f km", totalDistanceKm))
        }
        if totalTimeHours > 0 {
            summaryParts.append(String(format: "%.1f h", totalTimeHours))
        }
        parts.append(summaryParts.joined(separator: ", ") + ".")
        
        let easyPaceMs = profile?.easyPaceMs ?? 0
        let easyTime = weekActivities.filter { easyPaceMs > 0 && $0.averageSpeed <= easyPaceMs * 1.02 }.reduce(0) { $0 + $1.movingTime }
        let totalTime = weekActivities.reduce(0) { $0 + $1.movingTime }
        let easyRatio = totalTime > 0 ? Double(easyTime) / Double(totalTime) : 0
        
        let hardSessions = weekActivities.filter { easyPaceMs > 0 && $0.averageSpeed > easyPaceMs * 1.08 }.count
        let sortedByDate = weekActivities.sorted { $0.startDate < $1.startDate }
        var consecutiveHard = 0
        var maxConsecutiveHard = 0
        for act in sortedByDate {
            if easyPaceMs > 0 && act.averageSpeed > easyPaceMs * 1.08 {
                consecutiveHard += 1
                maxConsecutiveHard = max(maxConsecutiveHard, consecutiveHard)
            } else {
                consecutiveHard = 0
            }
        }
        
        // Regularidad (no copiamos huecos globales en la narrativa de "esta semana")
        if let c = consistency {
            if c.consecutiveWeeks >= 4 {
                parts.append("Semana consistente.")
            } else if c.consecutiveWeeks == 0 {
                parts.append("Semana irregular.")
            }
        }
        
        // Huecos solo dentro de esta semana (entre sesiones de la misma semana)
        let calendar = Calendar.sportBoardMadrid
        if weekActivities.count >= 2 {
            let sorted = weekActivities.sorted { $0.startDate < $1.startDate }
            var gapInWeek = 0
            for i in 1..<sorted.count {
                let days = calendar.dateComponents([.day], from: sorted[i - 1].startDate, to: sorted[i].startDate).day ?? 0
                if days > 4 { gapInWeek += 1 }
            }
            if gapInWeek > 0 {
                parts.append("Hay un hueco de más de 4 días entre sesiones esta semana.")
            }
        }
        
        // Volumen fácil
        if easyRatio < 0.5 && totalTime > 3600 {
            parts.append("Poco volumen fácil.")
        } else if easyRatio >= 0.75 {
            parts.append("Buena proporción de rodaje fácil.")
        }
        
        // Sesiones exigentes / rodajes suaves (basado en ritmo vs ritmo cómodo del perfil)
        if hardSessions >= 2 && maxConsecutiveHard >= 2 {
            parts.append("Dos o más sesiones exigentes seguidas.")
        } else if hardSessions == 0 && weekActivities.count >= 2 {
            if easyPaceMs > 0 {
                parts.append("Solo rodajes suaves esta semana (ritmo ≤ ritmo cómodo + 8%).")
            } else {
                parts.append("Solo rodajes suaves esta semana.")
            }
        }
        
        // Eficiencia
        if let trend = efficiencyTrend, trend == .declining {
            parts.append("La eficiencia baja ligeramente.")
        }
        
        // Fatiga
        if let f = fatigue, f.level == .high {
            parts.append("Probablemente por fatiga acumulada.")
        } else if fatigue?.level == .medium {
            parts.append("Posible fatiga moderada.")
        }
        
        return parts.joined(separator: " ")
    }
    
    /// Esta semana = [Lunes 00:00 Madrid, siguiente Lunes 00:00 Madrid). Solo actividades Run.
    /// Se obtienen las actividades más recientes (orden descendente) y se filtran por rango para no perder las de esta semana.
    static func fetchThisWeekRuns(
        modelContext: ModelContext,
        dateProvider: DateProviding = SystemDateProvider(),
        calendar: Calendar = Calendar.sportBoardMadrid
    ) throws -> [Activity] {
        let now = dateProvider.now
        let weekStart = now.startOfWeek(using: calendar)
        let weekEnd = now.startOfNextWeek(using: calendar)
        var descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        descriptor.fetchLimit = 200
        let all = try modelContext.fetch(descriptor)
        let runTypes = ["run", "virtualrun", "trailrun"]
        return all.filter { runTypes.contains($0.sportType.lowercased()) && $0.startDate >= weekStart && $0.startDate < weekEnd }
    }
}

/// Dirección de tendencia de eficiencia (para narrativa y otros)
enum EfficiencyTrendDirection: String {
    case improving
    case stable
    case declining
}
