//
//  FatigueService.swift
//  SportBoardApp
//
//  Indicador de fatiga acumulada explicable.
//  Combina carga aguda/crónica, intensidad, impacto mecánico y reflexión subjetiva.
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
    /// 0 = piernas frescas, 100 = señales muy altas de fatiga acumulada.
    var scorePercent: Int
    var causes: [String]
    var recommendedAction: String

    var formattedScorePercent: String {
        "\(scorePercent)%"
    }

    var state: LegFatigueState {
        LegFatigueState(scorePercent: scorePercent)
    }
}

/// Clasificación fina para la fatiga específica de piernas.
enum LegFatigueState: String, CaseIterable {
    case fresh
    case normal
    case fatigued
    case highFatigue

    init(scorePercent: Int) {
        switch scorePercent {
        case ..<30:
            self = .fresh
        case 30..<60:
            self = .normal
        case 60..<80:
            self = .fatigued
        default:
            self = .highFatigue
        }
    }

    var displayName: String {
        switch self {
        case .fresh:
            return "Fresco"
        case .normal:
            return "Normal"
        case .fatigued:
            return "Fatigado"
        case .highFatigue:
            return "Fatiga alta"
        }
    }
}

struct FatigueModelConfig {
    var acuteDays = 7
    var chronicDays = 28
    var intensityDays = 14
    var mechanicalDays = 14
    var subjectiveDays = 14
    var smoothingDays = 3
    var smoothingAlpha = 0.55

    /// Roughly 7h30 easy-equivalent load in a week maps to 100.
    var maxWeeklyLoad = 450.0
    /// Four normal training weeks map to 100 chronic load.
    var maxChronicLoad = 1_800.0
    var maxElevationGainForSession = 800.0
    var maxConsecutiveDays = 5.0

    var weights = FatigueScoreWeights()
}

struct FatigueScoreWeights {
    var acuteLoad = 0.35
    var acuteChronicRatio = 0.20
    var intensityRatio = 0.15
    var consecutiveDays = 0.10
    var mechanicalLoad = 0.10
    var subjectiveScore = 0.10
}

/// Servicio que calcula fatiga acumulada desde historial local.
struct FatigueService {
    static let defaultConfig = FatigueModelConfig()
    
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
        reflections: [PostActivityReflection] = [],
        now: Date = Date(),
        config: FatigueModelConfig = defaultConfig
    ) -> FatigueDiagnosis {
        let runs = activities
            .filter { isRun($0) }
            .filter { $0.startDate <= now }
        let score = Int(smoothedFatigueScore(
            activities: runs,
            profile: profile,
            reflections: reflections,
            now: now,
            config: config
        ).rounded())
        let causes = fatigueCauses(
            activities: runs,
            profile: profile,
            reflections: reflections,
            now: now,
            config: config
        )
        let level = fatigueLevel(for: score)
        let action = recommendedAction(for: score)

        return FatigueDiagnosis(
            level: level,
            scorePercent: score,
            causes: causes.isEmpty ? ["Sin señales claras de fatiga acumulada"] : causes,
            recommendedAction: action
        )
    }

    static func computeWorkoutLoad(
        activity: Activity,
        profile: RunnerProfile?,
        config: FatigueModelConfig = defaultConfig
    ) -> Double {
        let durationMinutes = Double(activity.movingTime) / 60
        guard durationMinutes > 0 else { return 0 }
        return durationMinutes * intensityFactor(activity: activity, profile: profile)
    }

    static func computeMechanicalImpact(
        activity: Activity,
        profile: RunnerProfile?,
        config: FatigueModelConfig = defaultConfig
    ) -> Double {
        let elevationGainFactor = clamp(
            (activity.totalElevationGain / config.maxElevationGainForSession) * 30,
            lower: 0,
            upper: 30
        )
        let paceFactor = paceImpactFactor(activity: activity, profile: profile)
        let intensityBonus = clamp(
            ((intensityFactor(activity: activity, profile: profile) - 1.0) / 1.5) * 35,
            lower: 0,
            upper: 35
        )

        return clamp(elevationGainFactor + paceFactor + intensityBonus, lower: 0, upper: 100)
    }

    static func computeAcuteLoad(
        activities: [Activity],
        profile: RunnerProfile?,
        now: Date = Date(),
        config: FatigueModelConfig = defaultConfig
    ) -> Double {
        normalizedLoad(
            rawLoad(inLastDays: config.acuteDays, activities: activities, profile: profile, now: now),
            maxLoad: config.maxWeeklyLoad
        )
    }

    static func computeChronicLoad(
        activities: [Activity],
        profile: RunnerProfile?,
        now: Date = Date(),
        config: FatigueModelConfig = defaultConfig
    ) -> Double {
        normalizedLoad(
            rawLoad(inLastDays: config.chronicDays, activities: activities, profile: profile, now: now),
            maxLoad: config.maxChronicLoad
        )
    }

    static func computeFatigueScore(
        activities: [Activity],
        profile: RunnerProfile?,
        reflections: [PostActivityReflection] = [],
        now: Date = Date(),
        config: FatigueModelConfig = defaultConfig
    ) -> Double {
        let runs = activities.filter { isRun($0) && $0.startDate <= now }
        return rawFatigueScore(activities: runs, profile: profile, reflections: reflections, now: now, config: config)
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

    private static func smoothedFatigueScore(
        activities: [Activity],
        profile: RunnerProfile?,
        reflections: [PostActivityReflection],
        now: Date,
        config: FatigueModelConfig
    ) -> Double {
        let calendar = Calendar.current
        let offsets = Array(0..<max(1, config.smoothingDays)).reversed()
        let scores = offsets.map { offset -> Double in
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            return rawFatigueScore(activities: activities, profile: profile, reflections: reflections, now: date, config: config)
        }
        guard var ema = scores.first else { return 0 }
        for score in scores.dropFirst() {
            ema = config.smoothingAlpha * score + (1 - config.smoothingAlpha) * ema
        }
        return clamp(ema, lower: 0, upper: 100)
    }

    private static func rawFatigueScore(
        activities: [Activity],
        profile: RunnerProfile?,
        reflections: [PostActivityReflection],
        now: Date,
        config: FatigueModelConfig
    ) -> Double {
        let acuteRaw = rawLoad(inLastDays: config.acuteDays, activities: activities, profile: profile, now: now)
        let chronicRaw = rawLoad(inLastDays: config.chronicDays, activities: activities, profile: profile, now: now)
        let acuteLoad = normalizedLoad(acuteRaw, maxLoad: config.maxWeeklyLoad)
        let chronicLoad = normalizedLoad(chronicRaw, maxLoad: config.maxChronicLoad)
        let weeklyChronic = chronicRaw / 4
        let ratioScore = weeklyChronic > 0 ? clamp((acuteRaw / weeklyChronic) * 50, lower: 0, upper: 100) : nil
        let intensityRatio = hardSessionRatio(activities: activities, profile: profile, now: now, config: config) * 100
        let consecutiveDays = normalizedConsecutiveDays(activities: activities, now: now, config: config)
        let mechanicalLoad = weightedMechanicalLoad(activities: activities, profile: profile, now: now, config: config)
        let subjectiveScore = subjectiveScore(reflections: reflections, now: now, config: config)

        let components: [(value: Double?, weight: Double)] = [
            (acuteLoad, config.weights.acuteLoad),
            (ratioScore, config.weights.acuteChronicRatio),
            (intensityRatio, config.weights.intensityRatio),
            (consecutiveDays, config.weights.consecutiveDays),
            (mechanicalLoad, config.weights.mechanicalLoad),
            (subjectiveScore, config.weights.subjectiveScore)
        ]
        let weighted = components.reduce((sum: 0.0, weight: 0.0)) { partial, component in
            guard let value = component.value else { return partial }
            return (partial.sum + clamp(value, lower: 0, upper: 100) * component.weight, partial.weight + component.weight)
        }
        guard weighted.weight > 0 else { return 0 }
        _ = chronicLoad // kept as a named component for readability and future tuning.
        return clamp(weighted.sum / weighted.weight, lower: 0, upper: 100)
    }

    private static func rawLoad(
        inLastDays days: Int,
        activities: [Activity],
        profile: RunnerProfile?,
        now: Date
    ) -> Double {
        activities
            .filter { isWithinLast(days: days, date: $0.startDate, now: now) }
            .reduce(0) { $0 + computeWorkoutLoad(activity: $1, profile: profile) }
    }

    private static func normalizedLoad(_ load: Double, maxLoad: Double) -> Double {
        guard maxLoad > 0 else { return 0 }
        return clamp((load / maxLoad) * 100, lower: 0, upper: 100)
    }

    private static func hardSessionRatio(
        activities: [Activity],
        profile: RunnerProfile?,
        now: Date,
        config: FatigueModelConfig
    ) -> Double {
        let recent = activities.filter { isWithinLast(days: config.intensityDays, date: $0.startDate, now: now) }
        guard !recent.isEmpty else { return 0 }
        let hardCount = recent.filter { intensityFactor(activity: $0, profile: profile) >= 1.5 }.count
        return Double(hardCount) / Double(recent.count)
    }

    private static func normalizedConsecutiveDays(
        activities: [Activity],
        now: Date,
        config: FatigueModelConfig
    ) -> Double {
        let days = consecutiveTrainingDays(activities: activities, now: now)
        guard config.maxConsecutiveDays > 0 else { return 0 }
        return clamp((Double(days) / config.maxConsecutiveDays) * 100, lower: 0, upper: 100)
    }

    private static func weightedMechanicalLoad(
        activities: [Activity],
        profile: RunnerProfile?,
        now: Date,
        config: FatigueModelConfig
    ) -> Double {
        let recent = activities.filter { isWithinLast(days: config.mechanicalDays, date: $0.startDate, now: now) }
        guard !recent.isEmpty else { return 0 }
        let calendar = Calendar.current
        let weighted = recent.reduce((sum: 0.0, weight: 0.0)) { partial, activity in
            let daysAgo = Double(calendar.dateComponents([.day], from: activity.startDate, to: now).day ?? 0)
            let recencyWeight = max(0.35, 1 - daysAgo / Double(max(1, config.mechanicalDays)))
            let impact = computeMechanicalImpact(activity: activity, profile: profile, config: config)
            return (partial.sum + impact * recencyWeight, partial.weight + recencyWeight)
        }
        return weighted.weight > 0 ? weighted.sum / weighted.weight : 0
    }

    private static func subjectiveScore(
        reflections: [PostActivityReflection],
        now: Date,
        config: FatigueModelConfig
    ) -> Double? {
        let recent = reflections.filter { isWithinLast(days: config.subjectiveDays, date: $0.date, now: now) }
        guard !recent.isEmpty else { return nil }
        let scores = recent.map { reflection -> Double in
            let feelingPenalty = Double(max(0, 5 - reflection.feelingScore)) * 15
            let pushedPenalty = reflection.pushedTooHard ? 30.0 : 0
            let repeatPenalty = reflection.wouldRepeatToday ? 0.0 : 15.0
            return clamp(feelingPenalty + pushedPenalty + repeatPenalty, lower: 0, upper: 100)
        }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private static func intensityFactor(activity: Activity, profile: RunnerProfile?) -> Double {
        if let factor = intensityFactorFromPace(activity: activity, profile: profile) {
            return factor
        }
        if let factor = intensityFactorFromHeartRate(activity: activity) {
            return factor
        }
        let classification = RunClassifier.classify(
            activity: activity,
            easyPaceMs: profile?.easyPaceMs,
            thresholdPaceMs: profile?.thresholdPaceMs
        )
        return intensityFactor(for: classification.type)
    }

    private static func intensityFactorFromPace(activity: Activity, profile: RunnerProfile?) -> Double? {
        guard activity.averageSpeed > 0 else { return nil }
        guard let profile, profile.easyPaceMs > 0 else { return nil }
        if profile.thresholdPaceMs > 0 {
            if activity.averageSpeed >= profile.thresholdPaceMs * 1.08 {
                return 2.25
            }
            if activity.averageSpeed >= profile.thresholdPaceMs * 0.95 {
                return 1.5
            }
        }
        if activity.averageSpeed > profile.easyPaceMs * 1.08 {
            return 1.2
        }
        return 1.0
    }

    private static func intensityFactorFromHeartRate(activity: Activity) -> Double? {
        guard let heartRate = activity.averageHeartrate else { return nil }
        switch heartRate {
        case 170...:
            return 2.0
        case 155..<170:
            return 1.5
        case 140..<155:
            return 1.2
        default:
            return 1.0
        }
    }

    private static func intensityFactor(for type: RunSessionType) -> Double {
        switch type {
        case .recovery, .easy, .long, .unknown:
            return 1.0
        case .tempo:
            return 1.5
        case .intervals:
            return 2.25
        case .race:
            return 2.5
        }
    }

    private static func paceImpactFactor(activity: Activity, profile: RunnerProfile?) -> Double {
        guard activity.averageSpeed > 0 else { return 0 }
        guard let profile, profile.easyPaceMs > 0 else {
            return 10
        }
        if profile.thresholdPaceMs > 0, activity.averageSpeed >= profile.thresholdPaceMs {
            return clamp(22 + ((activity.averageSpeed / profile.thresholdPaceMs) - 1) * 45, lower: 22, upper: 35)
        }
        let relativeToEasy = activity.averageSpeed / profile.easyPaceMs
        return clamp((relativeToEasy - 0.95) * 35, lower: 0, upper: 24)
    }

    private static func fatigueCauses(
        activities: [Activity],
        profile: RunnerProfile?,
        reflections: [PostActivityReflection],
        now: Date,
        config: FatigueModelConfig
    ) -> [String] {
        var causes: [String] = []
        let acuteRaw = rawLoad(inLastDays: config.acuteDays, activities: activities, profile: profile, now: now)
        let chronicRaw = rawLoad(inLastDays: config.chronicDays, activities: activities, profile: profile, now: now)
        let weeklyChronic = chronicRaw / 4
        if weeklyChronic > 0, acuteRaw / weeklyChronic >= 1.35 {
            causes.append("Carga aguda por encima de tu carga crónica")
        }
        let hardRatio = hardSessionRatio(activities: activities, profile: profile, now: now, config: config)
        if hardRatio >= 0.35 {
            causes.append("Alta proporción de sesiones intensas recientes")
        }
        let consecutive = consecutiveTrainingDays(activities: activities, now: now)
        if consecutive >= 3 {
            causes.append("\(consecutive) días seguidos entrenando")
        }
        if weightedMechanicalLoad(activities: activities, profile: profile, now: now, config: config) >= 55 {
            causes.append("Impacto mecánico elevado por ritmo, desnivel o intensidad")
        }
        if let subjective = subjectiveScore(reflections: reflections, now: now, config: config), subjective >= 40 {
            causes.append("Tus reflexiones recientes indican mala sensación o exceso de esfuerzo")
        }
        return causes
    }

    private static func consecutiveTrainingDays(activities: [Activity], now: Date) -> Int {
        let calendar = Calendar.current
        let trainingDays = Set(activities.map { calendar.startOfDay(for: $0.startDate) })
        var cursor = calendar.startOfDay(for: now)
        var count = 0
        while trainingDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private static func isWithinLast(days: Int, date: Date, now: Date) -> Bool {
        guard date <= now else { return false }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        return date >= start
    }

    private static func isRun(_ activity: Activity) -> Bool {
        ["run", "virtualrun", "trailrun"].contains(activity.sportType.lowercased())
    }

    private static func fatigueLevel(for score: Int) -> FatigueLevel {
        switch score {
        case ..<30:
            return .low
        case 30..<60:
            return .medium
        default:
            return .high
        }
    }

    private static func recommendedAction(for score: Int) -> String {
        switch LegFatigueState(scorePercent: score) {
        case .fresh:
            return "Piernas frescas. Puedes mantener la progresión prevista."
        case .normal:
            return "Carga asumible. Prioriza recuperar bien entre sesiones de calidad."
        case .fatigued:
            return "Piernas cargadas. Reduce intensidad o cambia por rodaje fácil."
        case .highFatigue:
            return "Fatiga alta. Descanso o sesión muy suave antes de volver a exigir."
        }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
