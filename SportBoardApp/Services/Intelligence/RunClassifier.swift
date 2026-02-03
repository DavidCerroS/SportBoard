//
//  RunClassifier.swift
//  SportBoardApp
//
//  Clasificador interno de sesiones de carrera, con explicación.
//  Desbloquea perfil, consistencia, fatiga, narrativa y sugerencias.
//

import Foundation

/// Tipo de sesión de carrera (explicable)
enum RunSessionType: String, CaseIterable {
    case recovery
    case easy
    case long
    case tempo
    case intervals
    case race
    case unknown
    
    var displayName: String {
        switch self {
        case .recovery: return "Recuperación"
        case .easy: return "Rodaje"
        case .long: return "Largo"
        case .tempo: return "Ritmo"
        case .intervals: return "Series"
        case .race: return "Carrera"
        case .unknown: return "Sin clasificar"
        }
    }
}

/// Resultado de clasificación con confianza y razones
struct RunClassification {
    var type: RunSessionType
    var confidence: Double // 0...1
    var reasons: [String]
    
    /// No mostrar clasificación si la confianza es baja
    static let minConfidenceToShow = 0.4
    
    var shouldShow: Bool {
        type != .unknown && confidence >= RunClassification.minConfidenceToShow
    }
}

// MARK: - RunClassifier

/// Clasifica una actividad de carrera en tipo de sesión usando reglas basadas en duración, ritmo, FC y variabilidad.
struct RunClassifier {
    
    /// Clasifica una actividad. Si no es carrera o datos insuficientes, retorna .unknown con razones.
    /// - Parameters:
    ///   - activity: Actividad a clasificar
    ///   - splits: Splits ya cargados (opcional)
    ///   - laps: Laps ya cargados (opcional)
    ///   - easyPaceMs: Ritmo cómodo histórico en m/s (opcional, del perfil)
    ///   - thresholdPaceMs: Ritmo umbral en m/s (opcional, del perfil)
    static func classify(
        activity: Activity,
        splits: [ActivitySplit]? = nil,
        laps: [ActivityLap]? = nil,
        easyPaceMs: Double? = nil,
        thresholdPaceMs: Double? = nil
    ) -> RunClassification {
        let quality = DataQuality.evaluate(activity: activity, splits: splits)
        guard quality.canClassify else {
            return RunClassification(
                type: .unknown,
                confidence: 0,
                reasons: quality.missingReasons
            )
        }
        
        let durationMin = Double(activity.movingTime) / 60
        let distanceKm = activity.distance / 1000
        let paceMs = activity.averageSpeed
        let paceSecPerKm = paceMs > 0 ? 1000 / paceMs : 0
        let hr = activity.averageHeartrate
        
        var reasons: [String] = []
        var candidates: [(RunSessionType, Double)] = []
        
        // Variabilidad de splits (ritmo errático → intervals o tempo)
        let splitVariability = Self.splitPaceVariability(splits: splits ?? activity.sortedSplits)
        let hasStructuredLaps = (laps ?? activity.sortedLaps).map { $0.count > 2 } ?? false
        
        // Laps estructurados (varios intervalos) → intervals
        if hasStructuredLaps {
            candidates.append((.intervals, 0.85))
            reasons.append("Varios intervalos marcados")
        }
        
        // Duración muy corta + ritmo muy rápido → race o intervals
        if durationMin < 25 && paceMs > 0 {
            if let th = thresholdPaceMs, th > 0, paceMs > th * 1.05 {
                candidates.append((.race, 0.7))
                reasons.append("Duración corta y ritmo por encima del umbral")
            } else if splitVariability > 0.15 {
                candidates.append((.intervals, 0.65))
                reasons.append("Duración corta con ritmo variable")
            }
        }
        
        // Largo: > 90 min o > 18 km típico
        if durationMin >= 85 || distanceKm >= 18 {
            let score: Double = durationMin >= 120 ? 0.9 : (durationMin >= 90 ? 0.8 : 0.6)
            candidates.append((.long, score))
            reasons.append("Duración o distancia de largo")
        }
        
        // Ritmo relativo al fácil/umbral (si tenemos perfil)
        if let easy = easyPaceMs, easy > 0, let th = thresholdPaceMs, th > 0 {
            if paceMs <= easy * 0.92 {
                candidates.append((.recovery, 0.75))
                reasons.append("Ritmo más lento que rodaje cómodo")
            } else if paceMs >= th * 0.95 && paceMs <= th * 1.08 {
                candidates.append((.tempo, 0.7))
                reasons.append("Ritmo en zona de umbral")
            } else if paceMs > th * 1.1 {
                if durationMin < 40 {
                    candidates.append((.race, 0.65))
                    reasons.append("Ritmo muy por encima del umbral en sesión corta")
                } else {
                    candidates.append((.intervals, 0.5))
                }
            } else if paceMs > easy && paceMs < th * 0.92 {
                if durationMin >= 45 {
                    candidates.append((.easy, 0.7))
                    reasons.append("Ritmo entre fácil y umbral, duración moderada")
                }
            }
        }
        
        // FC alta para ritmo lento → recovery (si tenemos HR)
        if let hr = hr, paceSecPerKm > 0, paceSecPerKm < 600 {
            let paceMinPerKm = paceSecPerKm / 60
            if paceMinPerKm > 6.0 && hr > 140 {
                candidates.append((.recovery, 0.55))
                reasons.append("FC elevada para ritmo lento (posible fatiga)")
            }
        }
        
        // Por defecto: easy si duración 25–90 min y no hay señal fuerte
        if candidates.isEmpty {
            if durationMin >= 25 && durationMin <= 90 {
                candidates.append((.easy, 0.5))
                reasons.append("Duración típica de rodaje")
            } else if durationMin < 20 {
                candidates.append((.unknown, 0.3))
                reasons.append("Duración insuficiente para clasificar")
            }
        }
        
        // Elegir mejor candidato
        let sorted = candidates.sorted { $0.1 > $1.1 }
        let (type, confidence) = sorted.first ?? (.unknown, 0)
        
        return RunClassification(
            type: type,
            confidence: confidence,
            reasons: reasons.isEmpty ? ["Datos insuficientes para clasificar"] : reasons
        )
    }
    
    /// Desviación típica de ritmo entre splits (normalizada por media). 0 = muy estable, >0.15 = errático.
    private static func splitPaceVariability(splits: [ActivitySplit]?) -> Double {
        guard let splits = splits, splits.count >= 3 else { return 0 }
        let paces = splits.compactMap { s -> Double? in
            let km = s.distance / 1000
            guard km > 0 else { return nil }
            return Double(s.elapsedTime) / km
        }
        guard paces.count >= 2 else { return 0 }
        let mean = paces.reduce(0, +) / Double(paces.count)
        let variance = paces.map { pow($0 - mean, 2) }.reduce(0, +) / Double(paces.count)
        let std = sqrt(variance)
        return mean > 0 ? std / mean : 0
    }
}
