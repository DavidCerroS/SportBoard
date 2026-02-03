//
//  ConsistencyService.swift
//  SportBoardApp
//
//  Métrica de regularidad (no volumen): semanas consecutivas, huecos, variabilidad, ratio fácil/duro.
//  Salida: score 0–100 y desglose explicable.
//

import Foundation
import SwiftData

/// Componentes del score de consistencia (explicables)
struct ConsistencyBreakdown {
    var consecutiveWeeks: Int
    var gapsOver4Days: Int
    var weeklyLoadVariation: Double // coeficiente de variación (0 = estable)
    var easyHardDeviation: Double   // desviación del ratio fácil vs objetivo (ej. 0.8)
    var score: Int // 0–100
    var reasons: [String]
}

/// Servicio que calcula consistencia real desde actividades locales.
struct ConsistencyService {
    
    /// Ventana de análisis (semanas)
    private static let analysisWeeks = 12
    
    /// Hueco "grande" en días (sin entrenar)
    private static let gapThresholdDays = 4
    
    /// Ratio fácil objetivo (ej. 80% del tiempo en fácil)
    private static let targetEasyRatio = 0.75
    
    /// Calcula consistencia para actividades de carrera en el contexto.
    static func compute(
        modelContext: ModelContext,
        profile: RunnerProfile?,
        sportType: String = "Run"
    ) throws -> ConsistencyBreakdown {
        let activities = try fetchRunActivities(modelContext: modelContext, sportType: sportType)
        return computeFromActivities(activities, profile: profile)
    }
    
    static func computeFromActivities(
        _ activities: [Activity],
        profile: RunnerProfile?
    ) -> ConsistencyBreakdown {
        let now = Date()
        let calendar = Calendar.sportBoardMadrid
        let weekStart = now.startOfWeekMadrid
        var weeksWithActivity: Set<Date> = []
        var weekLoads: [Date: Double] = [:]
        var gapsOver4 = 0
        var easyTime = 0
        var totalTime = 0
        
        let easyPaceMs = profile?.easyPaceMs ?? 0
        // Solo considerar actividades en la ventana de análisis (ej. últimas 12 semanas)
        let windowStart = calendar.date(byAdding: .weekOfYear, value: -Self.analysisWeeks, to: weekStart) ?? weekStart
        let activitiesInWindow = activities.filter { $0.startDate >= windowStart }
        let sortedByDate = activitiesInWindow.sorted { $0.startDate < $1.startDate }
        
        for i in 0..<sortedByDate.count {
            let act = sortedByDate[i]
            let start = act.startDate
            let week = start.startOfWeekMadrid
            weeksWithActivity.insert(week)
            let load = Double(act.movingTime) / 3600.0 // horas
            weekLoads[week, default: 0] += load
            
            totalTime += act.movingTime
            if easyPaceMs > 0 && act.averageSpeed <= easyPaceMs * 1.02 {
                easyTime += act.movingTime
            }
            
            // Huecos solo entre sesiones consecutivas dentro de la ventana reciente
            if i > 0 {
                let prev = sortedByDate[i - 1].startDate
                let days = calendar.dateComponents([.day], from: prev, to: start).day ?? 0
                if days > Self.gapThresholdDays {
                    gapsOver4 += 1
                }
            }
        }
        
        // Racha: semanas consecutivas hacia atrás con >=1 Run. Si hay actividad esta semana, desde esta; si no, desde la última semana con actividad.
        var consecutiveWeeks = 0
        var startWeekForStreak = weekStart
        if !weeksWithActivity.contains(weekStart) {
            let sortedWeeks = weeksWithActivity.sorted(by: >)
            if let lastWithActivity = sortedWeeks.first {
                startWeekForStreak = lastWithActivity
            }
        }
        var current = startWeekForStreak
        for _ in 0..<Self.analysisWeeks {
            if weeksWithActivity.contains(current) {
                consecutiveWeeks += 1
            } else {
                break
            }
            current = calendar.date(byAdding: .weekOfYear, value: -1, to: current) ?? current
        }
        
        // Variación de carga semanal (CV) — solo semanas con actividad en ventana
        let loads = Array(weekLoads.values)
        let weeklyVariation = coefficientOfVariation(loads)
        
        // Ratio fácil/duro (solo ventana)
        let easyRatio = totalTime > 0 ? Double(easyTime) / Double(totalTime) : 0.5
        let easyHardDeviation = abs(easyRatio - Self.targetEasyRatio)
        
        // Score 0–100 (heurístico)
        var score = 70
        var reasons: [String] = []
        
        if consecutiveWeeks >= 4 {
            score += min(15, consecutiveWeeks)
            reasons.append("Racha: \(consecutiveWeeks) semanas")
        } else if consecutiveWeeks > 0 {
            reasons.append("Racha: \(consecutiveWeeks) semanas")
        } else {
            score -= 20
            reasons.append("Sin racha reciente")
        }
        
        if gapsOver4 == 0 {
            score += 5
            reasons.append("Sin huecos largos sin entrenar")
        } else {
            score -= min(15, gapsOver4 * 5)
            reasons.append("\(gapsOver4) huecos de más de \(Self.gapThresholdDays) días")
        }
        
        if weeklyVariation < 0.4 {
            score += 5
            reasons.append("Carga semanal estable")
        } else if weeklyVariation > 0.8 {
            score -= 10
            reasons.append("Carga semanal muy variable")
        }
        
        if easyHardDeviation <= 0.15 {
            score += 5
            reasons.append("Buena proporción fácil/duro")
        } else if easyHardDeviation > 0.3 {
            score -= 10
            reasons.append("Proporción fácil/duro desviada")
        }
        
        score = max(0, min(100, score))
        
        return ConsistencyBreakdown(
            consecutiveWeeks: consecutiveWeeks,
            gapsOver4Days: gapsOver4,
            weeklyLoadVariation: weeklyVariation,
            easyHardDeviation: easyHardDeviation,
            score: score,
            reasons: reasons
        )
    }
    
    private static func fetchRunActivities(modelContext: ModelContext, sportType: String) throws -> [Activity] {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        descriptor.fetchLimit = 500
        let all = try modelContext.fetch(descriptor)
        let runTypes = ["run", "virtualrun", "trailrun"]
        return all.filter { runTypes.contains($0.sportType.lowercased()) }
    }
    
    private static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let std = sqrt(variance)
        return mean > 0 ? std / mean : 0
    }
}
