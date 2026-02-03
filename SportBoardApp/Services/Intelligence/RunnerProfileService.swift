//
//  RunnerProfileService.swift
//  SportBoardApp
//
//  Calcula y persiste el perfil de corredor desde histórico local.
//  Rodajes estables → ritmo fácil; mejores esfuerzos 20–60' → umbral; agrupación semanal → variabilidad.
//

import Foundation
import SwiftData

/// Servicio que calcula el RunnerProfile desde actividades ya sincronizadas.
struct RunnerProfileService {
    
    /// Deporte por defecto para el perfil
    private static let runSportType = "Run"
    
    /// Mínimo de actividades de carrera para calcular perfil
    private static let minRunActivities = 5
    
    /// Duración mínima para considerar "rodaje estable" (minutos)
    private static let minEasyDurationMin = 25.0
    
    /// Ventana típica para esfuerzo umbral (minutos)
    private static let thresholdDurationMinLow = 20.0
    private static let thresholdDurationMinHigh = 65.0
    
    /// Recalcular perfil si han pasado más de estos días
    static let recomputeIntervalDays = 7
    
    /// Calcula el perfil y lo guarda en el contexto. Usar desde MainActor o pasar context.
    static func computeAndSave(modelContext: ModelContext) throws {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        let allActivities = try modelContext.fetch(descriptor)
        let activities = allActivities.filter { $0.sportType.lowercased() == "run" }
        
        guard activities.count >= minRunActivities else {
            try deleteExistingProfile(modelContext: modelContext)
            return
        }
        
        let (easyPaceMs, threshMs, weeklyVar, easyHardRatio, confidence) = computeFromActivities(activities)
        
        try deleteExistingProfile(modelContext: modelContext)
        
        let profile = RunnerProfile(
            easyPaceMs: easyPaceMs,
            thresholdPaceMs: threshMs,
            weeklyVariability: weeklyVar,
            easyHardRatio: easyHardRatio,
            confidence: confidence,
            lastComputedAt: Date(),
            sportType: Self.runSportType
        )
        modelContext.insert(profile)
        try modelContext.save()
    }
    
    /// Obtiene el perfil existente (si hay)
    static func fetchProfile(modelContext: ModelContext) throws -> RunnerProfile? {
        let descriptors = try modelContext.fetch(FetchDescriptor<RunnerProfile>())
        return descriptors.first { $0.sportType.lowercased() == "run" }
    }
    
    /// Indica si conviene recalcular (han pasado X días o no hay perfil)
    static func shouldRecompute(modelContext: ModelContext) throws -> Bool {
        guard let profile = try fetchProfile(modelContext: modelContext) else { return true }
        let days = Calendar.current.dateComponents([.day], from: profile.lastComputedAt, to: Date()).day ?? 0
        return days >= recomputeIntervalDays
    }
    
    private static func deleteExistingProfile(modelContext: ModelContext) throws {
        let existing = try modelContext.fetch(FetchDescriptor<RunnerProfile>())
        for p in existing {
            modelContext.delete(p)
        }
        try modelContext.save()
    }
    
    private static func computeFromActivities(_ activities: [Activity]) -> (easyPaceMs: Double, thresholdPaceMs: Double, weeklyVariability: Double, easyHardRatio: Double, confidence: Double) {
        let runs = activities.filter { $0.sportType == Self.runSportType && $0.movingTime >= 10 * 60 && $0.averageSpeed > 0 }
        
        // Ritmo fácil: mediana de ritmos de rodajes "estables" (duración 25–90 min, ritmo no extremo)
        let easyCandidates = runs.filter { act in
            let min = Double(act.movingTime) / 60
            return min >= minEasyDurationMin && min <= 95 && act.averageSpeed > 0 && act.averageSpeed < 5.0
        }
        let easyPaces = easyCandidates.map(\.averageSpeed)
        let easyPaceMs = median(easyPaces) ?? 0
        
        // Umbral: mejor ritmo sostenido en ventana 20–65 min (equivalente a 5k–medio maratón esfuerzo)
        var bestPaceMs: Double = 0
        for act in runs {
            let min = Double(act.movingTime) / 60
            guard min >= thresholdDurationMinLow && min <= thresholdDurationMinHigh else { continue }
            if act.averageSpeed > bestPaceMs {
                bestPaceMs = act.averageSpeed
            }
        }
        let thresholdPaceMs = bestPaceMs > 0 ? bestPaceMs : easyPaceMs * 0.85
        
        // Variabilidad semanal: CV de volumen (km) por semana
        let byWeek = Dictionary(grouping: runs) { $0.startDate.startOfWeek }
        let weeklyKm = byWeek.mapValues { $0.reduce(0.0) { $0 + $1.distance / 1000 } }
        let volumes = Array(weeklyKm.values)
        let weeklyVariability = coefficientOfVariation(volumes)
        
        // Ratio fácil/duro: aproximación por ritmo (sin FC) — sesiones más lentas que easyPace*1.05 = "fácil"
        let easyThreshold = easyPaceMs * 0.98
        var easyTime = 0
        var totalTime = 0
        for act in runs {
            totalTime += act.movingTime
            if act.averageSpeed <= easyThreshold {
                easyTime += act.movingTime
            }
        }
        let easyHardRatio = totalTime > 0 ? Double(easyTime) / Double(totalTime) : 0.5
        
        // Confianza: más datos y dispersión razonable = mayor confianza
        let n = runs.count
        let conf = min(1.0, Double(n) / 30.0) * (easyPaces.isEmpty ? 0.5 : 1.0)
        
        return (easyPaceMs, thresholdPaceMs, weeklyVariability, easyHardRatio, conf)
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
    
    private static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let std = sqrt(variance)
        return mean > 0 ? std / mean : 0
    }
}
