//
//  EfficiencyTrendService.swift
//  SportBoardApp
//
//  Tendencia de eficiencia real (no solo AE): ritmo normalizado, FC, deriva, variabilidad.
//  Salida: dirección, confianza, razones.
//

import Foundation
import SwiftData

/// Resultado de tendencia de eficiencia
struct EfficiencyTrendResult {
    var direction: EfficiencyTrendDirection
    var confidence: Double
    var reasons: [String]
}

/// Servicio que calcula tendencia de eficiencia desde historial local.
struct EfficiencyTrendService {
    
    private static let weeksToAnalyze = 6
    
    /// Calcula tendencia para actividades de carrera.
    static func compute(
        modelContext: ModelContext,
        profile: RunnerProfile?,
        fatigue: FatigueDiagnosis?
    ) throws -> EfficiencyTrendResult {
        let activities = try fetchRunActivities(modelContext: modelContext)
        return computeFromActivities(activities, profile: profile, fatigue: fatigue)
    }
    
    static func computeFromActivities(
        _ activities: [Activity],
        profile: RunnerProfile?,
        fatigue: FatigueDiagnosis?
    ) -> EfficiencyTrendResult {
        let now = Date()
        let calendar = Calendar.current
        let weekStart = now.startOfWeek
        var weeklyPaces: [Date: [Double]] = [:]
        var weeklyHR: [Date: [Double]] = [:]
        
        let runTypes = ["run", "virtualrun", "trailrun"]
        let runs = activities.filter { runTypes.contains($0.sportType.lowercased()) }
            .filter { $0.movingTime >= 15 * 60 && $0.averageSpeed > 0 }
        
        for i in 0..<Self.weeksToAnalyze {
            let wStart = calendar.date(byAdding: .weekOfYear, value: -i, to: weekStart) ?? weekStart
            let wEnd = calendar.date(byAdding: .day, value: 7, to: wStart) ?? wStart
            let inWeek = runs.filter { $0.startDate >= wStart && $0.startDate < wEnd }
            let paces = inWeek.map { 1000 / $0.averageSpeed }
            let hr = inWeek.compactMap(\.averageHeartrate)
            if !paces.isEmpty { weeklyPaces[wStart] = paces }
            if !hr.isEmpty { weeklyHR[wStart] = hr }
        }
        
        let sortedWeeks = weeklyPaces.keys.sorted()
        guard sortedWeeks.count >= 2 else {
            return EfficiencyTrendResult(
                direction: .stable,
                confidence: 0,
                reasons: ["Datos insuficientes para calcular tendencia"]
            )
        }
        
        var reasons: [String] = []
        var improvingScore = 0
        var decliningScore = 0
        
        // Comparar semanas recientes vs anteriores (ritmo en rodajes "fáciles")
        let recentWeeks = Array(sortedWeeks.suffix(2))
        let olderWeeks = Array(sortedWeeks.prefix(sortedWeeks.count - 2))
        var recentMedianPace: Double?
        var olderMedianPace: Double?
        if let r = recentWeeks.last, let paces = weeklyPaces[r], !paces.isEmpty {
            recentMedianPace = median(paces)
        }
        if let o = olderWeeks.last, let paces = weeklyPaces[o], !paces.isEmpty {
            olderMedianPace = median(paces)
        }
        if let rec = recentMedianPace, let old = olderMedianPace, old > 0 {
            let change = (rec - old) / old
            if change < -0.03 {
                improvingScore += 2
                reasons.append("Ritmo en rodajes mejorando")
            } else if change > 0.03 {
                decliningScore += 2
                reasons.append("Ritmo en rodajes más lento")
            }
        }
        
        // FC: si sube en mismas condiciones → empeorando
        if let r = recentWeeks.last, let o = olderWeeks.last,
           let hrR = weeklyHR[r], let hrO = weeklyHR[o],
           !hrR.isEmpty, !hrO.isEmpty {
            let avgHRRecent = hrR.reduce(0, +) / Double(hrR.count)
            let avgHROlder = hrO.reduce(0, +) / Double(hrO.count)
            if avgHRRecent > avgHROlder + 3 {
                decliningScore += 1
                reasons.append("FC media más alta recientemente")
            }
        }
        
        // Contexto fatiga: si fatiga alta, no penalizar tendencia
        if fatigue?.level == .high {
            decliningScore = max(0, decliningScore - 1)
            reasons.append("Fatiga alta puede explicar bajada puntual")
        }
        
        let direction: EfficiencyTrendDirection
        if improvingScore > decliningScore {
            direction = .improving
        } else if decliningScore > improvingScore {
            direction = .declining
        } else {
            direction = .stable
        }
        
        let confidence = min(1.0, Double(sortedWeeks.count) / 4.0) * 0.8
        if reasons.isEmpty {
            reasons.append("Tendencia estable con los datos disponibles")
        }
        
        return EfficiencyTrendResult(
            direction: direction,
            confidence: confidence,
            reasons: reasons
        )
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
