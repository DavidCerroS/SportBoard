//
//  TrainingReadinessService.swift
//  SportBoardApp
//
//  Sintetiza las señales de inteligencia en una decisión entrenable.
//

import Foundation

struct TrainingReadiness {
    var state: ReadinessState
    var score: Int
    var recommendation: NextWorkoutSuggestion?
    var riskLevel: ReadinessRiskLevel
    var signals: [TrainingSignal]
    var explanation: [String]
}

enum ReadinessState {
    case ready
    case keepEasy
    case caution
    case recover
    case insufficientData

    var title: String {
        switch self {
        case .ready:
            return "Listo para entrenar"
        case .keepEasy:
            return "Mantén suave"
        case .caution:
            return "Cuidado con la carga"
        case .recover:
            return "Recuperar primero"
        case .insufficientData:
            return "Faltan datos"
        }
    }

    var subtitle: String {
        switch self {
        case .ready:
            return "Las señales actuales permiten entrenar con normalidad."
        case .keepEasy:
            return "Conviene sumar base sin añadir estrés."
        case .caution:
            return "Hay señales que recomiendan controlar la intensidad."
        case .recover:
            return "La prioridad ahora es bajar carga y asimilar."
        case .insufficientData:
            return "Sin historial suficiente para una lectura fiable."
        }
    }
}

enum ReadinessRiskLevel {
    case low
    case moderate
    case high

    var title: String {
        switch self {
        case .low:
            return "Bajo"
        case .moderate:
            return "Moderado"
        case .high:
            return "Alto"
        }
    }
}

struct TrainingSignal: Identifiable {
    var id: String
    var title: String
    var message: String
    var severity: SignalSeverity
    var category: SignalCategory
}

enum SignalSeverity {
    case positive
    case neutral
    case warning
    case critical
}

enum SignalCategory {
    case load
    case recovery
    case consistency
    case efficiency
    case data
    case opportunity
}

struct TrainingReadinessService {
    static func evaluate(
        profile: RunnerProfile?,
        consistency: ConsistencyBreakdown?,
        fatigue: FatigueDiagnosis?,
        efficiencyTrend: EfficiencyTrendResult?,
        suggestion: NextWorkoutSuggestion?,
        alerts: [SilentAlert],
        suspiciousPeak: SuspiciousPeakResult?
    ) -> TrainingReadiness {
        guard profile?.isValid == true || consistency != nil || fatigue != nil else {
            return TrainingReadiness(
                state: .insufficientData,
                score: 0,
                recommendation: suggestion,
                riskLevel: .moderate,
                signals: [
                    TrainingSignal(
                        id: "data_profile",
                        title: "Perfil incompleto",
                        message: "Sin suficientes carreras estables para calibrar ritmo cómodo, carga y tendencia.",
                        severity: .neutral,
                        category: .data
                    )
                ],
                explanation: ["Sin un perfil de corredor fiable, la app evita sobreactuar con recomendaciones."]
            )
        }

        let fatigueScore = fatigue?.scorePercent ?? 35
        let consistencyScore = consistency?.score ?? 60
        let trendPenalty = trendPenalty(for: efficiencyTrend)
        let alertPenalty = alerts.reduce(0) { partial, alert in
            partial + penalty(for: alert.severity)
        }
        let dataConfidenceBonus = Int(((profile?.confidence ?? 0.4) * 8).rounded())
        let score = clamp(
            100 - fatigueScore + (consistencyScore - 60) / 2 - trendPenalty - alertPenalty + dataConfidenceBonus,
            lower: 0,
            upper: 100
        )

        let riskLevel: ReadinessRiskLevel
        if fatigue?.level == .high || alerts.contains(where: { $0.severity == .high }) || score < 35 {
            riskLevel = .high
        } else if fatigue?.level == .medium || !alerts.isEmpty || score < 65 {
            riskLevel = .moderate
        } else {
            riskLevel = .low
        }

        let state: ReadinessState
        if riskLevel == .high {
            state = .recover
        } else if riskLevel == .moderate && fatigue?.state == .fatigued {
            state = .caution
        } else if suggestion?.intensity.lowercased() == "fácil" {
            state = .keepEasy
        } else {
            state = .ready
        }

        let signals = buildSignals(
            consistency: consistency,
            fatigue: fatigue,
            efficiencyTrend: efficiencyTrend,
            alerts: alerts,
            suspiciousPeak: suspiciousPeak,
            profile: profile
        )

        return TrainingReadiness(
            state: state,
            score: score,
            recommendation: suggestion,
            riskLevel: riskLevel,
            signals: signals,
            explanation: explanation(
                state: state,
                fatigue: fatigue,
                consistency: consistency,
                efficiencyTrend: efficiencyTrend,
                alerts: alerts
            )
        )
    }

    private static func buildSignals(
        consistency: ConsistencyBreakdown?,
        fatigue: FatigueDiagnosis?,
        efficiencyTrend: EfficiencyTrendResult?,
        alerts: [SilentAlert],
        suspiciousPeak: SuspiciousPeakResult?,
        profile: RunnerProfile?
    ) -> [TrainingSignal] {
        var signals: [TrainingSignal] = []

        signals.append(contentsOf: alerts.prefix(3).map { alert in
            TrainingSignal(
                id: "alert_\(alert.id)",
                title: alert.title,
                message: alert.message,
                severity: signalSeverity(for: alert.severity),
                category: .load
            )
        })

        if let fatigue {
            signals.append(
                TrainingSignal(
                    id: "fatigue",
                    title: "Piernas \(fatigue.state.displayName.lowercased())",
                    message: fatigue.causes.prefix(2).joined(separator: ". "),
                    severity: fatigueSeverity(for: fatigue),
                    category: .recovery
                )
            )
        }

        if let consistency {
            let severity: SignalSeverity = consistency.score >= 75 ? .positive : (consistency.score < 50 ? .warning : .neutral)
            signals.append(
                TrainingSignal(
                    id: "consistency",
                    title: "Consistencia \(consistency.score)/100",
                    message: consistency.reasons.prefix(2).joined(separator: ". "),
                    severity: severity,
                    category: .consistency
                )
            )
        }

        if let trend = efficiencyTrend {
            signals.append(
                TrainingSignal(
                    id: "efficiency",
                    title: efficiencyTitle(for: trend.direction),
                    message: trend.reasons.first ?? "Tendencia estable con los datos disponibles",
                    severity: efficiencySeverity(for: trend.direction),
                    category: .efficiency
                )
            )
        }

        if let peak = suspiciousPeak, peak.detected {
            signals.append(
                TrainingSignal(
                    id: "suspicious_peak",
                    title: "Mejora muy rápida",
                    message: peak.message,
                    severity: .neutral,
                    category: .opportunity
                )
            )
        }

        if profile?.isValid != true {
            signals.append(
                TrainingSignal(
                    id: "profile_confidence",
                    title: "Perfil poco calibrado",
                    message: "Las recomendaciones serán más precisas cuando haya más rodajes comparables.",
                    severity: .neutral,
                    category: .data
                )
            )
        }

        return Array(signals.prefix(5))
    }

    private static func explanation(
        state: ReadinessState,
        fatigue: FatigueDiagnosis?,
        consistency: ConsistencyBreakdown?,
        efficiencyTrend: EfficiencyTrendResult?,
        alerts: [SilentAlert]
    ) -> [String] {
        var lines: [String] = [state.subtitle]

        if let fatigue {
            lines.append("Fatiga: \(fatigue.formattedScorePercent) (\(fatigue.state.displayName.lowercased())).")
        }
        if let consistency {
            lines.append("Consistencia: \(consistency.score)/100 con \(consistency.consecutiveWeeks) semanas de racha.")
        }
        if let trend = efficiencyTrend {
            lines.append("Eficiencia: \(efficiencyTitle(for: trend.direction).lowercased()).")
        }
        if !alerts.isEmpty {
            lines.append("Hay \(alerts.count) señal\(alerts.count == 1 ? "" : "es") que conviene revisar antes de cargar más.")
        }

        return lines
    }

    private static func trendPenalty(for trend: EfficiencyTrendResult?) -> Int {
        guard let trend else { return 0 }
        switch trend.direction {
        case .improving:
            return -4
        case .stable:
            return 0
        case .declining:
            return Int((10 * trend.confidence).rounded())
        }
    }

    private static func penalty(for severity: AlertSeverity) -> Int {
        switch severity {
        case .info:
            return 3
        case .warning:
            return 8
        case .high:
            return 16
        }
    }

    private static func signalSeverity(for alertSeverity: AlertSeverity) -> SignalSeverity {
        switch alertSeverity {
        case .info:
            return .neutral
        case .warning:
            return .warning
        case .high:
            return .critical
        }
    }

    private static func fatigueSeverity(for fatigue: FatigueDiagnosis) -> SignalSeverity {
        switch fatigue.level {
        case .low:
            return .positive
        case .medium:
            return .warning
        case .high:
            return .critical
        }
    }

    private static func efficiencySeverity(for direction: EfficiencyTrendDirection) -> SignalSeverity {
        switch direction {
        case .improving:
            return .positive
        case .stable:
            return .neutral
        case .declining:
            return .warning
        }
    }

    private static func efficiencyTitle(for direction: EfficiencyTrendDirection) -> String {
        switch direction {
        case .improving:
            return "Eficiencia subiendo"
        case .stable:
            return "Eficiencia estable"
        case .declining:
            return "Eficiencia bajando"
        }
    }

    private static func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        max(lower, min(upper, value))
    }
}
