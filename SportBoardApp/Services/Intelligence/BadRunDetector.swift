//
//  BadRunDetector.swift
//  SportBoardApp
//
//  Identifica rodajes que debían ser fáciles pero resultaron exigentes.
//  Señales: FC alta para ese ritmo, ritmo errático, deriva excesiva, mala recuperación vs día anterior.
//

import Foundation
import SwiftData

/// Severidad del insight
enum BadRunSeverity: String, CaseIterable {
    case low
    case medium
    case high
    
    var displayName: String {
        switch self {
        case .low: return "Leve"
        case .medium: return "Moderada"
        case .high: return "Alta"
        }
    }
}

/// Resultado del detector: severidad, causas y acción sugerida
struct BadRunInsight {
    var severity: BadRunSeverity
    var causes: [String]
    var suggestedAction: String
    var summary: String
    
    var hasIssue: Bool { severity != .low || !causes.isEmpty }
}

/// Detector de rodaje mal ejecutado.
struct BadRunDetector {
    
    /// Margen para "FC alta para ese ritmo" (porcentaje por encima de lo esperado)
    private static let hrAboveExpectedMargin = 0.08
    
    /// Deriva anormal: diferencia de FC primera vs segunda mitad (bpm)
    private static let driftThresholdBpm = 8
    
    /// Variabilidad de ritmo entre splits (CV) que se considera errática
    private static let erraticPaceCV = 0.12
    
    /// Evalúa una actividad y devuelve insight si aplica.
    static func evaluate(
        activity: Activity,
        splits: [ActivitySplit]? = nil,
        profile: RunnerProfile?,
        previousDayActivity: Activity?
    ) -> BadRunInsight {
        let quality = DataQuality.evaluate(activity: activity, splits: splits)
        guard quality.isRun else {
            return BadRunInsight(
                severity: .low,
                causes: [],
                suggestedAction: "",
                summary: ""
            )
        }
        
        var causes: [String] = []
        var severityScore = 0
        
        let splitsToUse = splits ?? activity.sortedSplits
        let easyPaceMs = profile?.easyPaceMs ?? 0
        
        // 1. FC demasiado alta para ese ritmo (si tenemos perfil y HR)
        if quality.canUseHeartrateMetrics, let hr = activity.averageHeartrate, easyPaceMs > 0 {
            let expectedHRFactor = 0.85 + (0.15 * (activity.averageSpeed / easyPaceMs))
            let estimatedMaxHR = 190.0
            let expectedHR = estimatedMaxHR * expectedHRFactor * 0.75
            if hr > expectedHR * (1 + Self.hrAboveExpectedMargin) {
                causes.append("FC más alta de lo esperado para este ritmo")
                severityScore += 2
            }
        }
        
        // 2. Ritmo errático entre splits
        if quality.canUseSplitMetrics, let splitsArray = splitsToUse, splitsArray.count >= 3 {
            let paces = splitsArray.compactMap { s -> Double? in
                let km = s.distance / 1000
                guard km > 0 else { return nil }
                return Double(s.elapsedTime) / km
            }
            if paces.count >= 3 {
                let cv = coefficientOfVariation(paces)
                if cv > Self.erraticPaceCV {
                    causes.append("Ritmo muy variable entre kilómetros")
                    severityScore += 1
                }
            }
        }
        
        // 3. Deriva excesiva (primera vs segunda mitad)
        if let splitsArray = splitsToUse, splitsArray.count >= 4 {
            let mid = splitsArray.count / 2
            let firstHalf = splitsArray.prefix(mid).compactMap(\.averageHeartrate)
            let secondHalf = splitsArray.suffix(splitsArray.count - mid).compactMap(\.averageHeartrate)
            if let avg1 = firstHalf.isEmpty ? nil : firstHalf.reduce(0, +) / Double(firstHalf.count),
               let avg2 = secondHalf.isEmpty ? nil : secondHalf.reduce(0, +) / Double(secondHalf.count) {
                let drift = avg2 - avg1
                if drift > Double(Self.driftThresholdBpm) {
                    causes.append("Deriva de FC alta (segunda mitad más exigente)")
                    severityScore += 2
                }
            }
        }
        
        // 4. Mala recuperación respecto al día anterior
        if let prev = previousDayActivity, prev.averageSpeed > 0, activity.averageSpeed > 0 {
            let prevPace = 1000 / prev.averageSpeed
            let todayPace = 1000 / activity.averageSpeed
            if let prevHR = prev.averageHeartrate, let todayHR = activity.averageHeartrate {
                if todayPace >= prevPace * 0.98 && todayHR > prevHR + 5 {
                    causes.append("FC elevada respecto al entrenamiento de ayer")
                    severityScore += 2
                }
            }
        }
        
        let severity: BadRunSeverity
        if severityScore >= 4 { severity = .high }
        else if severityScore >= 2 { severity = .medium }
        else { severity = .low }
        
        let action: String
        if severity == .high {
            action = "Considera un día de descanso o rodaje muy suave mañana."
        } else if severity == .medium {
            action = "Prioriza recuperación: próximo entreno fácil."
        } else {
            action = ""
        }
        
        let summary: String
        if causes.isEmpty {
            summary = ""
        } else {
            summary = "Este rodaje fue más exigente de lo esperado. Probable fatiga acumulada."
        }
        
        return BadRunInsight(
            severity: severity,
            causes: causes,
            suggestedAction: action,
            summary: summary
        )
    }
    
    private static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let std = sqrt(variance)
        return mean > 0 ? std / mean : 0
    }
}
