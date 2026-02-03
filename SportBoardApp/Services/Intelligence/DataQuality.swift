//
//  DataQuality.swift
//  SportBoardApp
//
//  Capa que determina qué métricas se pueden calcular con fiabilidad para una actividad.
//  Evita métricas falsas, NaNs silenciosos y conclusiones erróneas.
//

import Foundation

/// Calidad de datos de una actividad. Todas las métricas de inteligencia deben consultar esta capa antes de calcularse.
struct DataQuality {
    var hasHeartrate: Bool
    var hasSplits: Bool
    var hasEnoughDuration: Bool
    var hasEnoughDistance: Bool
    var isRun: Bool
    
    /// Razones por las que no se puede calcular algo (para tooltips en UI)
    var missingReasons: [String] {
        var reasons: [String] = []
        if !hasHeartrate { reasons.append("No hay datos de frecuencia cardíaca") }
        if !hasSplits { reasons.append("No hay splits por kilómetro") }
        if !hasEnoughDuration { reasons.append("Duración insuficiente para análisis") }
        if !hasEnoughDistance { reasons.append("Distancia insuficiente para análisis") }
        if !isRun { reasons.append("Solo aplicable a actividades de carrera") }
        return reasons
    }
    
    /// Si se pueden calcular métricas que requieren FC (ej. detector de rodaje mal ejecutado por FC)
    var canUseHeartrateMetrics: Bool { hasHeartrate && isRun }
    
    /// Si se pueden calcular métricas que requieren splits (deriva, variabilidad intra-sesión)
    var canUseSplitMetrics: Bool { hasSplits && hasEnoughDistance && isRun }
    
    /// Si se puede clasificar la sesión (run + duración/distancia mínima)
    var canClassify: Bool { isRun && (hasEnoughDuration || hasEnoughDistance) }
    
    /// Mensaje para tooltip cuando no se puede calcular una métrica
    func tooltipMessage(for metric: String) -> String? {
        let relevant = missingReasons.filter { reason in
            switch metric.lowercased() {
            case "heartrate", "fc", "deriva": return reason.contains("frecuencia") || reason.contains("splits")
            case "consistency", "clasificación": return reason.contains("carrera") || reason.contains("Duración")
            default: return true
            }
        }
        guard !relevant.isEmpty else { return nil }
        return "No se puede calcular \(metric): \(relevant.joined(separator: "; "))."
    }
}

// MARK: - Evaluation

extension DataQuality {
    
    /// Umbral mínimo de duración para considerar una sesión analizable (segundos)
    private static let minDurationSeconds = 10 * 60 // 10 min
    
    /// Umbral mínimo de distancia para análisis con splits (metros)
    private static let minDistanceMeters = 1000.0 // 1 km
    
    /// Tipos de deporte considerados "carrera" para análisis
    private static let runSportTypes: Set<String> = ["run", "virtualrun", "trailrun"]
    
    /// Evalúa la calidad de datos de una actividad
    static func evaluate(activity: Activity, splits: [ActivitySplit]? = nil) -> DataQuality {
        let hasHR = activity.hasHeartrate && activity.averageHeartrate != nil
        let splitsToUse = splits ?? activity.sortedSplits
        let hasSplits = (splitsToUse?.isEmpty == false) && (splitsToUse?.count ?? 0) >= 2
        let hasDuration = activity.movingTime >= minDurationSeconds
        let hasDistance = activity.distance >= minDistanceMeters
        let isRun = Self.runSportTypes.contains(activity.sportType.lowercased())
        
        return DataQuality(
            hasHeartrate: hasHR,
            hasSplits: hasSplits,
            hasEnoughDuration: hasDuration,
            hasEnoughDistance: hasDistance,
            isRun: isRun
        )
    }
}
