//
//  SilentAlertsService.swift
//  SportBoardApp
//
//  Avisos solo cuando importa: riesgo de lesión, tendencia negativa persistente, semana rota (poco fácil).
//  Solo aparecen al entrar en la app; nunca push por defecto.
//

import Foundation
import SwiftData

/// Una alerta silenciosa (solo en app)
struct SilentAlert {
    var id: String
    var title: String
    var message: String
    var severity: AlertSeverity
}

enum AlertSeverity {
    case info
    case warning
    case high
}

/// Servicio que evalúa alertas al abrir la app.
struct SilentAlertsService {
    
    private static let recentWeeksForLoad = 4
    private static let loadSpikeFactor = 1.5
    private static let decliningWeeksThreshold = 2
    private static let easyRatioWeekBroken = 0.4
    
    /// Evalúa todas las reglas y devuelve alertas a mostrar (solo en app).
    static func evaluate(
        modelContext: ModelContext,
        profile: RunnerProfile?,
        efficiencyTrend: EfficiencyTrendResult?,
        consistency: ConsistencyBreakdown?,
        fatigue: FatigueDiagnosis?
    ) throws -> [SilentAlert] {
        var alerts: [SilentAlert] = []
        let activities = try fetchRunActivities(modelContext: modelContext)
        
        // 1. Pico de carga (riesgo lesión)
        let loadAlert = evaluateLoadSpike(activities: activities)
        if let a = loadAlert { alerts.append(a) }
        
        // 2. Tendencia negativa persistente
        if let trend = efficiencyTrend, trend.direction == .declining, trend.confidence >= 0.5 {
            alerts.append(SilentAlert(
                id: "trend_declining",
                title: "Tendencia de eficiencia",
                message: "La eficiencia va a la baja en las últimas semanas. \(trend.reasons.first ?? "")",
                severity: .warning
            ))
        }
        
        // 3. Semana "rota" (poco volumen fácil)
        let weekAlert = evaluateWeekBroken(activities: activities, profile: profile)
        if let a = weekAlert { alerts.append(a) }
        
        // 4. Fatiga alta
        if let f = fatigue, f.level == .high {
            alerts.append(SilentAlert(
                id: "fatigue_high",
                title: "Fatiga acumulada",
                message: "\(f.causes.prefix(2).joined(separator: ". ")). \(f.recommendedAction)",
                severity: .warning
            ))
        }
        
        return alerts
    }
    
    private static func evaluateLoadSpike(activities: [Activity]) -> SilentAlert? {
        let now = Date()
        let calendar = Calendar.current
        let weekStart = now.startOfWeek
        var weeklyLoad: [Date: Double] = [:]
        let runTypes = ["run", "virtualrun", "trailrun"]
        let runs = activities.filter { runTypes.contains($0.sportType.lowercased()) }
        
        for i in 0..<Self.recentWeeksForLoad {
            let wStart = calendar.date(byAdding: .weekOfYear, value: -i, to: weekStart) ?? weekStart
            let wEnd = calendar.date(byAdding: .day, value: 7, to: wStart) ?? wStart
            let inWeek = runs.filter { $0.startDate >= wStart && $0.startDate < wEnd }
            let hours = inWeek.reduce(0.0) { $0 + Double($1.movingTime) / 3600 }
            weeklyLoad[wStart] = hours
        }
        let current = weeklyLoad[weekStart] ?? 0
        let previousWeeksLoads = (0..<Self.recentWeeksForLoad)
            .compactMap { i -> Date? in calendar.date(byAdding: .weekOfYear, value: -i - 1, to: weekStart) }
            .compactMap { weeklyLoad[$0] }
        guard !previousWeeksLoads.isEmpty else { return nil }
        let baseline = previousWeeksLoads.reduce(0, +) / Double(previousWeeksLoads.count)
        if baseline > 0 && current > baseline * Self.loadSpikeFactor {
            return SilentAlert(
                id: "load_spike",
                title: "Carga elevada",
                message: "Esta semana la carga es notablemente mayor que tu media reciente. Considera no subir más el volumen.",
                severity: .warning
            )
        }
        return nil
    }
    
    private static func evaluateWeekBroken(activities: [Activity], profile: RunnerProfile?) -> SilentAlert? {
        let weekStart = Date().startOfWeek
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let runTypes = ["run", "virtualrun", "trailrun"]
        let runs = activities.filter { runTypes.contains($0.sportType.lowercased()) }
            .filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
        guard runs.count >= 2 else { return nil }
        let easyPaceMs = profile?.easyPaceMs ?? 0
        guard easyPaceMs > 0 else { return nil }
        let easyTime = runs.filter { $0.averageSpeed <= easyPaceMs * 1.02 }.reduce(0) { $0 + $1.movingTime }
        let totalTime = runs.reduce(0) { $0 + $1.movingTime }
        let easyRatio = Double(easyTime) / Double(totalTime)
        if easyRatio < Self.easyRatioWeekBroken {
            return SilentAlert(
                id: "week_broken",
                title: "Semana con poco fácil",
                message: "Esta semana hay poca proporción de volumen fácil. Prioriza rodajes suaves en los próximos días.",
                severity: .info
            )
        }
        return nil
    }
    
    private static func fetchRunActivities(modelContext: ModelContext) throws -> [Activity] {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        let all = try modelContext.fetch(descriptor)
        let runTypes = ["run", "virtualrun", "trailrun"]
        return all.filter { runTypes.contains($0.sportType.lowercased()) }
    }
}
