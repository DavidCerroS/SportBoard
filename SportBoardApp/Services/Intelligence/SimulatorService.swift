//
//  SimulatorService.swift
//  SportBoardApp
//
//  Simulación cualitativa "qué pasa si…": días/semana, ± volumen, nº sesiones duras.
//  Outputs: impacto en consistencia, riesgo estimado, tendencia esperada.
//

import Foundation
import SwiftData

/// Inputs del simulador
struct SimulatorInput {
    var daysPerWeek: Int
    var volumeChangePercent: Double  // ej. -10 = bajar 10%
    var hardSessionsPerWeek: Int
}

/// Resultado cualitativo del simulador
struct SimulatorResult {
    var consistencyImpact: String   // "mejor", "igual", "peor"
    var riskLevel: String           // "bajo", "medio", "alto"
    var trendExpectation: String    // "mejorando", "estable", "empeorando"
    var reasons: [String]
}

/// Servicio que simula impacto de cambios en días, volumen y sesiones duras.
struct SimulatorService {
    
    /// Simula escenario y devuelve impacto cualitativo.
    static func simulate(
        currentDaysPerWeek: Int,
        currentVolumeHoursPerWeek: Double,
        currentHardSessionsPerWeek: Int,
        input: SimulatorInput
    ) -> SimulatorResult {
        let newDays = input.daysPerWeek
        let newVolume = currentVolumeHoursPerWeek * (1 + input.volumeChangePercent / 100)
        let newHard = input.hardSessionsPerWeek
        
        var reasons: [String] = []
        var consistencyImpact = "igual"
        var riskLevel = "bajo"
        var trendExpectation = "estable"
        
        // Consistencia: más días suele mejorar; menos días empeorar
        if newDays > currentDaysPerWeek {
            consistencyImpact = "mejor"
            reasons.append("Más días de entreno suele mejorar la consistencia.")
        } else if newDays < currentDaysPerWeek && newDays < 3 {
            consistencyImpact = "peor"
            reasons.append("Menos de 3 días puede bajar la consistencia.")
        }
        
        // Riesgo: volumen muy alto o muchas duras
        if newVolume > currentVolumeHoursPerWeek * 1.2 {
            riskLevel = "medio"
            reasons.append("Subir mucho el volumen aumenta el riesgo de lesión.")
        }
        if newHard >= 3 && newDays <= 4 {
            riskLevel = riskLevel == "medio" ? "alto" : "medio"
            reasons.append("Varias sesiones duras con pocos días puede acumular fatiga.")
        }
        if newHard > newDays - 1 {
            riskLevel = "alto"
            reasons.append("Demasiadas sesiones exigentes respecto a días disponibles.")
        }
        
        // Tendencia: equilibrio volumen / recuperación
        if riskLevel == "alto" {
            trendExpectation = "empeorando"
        } else if consistencyImpact == "mejor" && riskLevel == "bajo" {
            trendExpectation = "mejorando"
        }
        
        if reasons.isEmpty {
            reasons.append("Escenario razonable. Sin cambios drásticos.")
        }
        
        return SimulatorResult(
            consistencyImpact: consistencyImpact,
            riskLevel: riskLevel,
            trendExpectation: trendExpectation,
            reasons: reasons
        )
    }
    
    /// Obtiene valores actuales desde el contexto (para comparar con simulación).
    static func currentMetrics(modelContext: ModelContext) throws -> (daysPerWeek: Int, volumeHoursPerWeek: Double, hardSessionsPerWeek: Int) {
        let weekStart = Date().startOfWeek
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let all = try modelContext.fetch(descriptor)
        let runTypes = ["run", "virtualrun", "trailrun"]
        let runs = all.filter { runTypes.contains($0.sportType.lowercased()) }
        let profile = try RunnerProfileService.fetchProfile(modelContext: modelContext)
        let easyPaceMs = profile?.easyPaceMs ?? 0
        
        let inWeek = runs.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
        let days = Set(inWeek.map { calendar.startOfDay(for: $0.startDate) }).count
        let volumeHours = inWeek.reduce(0.0) { $0 + Double($1.movingTime) / 3600 }
        let hardCount = easyPaceMs > 0 ? inWeek.filter { $0.averageSpeed > easyPaceMs * 1.08 }.count : 0
        
        return (days, volumeHours, hardCount)
    }
}
