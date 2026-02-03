//
//  FatigueService.swift
//  SportBoardApp
//
//  Indicador de fatiga acumulada explicable: nivel, causas y acción recomendada.
//  Factores: días consecutivos, carga reciente vs baseline, proporción duro, reflexión subjetiva (si existe).
//

import Foundation
import SwiftData

/// Nivel de fatiga
enum FatigueLevel: String, CaseIterable {
    case low
    case medium
    case high
    
    var displayName: String {
        switch self {
        case .low: return "Baja"
        case .medium: return "Moderada"
        case .high: return "Alta"
        }
    }
}

/// Resultado del diagnóstico de fatiga
struct FatigueDiagnosis {
    var level: FatigueLevel
    var causes: [String]
    var recommendedAction: String
}

/// Servicio que calcula fatiga acumulada desde historial local.
struct FatigueService {
    
    /// Días hacia atrás para analizar carga reciente
    private static let recentDays = 14
    
    /// Baseline: mediana de carga semanal en ventana larga
    private static let baselineWeeks = 8
    
    /// Máximo de días consecutivos sin descanso antes de penalizar
    private static let maxConsecutiveDays = 3
    
    /// Proporción de sesiones "duras" que se considera alta
    private static let hardRatioThreshold = 0.35
    
    /// Calcula diagnóstico de fatiga para actividades de carrera.
    static func compute(
        modelContext: ModelContext,
        profile: RunnerProfile?
    ) throws -> FatigueDiagnosis {
        let activities = try fetchRunActivities(modelContext: modelContext)
        let reflections = try modelContext.fetch(FetchDescriptor<PostActivityReflection>())
        return computeFromActivities(activities, profile: profile, reflections: reflections)
    }
    
    static func computeFromActivities(
        _ activities: [Activity],
        profile: RunnerProfile?,
        reflections: [PostActivityReflection] = []
    ) -> FatigueDiagnosis {
        let now = Date()
        let calendar = Calendar.current
        let recentStart = calendar.date(byAdding: .day, value: -Self.recentDays, to: now) ?? now
        let recent = activities.filter { $0.startDate >= recentStart }
        
        var causes: [String] = []
        var score = 0 // más alto = más fatiga
        
        // 1. Días consecutivos entrenando
        let sortedByDate = recent.sorted { $0.startDate < $1.startDate }
        var maxConsecutive = 0
        var currentConsecutive = 0
        var previousDay: Date?
        for act in sortedByDate {
            let day = calendar.startOfDay(for: act.startDate)
            if let prev = previousDay {
                let diff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if diff == 0 { continue }
                if diff == 1 {
                    currentConsecutive += 1
                } else {
                    maxConsecutive = max(maxConsecutive, currentConsecutive)
                    currentConsecutive = 1
                }
            } else {
                currentConsecutive = 1
            }
            previousDay = day
        }
        maxConsecutive = max(maxConsecutive, currentConsecutive)
        if maxConsecutive >= Self.maxConsecutiveDays {
            score += 25
            causes.append("\(maxConsecutive) días seguidos entrenando")
        }
        
        // 2. Carga reciente vs baseline
        let recentLoad = recent.reduce(0.0) { $0 + Double($1.movingTime) / 3600 }
        let byWeek = Dictionary(grouping: activities) { $0.startDate.startOfWeek }
        let weeklyLoads = byWeek.mapValues { acts in
            acts.reduce(0.0) { $0 + Double($1.movingTime) / 3600 }
        }
        let sortedLoads = Array(weeklyLoads.values).sorted()
        let baseline = median(sortedLoads) ?? recentLoad / 2
        if baseline > 0 && recentLoad > baseline * 1.4 {
            score += 20
            causes.append("Carga reciente muy por encima de tu media")
        }
        
        // 3. Proporción de sesiones duras
        let easyPaceMs = profile?.easyPaceMs ?? 0
        var hardCount = 0
        for act in recent {
            if easyPaceMs > 0 && act.averageSpeed > easyPaceMs * 1.08 {
                hardCount += 1
            } else if easyPaceMs == 0 {
                hardCount += 1 // sin perfil, no clasificamos
            }
        }
        let hardRatio = recent.isEmpty ? 0 : Double(hardCount) / Double(recent.count)
        if hardRatio > Self.hardRatioThreshold {
            score += 20
            causes.append("Muchas sesiones exigentes recientes")
        }
        
        // 4. Poco volumen fácil
        let easyTime = recent.filter { act in
            easyPaceMs > 0 && act.averageSpeed <= easyPaceMs * 1.02
        }.reduce(0) { $0 + $1.movingTime }
        let totalTime = recent.reduce(0) { $0 + $1.movingTime }
        let easyRatio = totalTime > 0 ? Double(easyTime) / Double(totalTime) : 0.5
        if easyRatio < 0.5 && totalTime > 3600 {
            score += 15
            causes.append("Poco volumen fácil en los últimos días")
        }
        
        // 5. Reflexión subjetiva (si existe)
        let recentReflections = reflections.filter { r in
            calendar.isDate(r.date, inSameDayAs: now) || r.date < now
        }
        let pushedTooMuch = recentReflections.filter { $0.pushedTooHard }.count
        let lowFeeling = recentReflections.filter { $0.feelingScore <= 2 }.count
        if pushedTooMuch > 0 {
            score += 15
            causes.append("Has indicado que forzaste de más recientemente")
        }
        if lowFeeling > 0 {
            score += 10
            causes.append("Sensación baja en sesiones recientes")
        }
        
        // Nivel y acción
        let level: FatigueLevel
        if score >= 55 {
            level = .high
        } else if score >= 30 {
            level = .medium
        } else {
            level = .low
        }
        
        let action: String
        switch level {
        case .high:
            action = "Descanso o solo rodaje muy suave. Evita sesiones duras hasta que baje la fatiga."
        case .medium:
            action = "Prioriza rodajes fáciles y evita acumular días seguidos sin descanso."
        case .low:
            action = "Mantén la progresión sin forzar. Incluye suficiente volumen fácil."
        }
        
        if causes.isEmpty {
            causes.append("Sin señales claras de fatiga acumulada")
        }
        
        return FatigueDiagnosis(
            level: level,
            causes: causes,
            recommendedAction: action
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
