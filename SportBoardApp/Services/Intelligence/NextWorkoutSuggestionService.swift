//
//  NextWorkoutSuggestionService.swift
//  SportBoardApp
//
//  Sugerencia del próximo entrenamiento (no plan rígido).
//  Reglas: fatiga alta → fácil; muchas duras → recuperación; huecos → moderado; ratio desviado → compensar.
//

import Foundation
import SwiftData

/// Sugerencia de próximo entreno
struct NextWorkoutSuggestion {
    var type: String       // "Rodaje Z2", "Recuperación", "Rodaje moderado", etc.
    var durationMin: Int   // minutos sugeridos (rango: durationMin–durationMax)
    var durationMax: Int
    var intensity: String  // "fácil", "moderado", "exigente"
    var reason: String
    var fullText: String
}

/// Servicio que sugiere el próximo entrenamiento.
/// Sin Goal/RaceEvent en datos: "Modo mantenimiento" (solo rodaje Z2 o descanso según fatiga/huecos).
struct NextWorkoutSuggestionService {
    
    private static let recentDays = 7
    private static let gapThresholdDays = 2
    
    /// Prefijo cuando no hay objetivo de carrera definido.
    private static let maintenancePrefix = "Modo mantenimiento. "
    
    /// Genera sugerencia para carrera.
    static func suggest(
        modelContext: ModelContext,
        profile: RunnerProfile?,
        fatigue: FatigueDiagnosis?,
        consistency: ConsistencyBreakdown?
    ) throws -> NextWorkoutSuggestion? {
        let activities = try fetchRecentRuns(modelContext: modelContext)
        return suggestFromActivities(
            recentActivities: activities,
            profile: profile,
            fatigue: fatigue,
            consistency: consistency
        )
    }
    
    static func suggestFromActivities(
        recentActivities: [Activity],
        profile: RunnerProfile?,
        fatigue: FatigueDiagnosis?,
        consistency: ConsistencyBreakdown?
    ) -> NextWorkoutSuggestion? {
        let now = Date()
        let calendar = Calendar.current
        let recentStart = calendar.date(byAdding: .day, value: -Self.recentDays, to: now) ?? now
        let recent = recentActivities.filter { $0.startDate >= recentStart }.sorted { $0.startDate > $1.startDate }
        
        let easyPaceMs = profile?.easyPaceMs ?? 0
        let hardCount = recent.filter { easyPaceMs > 0 && $0.averageSpeed > easyPaceMs * 1.08 }.count
        let easyTime = recent.filter { easyPaceMs > 0 && $0.averageSpeed <= easyPaceMs * 1.02 }.reduce(0) { $0 + $1.movingTime }
        let totalTime = recent.reduce(0) { $0 + $1.movingTime }
        let easyRatio = totalTime > 0 ? Double(easyTime) / Double(totalTime) : 0.5
        
        var daysSinceLastRun = 0
        if let last = recent.first {
            daysSinceLastRun = calendar.dateComponents([.day], from: last.startDate, to: now).day ?? 0
        }
        
        let fatigueHigh = fatigue?.level == .high
        let fatigueMedium = fatigue?.level == .medium
        let manyHardSessions = hardCount >= 2
        let lowEasyRatio = easyRatio < 0.5
        let longGap = daysSinceLastRun >= Self.gapThresholdDays
        let veryLongGap = daysSinceLastRun >= 5
        
        if fatigueHigh || manyHardSessions {
            return NextWorkoutSuggestion(
                type: "Rodaje Z2",
                durationMin: 35,
                durationMax: 50,
                intensity: "fácil",
                reason: Self.maintenancePrefix + (fatigueHigh ? "Fatiga acumulada alta." : "Dos o más sesiones exigentes recientes."),
                fullText: Self.maintenancePrefix + "Rodaje 35–50' en Z2, terreno llano. Motivo: \(fatigueHigh ? "fatiga acumulada" : "varias sesiones intensas recientes"). Prioriza recuperación."
            )
        }
        
        if fatigueMedium && lowEasyRatio {
            return NextWorkoutSuggestion(
                type: "Rodaje fácil",
                durationMin: 40,
                durationMax: 55,
                intensity: "fácil",
                reason: Self.maintenancePrefix + "Fatiga moderada y poca proporción fácil reciente.",
                fullText: Self.maintenancePrefix + "Rodaje 40–55' fácil, terreno llano. Motivo: fatiga moderada y baja proporción de volumen fácil."
            )
        }
        
        if veryLongGap {
            return NextWorkoutSuggestion(
                type: "Rodaje moderado",
                durationMin: 35,
                durationMax: 50,
                intensity: "moderado",
                reason: Self.maintenancePrefix + "Varios días sin entrenar. Volver con calma.",
                fullText: Self.maintenancePrefix + "Rodaje 35–50' a ritmo moderado. Motivo: varios días sin entrenar; no forzar."
            )
        }
        
        if longGap && recent.isEmpty == false {
            return NextWorkoutSuggestion(
                type: "Rodaje Z2",
                durationMin: 40,
                durationMax: 60,
                intensity: "fácil",
                reason: Self.maintenancePrefix + "Un par de días sin entrenar. Rodaje cómodo.",
                fullText: Self.maintenancePrefix + "Rodaje 40–60' en Z2. Motivo: retomar con volumen fácil."
            )
        }
        
        if lowEasyRatio && !manyHardSessions {
            return NextWorkoutSuggestion(
                type: "Rodaje fácil",
                durationMin: 45,
                durationMax: 60,
                intensity: "fácil",
                reason: Self.maintenancePrefix + "Proporción fácil/duro desviada. Compensar con volumen fácil.",
                fullText: Self.maintenancePrefix + "Rodaje 45–60' fácil. Motivo: compensar proporción fácil/duro."
            )
        }
        
        return NextWorkoutSuggestion(
            type: "Rodaje Z2",
            durationMin: 40,
            durationMax: 55,
            intensity: "fácil",
            reason: Self.maintenancePrefix + "Mantener base. Rodaje cómodo.",
            fullText: Self.maintenancePrefix + "Rodaje 40–55' en Z2, terreno llano. Motivo: mantener base y consistencia."
        )
    }
    
    private static func fetchRecentRuns(modelContext: ModelContext) throws -> [Activity] {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let all = try modelContext.fetch(descriptor)
        let runTypes = ["run", "virtualrun", "trailrun"]
        return all.filter { runTypes.contains($0.sportType.lowercased()) }
    }
}
