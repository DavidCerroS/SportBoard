//
//  RacePreparationService.swift
//  SportBoardApp
//
//  Contexto de preparacion para media maraton y ajuste del plan segun datos reales.
//

import Foundation
import SwiftData

struct RacePreparation {
    var source: RacePreparationSource
    var goal: RaceGoal
    var phase: RacePreparationPhase
    var daysToRace: Int
    var weeksToRace: Int
    var weekPlan: [PlannedWorkout]
    var nextWorkout: PlannedWorkout?
    var todayWorkout: PlannedWorkout?
    var completedWorkoutIDs: Set<String>
    var weekStatus: PlanWeekStatus
    var decision: PlanAdjustmentDecision
    var adherence: [WorkoutAdherence]
    var monthlyBlocks: [MonthlyTrainingBlock]
}

struct RaceGoal {
    var name: String
    var distanceName: String
    var raceDate: Date
    var targetTimeText: String?
    var objective: String
}

enum RacePreparationSource: Equatable {
    case activeGoal
    case fallback
}

enum RacePreparationPhase {
    case base
    case build
    case specific
    case taper
    case raceWeek
    case completed

    var title: String {
        switch self {
        case .base:
            return "Base"
        case .build:
            return "Construccion"
        case .specific:
            return "Especifica"
        case .taper:
            return "Taper"
        case .raceWeek:
            return "Semana de carrera"
        case .completed:
            return "Carrera completada"
        }
    }

    var focus: String {
        switch self {
        case .base:
            return "construir rutina, volumen facil y tecnica sin acumular fatiga innecesaria."
        case .build:
            return "subir volumen de forma controlada y consolidar las sesiones de calidad."
        case .specific:
            return "acercar tempo y tirada larga al ritmo y fatiga esperados de media maraton."
        case .taper:
            return "bajar volumen manteniendo chispa para llegar fresco."
        case .raceWeek:
            return "llegar descansado, activar piernas y no inventar nada."
        case .completed:
            return "recuperar, revisar el bloque y decidir el siguiente objetivo."
        }
    }
}

enum PlannedWorkoutType: String, Codable {
    case recovery
    case intervals
    case tempo
    case longRun
    case race
    case rest

    var title: String {
        switch self {
        case .recovery:
            return "Recuperacion"
        case .intervals:
            return "Series"
        case .tempo:
            return "Tempo"
        case .longRun:
            return "Tirada larga"
        case .race:
            return "Media maraton"
        case .rest:
            return "Descanso"
        }
    }

    var icon: String {
        switch self {
        case .recovery:
            return "figure.cooldown"
        case .intervals:
            return "bolt.fill"
        case .tempo:
            return "metronome.fill"
        case .longRun:
            return "road.lanes"
        case .race:
            return "flag.checkered"
        case .rest:
            return "moon.zzz.fill"
        }
    }
}

struct PlannedWorkout: Identifiable {
    var id: String
    var date: Date
    var type: PlannedWorkoutType
    var title: String
    var prescription: String
    var intent: String
    var minDuration: Int
    var maxDuration: Int
    var priority: WorkoutPriority
    var adaptation: WorkoutAdaptation? = nil
}

struct WorkoutAdaptation {
    var originalType: PlannedWorkoutType
    var originalTitle: String
    var originalPrescription: String
    var reason: String
    var severity: PlanDecisionSeverity
}

struct WorkoutAdherence: Identifiable {
    var id: String { workoutId }
    var workoutId: String
    var status: WorkoutAdherenceStatus
    var title: String
    var message: String
    var actualSummary: String?
}

enum WorkoutAdherenceStatus: Equatable {
    case pending
    case completed
    case partial
    case missed
    case adapted

    var title: String {
        switch self {
        case .pending:
            return "Pendiente"
        case .completed:
            return "Cumplida"
        case .partial:
            return "Parcial"
        case .missed:
            return "Sin hacer"
        case .adapted:
            return "Adaptada"
        }
    }
}

enum WorkoutPriority: String, Codable {
    case low
    case medium
    case high
    case key

    var title: String {
        switch self {
        case .low:
            return "Baja"
        case .medium:
            return "Media"
        case .high:
            return "Alta"
        case .key:
            return "Clave"
        }
    }
}

struct PlanWeekStatus {
    var completed: Int
    var planned: Int
    var missedKeyWorkouts: [PlannedWorkout]
    var remainingKeyWorkouts: [PlannedWorkout]
    var message: String

    var progress: Double {
        guard planned > 0 else { return 0 }
        return Double(completed) / Double(planned)
    }
}

struct PlanAdjustmentDecision {
    var title: String
    var recommendation: String
    var reason: String
    var severity: PlanDecisionSeverity
}

enum PlanDecisionSeverity {
    case green
    case blue
    case yellow
    case red
}

struct MonthlyTrainingBlock: Identifiable {
    var id: String { month }
    var month: String
    var focus: String
}

struct ImportedMonthlyTrainingPlan: Codable {
    var month: String
    var objective: String
    var weeks: [ImportedTrainingWeek]
}

struct ImportedTrainingWeek: Codable {
    var name: String
    var focus: String?
    var workouts: [ImportedPlannedWorkout]
}

struct ImportedPlannedWorkout: Codable {
    var date: String
    var type: PlannedWorkoutType
    var title: String
    var prescription: String
    var intent: String
    var minDuration: Int
    var maxDuration: Int
    var priority: WorkoutPriority
    var notes: [String]?
}

extension RaceGoal {
    init(_ trainingGoal: TrainingGoal) {
        self.init(
            name: trainingGoal.name,
            distanceName: trainingGoal.distanceName,
            raceDate: trainingGoal.raceDate,
            targetTimeText: trainingGoal.targetTimeText,
            objective: trainingGoal.objective
        )
    }
}

enum TrainingPlanImportError: LocalizedError {
    case invalidJSON
    case invalidMonth
    case invalidDate(String)
    case emptyPlan

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "El JSON no tiene el formato esperado."
        case .invalidMonth:
            return "El campo month debe tener formato yyyy-MM, por ejemplo 2026-06."
        case .invalidDate(let value):
            return "Fecha invalida en el plan: \(value). Usa yyyy-MM-dd."
        case .emptyPlan:
            return "El plan no contiene entrenamientos."
        }
    }
}

struct RacePreparationService {
    private static let runTypes = ["run", "virtualrun", "trailrun"]
    private static let importedPlanPrefix = "sportboard.trainingPlan."

    static var standardPlanTemplate: String {
        """
        {
          "month": "2026-06",
          "objective": "Objetivo del mes",
          "weeks": [
            {
              "name": "Semana 1 — 1 al 7 junio",
              "focus": "Foco de la semana",
              "workouts": [
                {
                  "date": "2026-06-01",
                  "type": "recovery",
                  "title": "Rodaje suave",
                  "prescription": "7 km comodos + 4 x 80 m progresivos",
                  "intent": "Asimilar y llegar fresco al martes.",
                  "minDuration": 35,
                  "maxDuration": 50,
                  "priority": "low",
                  "notes": ["Ritmo por sensaciones", "No apretar progresivos"]
                }
              ]
            }
          ]
        }
        """
    }

    static func importMonthlyPlan(from text: String) throws {
        guard let data = text.data(using: .utf8) else {
            throw TrainingPlanImportError.invalidJSON
        }

        let decoder = JSONDecoder()
        let plan: ImportedMonthlyTrainingPlan
        do {
            plan = try decoder.decode(ImportedMonthlyTrainingPlan.self, from: data)
        } catch {
            throw TrainingPlanImportError.invalidJSON
        }

        try validate(plan)
        UserDefaults.standard.set(data, forKey: storageKey(for: plan.month))
    }

    static func evaluate(
        modelContext: ModelContext,
        readiness: TrainingReadiness?,
        now: Date = Date()
    ) throws -> RacePreparation? {
        guard let activeGoal = try fetchActiveGoal(modelContext: modelContext) else {
            return nil
        }
        let activities = try fetchRuns(modelContext: modelContext)
        return evaluateFromActivities(
            activities,
            readiness: readiness,
            goal: RaceGoal(activeGoal),
            preferredWeekdayOffsets: activeGoal.preferredWeekdayOffsets,
            source: .activeGoal,
            now: now
        )
    }

    static func evaluateFromActivities(
        _ activities: [Activity],
        readiness: TrainingReadiness?,
        goal: RaceGoal? = nil,
        preferredWeekdayOffsets: [Int] = [0, 1, 3, 5],
        source: RacePreparationSource = .fallback,
        now: Date = Date(),
        calendar: Calendar = .sportBoardMadrid
    ) -> RacePreparation {
        let goal = goal ?? defaultGoal(calendar: calendar)
        let rawDaysToRace = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: goal.raceDate)).day ?? 0
        let daysToRace = max(0, rawDaysToRace)
        let weeksToRace = max(0, Int(ceil(Double(daysToRace) / 7.0)))
        let phase = phaseFor(daysToRace: rawDaysToRace)
        let baseWeekPlan = buildWeekPlan(
            now: now,
            goal: goal,
            phase: phase,
            weeksToRace: weeksToRace,
            preferredWeekdayOffsets: preferredWeekdayOffsets,
            calendar: calendar
        )
        let weekPlan = adaptWeekPlan(baseWeekPlan, readiness: readiness)
        let completed = completedWorkoutIDs(weekPlan: weekPlan, activities: activities, calendar: calendar)
        let todayWorkout = weekPlan.first { calendar.isDate($0.date, inSameDayAs: now) }
        let nextWorkout = weekPlan.first { $0.date >= calendar.startOfDay(for: now) && !completed.contains($0.id) }
        let status = weekStatus(weekPlan: weekPlan, completed: completed, now: now, calendar: calendar)
        let adherence = adherenceFor(weekPlan: weekPlan, activities: activities, now: now, calendar: calendar)
        let decision = decisionFor(
            todayWorkout: todayWorkout,
            nextWorkout: nextWorkout,
            readiness: readiness,
            status: status,
            daysToRace: daysToRace,
            now: now,
            calendar: calendar
        )

        return RacePreparation(
            source: source,
            goal: goal,
            phase: phase,
            daysToRace: daysToRace,
            weeksToRace: weeksToRace,
            weekPlan: weekPlan,
            nextWorkout: nextWorkout,
            todayWorkout: todayWorkout,
            completedWorkoutIDs: completed,
            weekStatus: status,
            decision: decision,
            adherence: adherence,
            monthlyBlocks: monthlyBlocks()
        )
    }

    static func fetchActiveGoal(modelContext: ModelContext) throws -> TrainingGoal? {
        var descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func defaultGoal(calendar: Calendar) -> RaceGoal {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 11,
            day: 8,
            hour: 9
        )
        return RaceGoal(
            name: "Media maraton",
            distanceName: "21,1 km",
            raceDate: components.date ?? Date(),
            targetTimeText: "1h 35m",
            objective: "Llegar fuerte y sano al 8 de noviembre"
        )
    }

    private static func phaseFor(daysToRace: Int) -> RacePreparationPhase {
        if daysToRace == 0 { return .raceWeek }
        if daysToRace < 0 { return .completed }
        switch daysToRace {
        case 0...7:
            return .raceWeek
        case 8...21:
            return .taper
        case 22...70:
            return .specific
        case 71...126:
            return .build
        default:
            return .base
        }
    }

    private static func buildWeekPlan(
        now: Date,
        goal: RaceGoal,
        phase: RacePreparationPhase,
        weeksToRace: Int,
        preferredWeekdayOffsets: [Int],
        calendar: Calendar
    ) -> [PlannedWorkout] {
        if let importedPlan = monthlyPlan(for: now, calendar: calendar) {
            let weekStart = now.startOfWeek(using: calendar)
            let weekEnd = now.startOfNextWeek(using: calendar)
            let workouts = plannedWorkouts(from: importedPlan, calendar: calendar)
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .sorted { $0.date < $1.date }
            if !workouts.isEmpty {
                return workouts
            }
        }

        if phase == .raceWeek {
            return raceWeekPlan(now: now, goal: goal, calendar: calendar)
        }

        let weekStart = now.startOfWeek(using: calendar)
        let types = workoutTypes(for: preferredWeekdayOffsets.count)
        return zip(preferredWeekdayOffsets.sorted(), types).map { offset, type in
            plannedWorkout(weekStart: weekStart, weekdayOffset: offset, type: type, phase: phase, weeksToRace: weeksToRace, calendar: calendar)
        }
    }

    private static func workoutTypes(for count: Int) -> [PlannedWorkoutType] {
        switch count {
        case ..<3:
            return [.recovery, .longRun]
        case 3:
            return [.recovery, .tempo, .longRun]
        case 4:
            return [.recovery, .intervals, .tempo, .longRun]
        default:
            return [.recovery, .intervals, .recovery, .tempo, .longRun, .recovery]
        }
    }

    private static func plannedWorkout(
        weekStart: Date,
        weekdayOffset: Int,
        type: PlannedWorkoutType,
        phase: RacePreparationPhase,
        weeksToRace: Int,
        calendar: Calendar
    ) -> PlannedWorkout {
        let date = calendar.date(byAdding: .day, value: weekdayOffset, to: weekStart) ?? weekStart
        let details = prescription(type: type, phase: phase, weeksToRace: weeksToRace)
        return PlannedWorkout(
            id: "\(date.iso8601String)-\(type.rawValue)",
            date: date,
            type: type,
            title: type.title,
            prescription: details.prescription,
            intent: details.intent,
            minDuration: details.minDuration,
            maxDuration: details.maxDuration,
            priority: details.priority
        )
    }

    private static func prescription(
        type: PlannedWorkoutType,
        phase: RacePreparationPhase,
        weeksToRace: Int
    ) -> (prescription: String, intent: String, minDuration: Int, maxDuration: Int, priority: WorkoutPriority) {
        switch (phase, type) {
        case (_, .recovery):
            return ("35-45' muy facil + movilidad", "Asimilar carga y llegar con piernas al martes.", 35, 45, .low)
        case (.base, .intervals):
            return ("Tecnica + 6x400 controlados", "Activar velocidad sin convertirlo en una carrera.", 45, 60, .high)
        case (.base, .tempo):
            return ("2x10' tempo comodo", "Aprender ritmo sostenido sin apretar de mas.", 45, 60, .high)
        case (.base, .longRun):
            return ("75-90' facil", "Construir resistencia aerobica.", 75, 90, .key)
        case (.build, .intervals):
            return ("5-6x800 a ritmo 10K", "Subir techo aerobico con recuperacion suficiente.", 55, 70, .high)
        case (.build, .tempo):
            return ("3x10' tempo o 25' continuo", "Consolidar umbral para media maraton.", 55, 70, .high)
        case (.build, .longRun):
            return ("90-110' facil, final progresivo opcional", "Aumentar tolerancia a volumen.", 90, 110, .key)
        case (.specific, .intervals):
            return ("4-5x1K controlados", "Mantener chispa sin comprometer tempo y tirada.", 55, 70, .high)
        case (.specific, .tempo):
            return ("35-45' a ritmo cercano a media", "Practicar ritmo objetivo con fatiga controlada.", 60, 75, .key)
        case (.specific, .longRun):
            return ("105-130' con bloques a ritmo media", "Simular fatiga especifica de carrera.", 105, 130, .key)
        case (.taper, .intervals):
            return ("4x600 alegres, mucho descanso", "Mantener chispa bajando volumen.", 40, 55, .medium)
        case (.taper, .tempo):
            return ("20' tempo suave", "Recordar ritmo sin acumular carga.", 40, 55, .medium)
        case (.taper, .longRun):
            return ("65-80' facil", "Llegar fresco sin perder sensaciones.", 65, 80, .high)
        default:
            return ("Rodaje facil", "Mantener continuidad.", 35, 55, .medium)
        }
    }

    private static func raceWeekPlan(now: Date, goal: RaceGoal, calendar: Calendar) -> [PlannedWorkout] {
        let weekStart = now.startOfWeek(using: calendar)
        var plan = [
            PlannedWorkout(
                id: "\(weekStart.iso8601String)-recovery",
                date: weekStart,
                type: .recovery,
                title: "Recuperacion",
                prescription: "30-40' facil + 4 progresivos",
                intent: "Soltar piernas sin cargar.",
                minDuration: 30,
                maxDuration: 40,
                priority: .medium
            ),
            plannedWorkout(weekStart: weekStart, weekdayOffset: 1, type: .intervals, phase: .raceWeek, weeksToRace: 0, calendar: calendar),
            plannedWorkout(weekStart: weekStart, weekdayOffset: 3, type: .tempo, phase: .raceWeek, weeksToRace: 0, calendar: calendar)
        ]
        plan.append(
            PlannedWorkout(
                id: "\(goal.raceDate.iso8601String)-race",
                date: goal.raceDate,
                type: .race,
                title: goal.name,
                prescription: goal.distanceName,
                intent: "Ejecutar el plan con cabeza los primeros 15 km.",
                minDuration: 0,
                maxDuration: 0,
                priority: .key
            )
        )
        return plan.sorted { $0.date < $1.date }
    }

    private static func adaptWeekPlan(
        _ weekPlan: [PlannedWorkout],
        readiness: TrainingReadiness?
    ) -> [PlannedWorkout] {
        guard let readiness else { return weekPlan }

        return weekPlan.map { workout in
            guard workout.type != .race && workout.type != .rest else { return workout }

            if readiness.riskLevel == .high && (workout.priority == .key || workout.priority == .high || workout.type == .intervals || workout.type == .tempo || workout.type == .longRun) {
                var adapted = workout
                adapted.type = .recovery
                adapted.title = "Rodaje muy facil"
                adapted.prescription = "30-45' muy faciles o descanso si las piernas no responden."
                adapted.intent = "Bajar carga y asimilar antes de volver a meter intensidad."
                adapted.minDuration = 30
                adapted.maxDuration = 45
                adapted.priority = .low
                adapted.adaptation = WorkoutAdaptation(
                    originalType: workout.type,
                    originalTitle: workout.title,
                    originalPrescription: workout.prescription,
                    reason: "Readiness en riesgo alto: conviene recortar la sesion prevista.",
                    severity: .red
                )
                return adapted
            }

            if readiness.riskLevel == .moderate && (workout.type == .intervals || workout.type == .tempo || workout.type == .longRun) {
                var adapted = workout
                let reducedMin = max(25, Int((Double(workout.minDuration) * 0.75).rounded()))
                let reducedMax = max(reducedMin, Int((Double(workout.maxDuration) * 0.75).rounded()))
                adapted.minDuration = reducedMin
                adapted.maxDuration = reducedMax
                adapted.prescription = "\(workout.prescription) Version controlada: recorta volumen 20-30% y no fuerces el ritmo."
                adapted.intent = "Mantener el estimulo sin convertirlo en carga excesiva."
                adapted.adaptation = WorkoutAdaptation(
                    originalType: workout.type,
                    originalTitle: workout.title,
                    originalPrescription: workout.prescription,
                    reason: "Readiness moderado: la sesion encaja, pero pide margen.",
                    severity: .yellow
                )
                return adapted
            }

            return workout
        }
    }

    private static func completedWorkoutIDs(
        weekPlan: [PlannedWorkout],
        activities: [Activity],
        calendar: Calendar
    ) -> Set<String> {
        var completed = Set<String>()
        for workout in weekPlan {
            let dayActivities = activities.filter { calendar.isDate($0.startDate, inSameDayAs: workout.date) }
            guard !dayActivities.isEmpty else { continue }

            switch workout.type {
            case .recovery:
                if dayActivities.contains(where: { $0.movingTime >= 20 * 60 }) { completed.insert(workout.id) }
            case .intervals, .tempo:
                if dayActivities.contains(where: { $0.movingTime >= 25 * 60 }) { completed.insert(workout.id) }
            case .longRun:
                if dayActivities.contains(where: { $0.movingTime >= 60 * 60 || $0.distance >= 12_000 }) { completed.insert(workout.id) }
            case .race:
                if dayActivities.contains(where: { $0.distance >= 20_000 }) { completed.insert(workout.id) }
            case .rest:
                break
            }
        }
        return completed
    }

    private static func adherenceFor(
        weekPlan: [PlannedWorkout],
        activities: [Activity],
        now: Date,
        calendar: Calendar
    ) -> [WorkoutAdherence] {
        weekPlan.map { workout in
            let dayActivities = activities
                .filter { calendar.isDate($0.startDate, inSameDayAs: workout.date) }
                .sorted { $0.movingTime > $1.movingTime }
            let best = dayActivities.first
            let dayIsPast = workout.date < calendar.startOfDay(for: now)
            let dayIsToday = calendar.isDate(workout.date, inSameDayAs: now)

            if let best {
                let actualMinutes = best.movingTime / 60
                let actualText = "\(best.formattedDistance) · \(TimeInterval(best.movingTime).formattedHoursMinutes)"
                let intensityMessage = intensityMessage(for: best, workout: workout)
                let status: WorkoutAdherenceStatus
                let message: String

                if actualMinutes >= workout.minDuration || best.distance >= minimumDistance(for: workout) {
                    status = workout.adaptation == nil ? .completed : .adapted
                    message = intensityMessage ?? "Sesion alineada con lo previsto."
                } else {
                    status = .partial
                    message = "Sesion mas corta de lo previsto; cuenta como continuidad, no como compensacion pendiente."
                }

                return WorkoutAdherence(
                    workoutId: workout.id,
                    status: status,
                    title: status.title,
                    message: message,
                    actualSummary: actualText
                )
            }

            if dayIsPast {
                return WorkoutAdherence(
                    workoutId: workout.id,
                    status: .missed,
                    title: "Sin registrar",
                    message: workout.priority == .key || workout.priority == .high
                        ? "Sesion clave pasada sin registrar. No la juntes con la siguiente."
                        : "Sesion pasada sin registrar; no hace falta compensarla.",
                    actualSummary: nil
                )
            }

            return WorkoutAdherence(
                workoutId: workout.id,
                status: workout.adaptation == nil ? .pending : .adapted,
                title: dayIsToday ? "Hoy" : "Pendiente",
                message: workout.adaptation?.reason ?? "Aun no hay actividad registrada para esta sesion.",
                actualSummary: nil
            )
        }
    }

    private static func minimumDistance(for workout: PlannedWorkout) -> Double {
        switch workout.type {
        case .longRun:
            return 12_000
        case .race:
            return 20_000
        case .intervals, .tempo:
            return 5_000
        case .recovery:
            return 4_000
        case .rest:
            return Double.greatestFiniteMagnitude
        }
    }

    private static func intensityMessage(for activity: Activity, workout: PlannedWorkout) -> String? {
        let maxPlannedSeconds = workout.maxDuration * 60
        if maxPlannedSeconds > 0 && activity.movingTime > Int(Double(maxPlannedSeconds) * 1.2) {
            return "Cumplida, pero mas larga de lo previsto. La siguiente sesion debe salir controlada."
        }

        if workout.type == .recovery, let hr = activity.averageHeartrate, hr >= 155 {
            return "Registrada, aunque la FC parece alta para recuperacion. Conviene suavizar la siguiente."
        }

        if workout.type == .intervals || workout.type == .tempo || workout.type == .longRun {
            return "Cumplida como sesion de calidad; evita compensar volumen extra."
        }

        return nil
    }

    private static func weekStatus(
        weekPlan: [PlannedWorkout],
        completed: Set<String>,
        now: Date,
        calendar: Calendar
    ) -> PlanWeekStatus {
        let missedKey = weekPlan.filter {
            $0.date < calendar.startOfDay(for: now)
                && !completed.contains($0.id)
                && ($0.priority == .key || $0.priority == .high)
        }
        let remainingKey = weekPlan.filter {
            $0.date >= calendar.startOfDay(for: now)
                && !completed.contains($0.id)
                && ($0.priority == .key || $0.priority == .high)
        }
        let completedCount = completed.count
        let message: String
        if missedKey.isEmpty && remainingKey.isEmpty {
            message = "Semana practicamente cerrada: no quedan sesiones clave pendientes."
        } else if missedKey.isEmpty {
            message = "Semana alineada: quedan \(remainingKey.count) sesion\(remainingKey.count == 1 ? "" : "es") clave."
        } else {
            message = "Hay \(missedKey.count) sesion\(missedKey.count == 1 ? "" : "es") clave sin registrar; evita compensar de golpe."
        }
        return PlanWeekStatus(
            completed: completedCount,
            planned: weekPlan.count,
            missedKeyWorkouts: missedKey,
            remainingKeyWorkouts: remainingKey,
            message: message
        )
    }

    private static func decisionFor(
        todayWorkout: PlannedWorkout?,
        nextWorkout: PlannedWorkout?,
        readiness: TrainingReadiness?,
        status: PlanWeekStatus,
        daysToRace: Int,
        now: Date,
        calendar: Calendar
    ) -> PlanAdjustmentDecision {
        let target = todayWorkout ?? nextWorkout
        guard let workout = target else {
            return PlanAdjustmentDecision(
                title: "Sin sesion pendiente",
                recommendation: "No metas carga extra solo por llenar huecos.",
                reason: status.message,
                severity: .blue
            )
        }

        if readiness?.riskLevel == .high {
            return PlanAdjustmentDecision(
                title: "Recortar el plan",
                recommendation: "Cambia \(workout.title.lowercased()) por 30-45' muy faciles o descanso.",
                reason: "El plan manda, pero las señales actuales indican riesgo alto. Mejor perder un entreno que comprometer el objetivo.",
                severity: .red
            )
        }

        if readiness?.riskLevel == .moderate && (workout.type == .intervals || workout.type == .tempo || workout.type == .longRun) {
            return PlanAdjustmentDecision(
                title: "Hacer version controlada",
                recommendation: "\(workout.title): reduce volumen un 20-30% y mantén la intensidad bajo control.",
                reason: "La sesion encaja con la preparacion, pero la carga actual pide no buscar heroicidades.",
                severity: .yellow
            )
        }

        if status.missedKeyWorkouts.count >= 2 {
            return PlanAdjustmentDecision(
                title: "No compensar",
                recommendation: "Haz la siguiente sesion prevista, no juntes sesiones perdidas.",
                reason: "Compensar dos sesiones clave en pocos dias sube riesgo y no mejora la preparacion.",
                severity: .yellow
            )
        }

        if daysToRace <= 21 && workout.type == .longRun {
            return PlanAdjustmentDecision(
                title: "Tirada con cabeza",
                recommendation: "\(workout.prescription). Sin competir el entrenamiento.",
                reason: "En taper/especifica final importa llegar fresco mas que exprimir una tirada.",
                severity: .blue
            )
        }

        return PlanAdjustmentDecision(
            title: todayWorkout == nil ? "Preparar siguiente sesion" : "Ejecutar plan",
            recommendation: "\(workout.title): \(workout.prescription).",
            reason: "La sesion prevista encaja con la fase \(phaseFor(daysToRace: daysToRace).title.lowercased()) y no hay señales fuertes para cambiarla.",
            severity: .green
        )
    }

    private static func monthlyBlocks() -> [MonthlyTrainingBlock] {
        [
            MonthlyTrainingBlock(month: "Mayo", focus: "Recuperar continuidad sin recaer."),
            MonthlyTrainingBlock(month: "Junio", focus: "Construccion: subir volumen y consolidar martes/jueves."),
            MonthlyTrainingBlock(month: "Julio", focus: "Construccion: tiradas mas largas y tempo progresivo."),
            MonthlyTrainingBlock(month: "Agosto", focus: "Especifica temprana: bloques a ritmo media sin sobrecargar."),
            MonthlyTrainingBlock(month: "Septiembre", focus: "Especifica: semanas clave de tempo y tirada larga."),
            MonthlyTrainingBlock(month: "Octubre", focus: "Pico y taper: afinar ritmo, bajar volumen al final."),
            MonthlyTrainingBlock(month: "Noviembre", focus: "Carrera: frescura, ejecucion y recuperacion.")
        ]
    }

    private static func monthlyPlan(for date: Date, calendar: Calendar) -> ImportedMonthlyTrainingPlan? {
        let month = monthKey(for: date, calendar: calendar)
        if let data = UserDefaults.standard.data(forKey: storageKey(for: month)),
           let plan = try? JSONDecoder().decode(ImportedMonthlyTrainingPlan.self, from: data) {
            return plan
        }
        if month == "2026-05" {
            return may2026Plan
        }
        return nil
    }

    private static func plannedWorkouts(
        from plan: ImportedMonthlyTrainingPlan,
        calendar: Calendar
    ) -> [PlannedWorkout] {
        plan.weeks.flatMap(\.workouts).compactMap { imported in
            guard let date = parseDate(imported.date, calendar: calendar) else { return nil }
            let notes = imported.notes?.isEmpty == false ? "\n" + (imported.notes ?? []).joined(separator: "\n") : ""
            return PlannedWorkout(
                id: "\(imported.date)-\(imported.type.rawValue)",
                date: date,
                type: imported.type,
                title: imported.title,
                prescription: imported.prescription + notes,
                intent: imported.intent,
                minDuration: imported.minDuration,
                maxDuration: imported.maxDuration,
                priority: imported.priority
            )
        }
    }

    private static func validate(_ plan: ImportedMonthlyTrainingPlan, calendar: Calendar = .sportBoardMadrid) throws {
        guard plan.month.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil else {
            throw TrainingPlanImportError.invalidMonth
        }
        let workouts = plan.weeks.flatMap(\.workouts)
        guard !workouts.isEmpty else {
            throw TrainingPlanImportError.emptyPlan
        }
        for workout in workouts {
            guard parseDate(workout.date, calendar: calendar) != nil else {
                throw TrainingPlanImportError.invalidDate(workout.date)
            }
        }
    }

    private static func storageKey(for month: String) -> String {
        importedPlanPrefix + month
    }

    private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private static func parseDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static var may2026Plan: ImportedMonthlyTrainingPlan {
        ImportedMonthlyTrainingPlan(
            month: "2026-05",
            objective: "Recuperar continuidad sin recaer.",
            weeks: [
                ImportedTrainingWeek(
                    name: "Semana 1 - 4 al 10 mayo",
                    focus: "Soltar, sostener ritmo alto con mas volumen y consolidar 13-14 km.",
                    workouts: [
                        ImportedPlannedWorkout(
                            date: "2026-05-04",
                            type: .recovery,
                            title: "Rodaje suave + progresivos",
                            prescription: "6-7 km suaves + 4 x 80 m progresivos controlados. Ritmo 5:25-5:55/km segun terreno.",
                            intent: "Soltar y mantener tecnica.",
                            minDuration: 35,
                            maxDuration: 50,
                            priority: .low,
                            notes: nil
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-05",
                            type: .intervals,
                            title: "6 x 1000 m",
                            prescription: "15' calentar + 6 x 1000 m a 4:10-4:16/km, recuperacion 2' suaves + 10' enfriar.",
                            intent: "Sostener ritmo alto con mas volumen.",
                            minDuration: 60,
                            maxDuration: 75,
                            priority: .high,
                            notes: ["La mejora es hacer 6 repeticiones, no correr mas rapido."]
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-07",
                            type: .tempo,
                            title: "Tempo continuo",
                            prescription: "10-15' suaves + 30' a 4:38-4:48/km + 10' suaves.",
                            intent: "Construir motor sostenido.",
                            minDuration: 50,
                            maxDuration: 65,
                            priority: .high,
                            notes: ["En Segurilla, por esfuerzo y no por ritmo exacto.", "FC aproximada 155-165; picos en subida no sostenidos."]
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-09",
                            type: .longRun,
                            title: "Tirada larga",
                            prescription: "13-14 km suaves-controlados. FC mayoritaria 140-150. Sin final fuerte.",
                            intent: "Consolidar volumen.",
                            minDuration: 70,
                            maxDuration: 90,
                            priority: .key,
                            notes: nil
                        )
                    ]
                ),
                ImportedTrainingWeek(
                    name: "Semana 2 - 11 al 17 mayo",
                    focus: "Asimilar y pasar de chispa a resistencia rapida.",
                    workouts: [
                        ImportedPlannedWorkout(
                            date: "2026-05-11",
                            type: .recovery,
                            title: "Rodaje suave",
                            prescription: "7 km comodos + 4 x 80 m progresivos si las piernas estan bien.",
                            intent: "Asimilar.",
                            minDuration: 35,
                            maxDuration: 50,
                            priority: .low,
                            notes: nil
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-12",
                            type: .intervals,
                            title: "5 x 1200 m",
                            prescription: "15' calentar + 5 x 1200 m a 4:12-4:18/km, recuperacion 2'30 suaves + 10' enfriar.",
                            intent: "Pasar de chispa a resistencia rapida.",
                            minDuration: 65,
                            maxDuration: 80,
                            priority: .high,
                            notes: ["Sesion seria; no hace falta apretar mas."]
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-14",
                            type: .tempo,
                            title: "Tempo de 6 km",
                            prescription: "2 km suaves + 6 km tempo a 4:38-4:48/km + 1-2 km suaves.",
                            intent: "Ritmo sostenido real.",
                            minDuration: 50,
                            maxDuration: 70,
                            priority: .high,
                            notes: ["En terreno ondulado, mantener esfuerzo estable y no pelear subidas."]
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-16",
                            type: .longRun,
                            title: "Tirada larga",
                            prescription: "14-15 km suave-controlada. FC mayoritaria 140-150.",
                            intent: "Primer contacto serio con 15 km.",
                            minDuration: 75,
                            maxDuration: 100,
                            priority: .key,
                            notes: ["Ultimos 2 km algo mas vivos solo si vas muy bien, no obligatorio."]
                        )
                    ]
                ),
                ImportedTrainingWeek(
                    name: "Semana 3 - 18 al 24 mayo",
                    focus: "Bloques mas largos y progresivo sostenido.",
                    workouts: [
                        ImportedPlannedWorkout(
                            date: "2026-05-18",
                            type: .recovery,
                            title: "Rodaje suave + progresivos",
                            prescription: "6-7 km suaves + 4 x 80 m progresivos.",
                            intent: "Soltar piernas.",
                            minDuration: 35,
                            maxDuration: 50,
                            priority: .low,
                            notes: nil
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-19",
                            type: .intervals,
                            title: "4 x 1600 m",
                            prescription: "15' calentar + 4 x 1600 m a 4:18-4:25/km, recuperacion 2'30-3' suaves + 10' enfriar.",
                            intent: "Sostener esfuerzo largo, no explosivo.",
                            minDuration: 70,
                            maxDuration: 85,
                            priority: .high,
                            notes: ["Muy util para media; no buscar ritmo de 5K."]
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-21",
                            type: .tempo,
                            title: "Rodaje progresivo sostenido",
                            prescription: "2 km suaves + 6 km progresivos: km 1-2 a 5:00-5:05, km 3-4 a 4:50-4:55, km 5-6 a 4:40-4:45 + 1 km suave. Total 9 km aprox.",
                            intent: "Aprender a correr de menos a mas y acabar fuerte sin ir a muerte.",
                            minDuration: 45,
                            maxDuration: 65,
                            priority: .high,
                            notes: nil
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-23",
                            type: .longRun,
                            title: "Tirada larga",
                            prescription: "15 km suaves-controlados. FC 140-150 la mayor parte.",
                            intent: "Resistencia larga y confianza.",
                            minDuration: 80,
                            maxDuration: 105,
                            priority: .key,
                            notes: ["Si vas perfecto: ultimos 2-3 km a 5:00-5:10.", "Si hay calor o fatiga: todo suave."]
                        )
                    ]
                ),
                ImportedTrainingWeek(
                    name: "Semana 4 - 25 al 31 mayo",
                    focus: "Asimilacion relativa: menos agresiva sin ser descarga total.",
                    workouts: [
                        ImportedPlannedWorkout(
                            date: "2026-05-25",
                            type: .recovery,
                            title: "Rodaje suave",
                            prescription: "6-7 km muy comodos. Sin apretar progresivos. Opcional 4 x 60 m muy suaves.",
                            intent: "Recuperar.",
                            minDuration: 35,
                            maxDuration: 50,
                            priority: .low,
                            notes: nil
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-26",
                            type: .intervals,
                            title: "Fartlek largo",
                            prescription: "15' calentar + 5 x 5' a 4:15-4:22/km, recuperacion 2' suaves + 10' enfriar.",
                            intent: "Sostener ritmo vivo con fatiga controlada.",
                            minDuration: 65,
                            maxDuration: 80,
                            priority: .high,
                            notes: ["Mas duracion por repeticion, no mas velocidad."]
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-28",
                            type: .tempo,
                            title: "Tempo largo",
                            prescription: "Opcion principal: 10-15' suaves + 35' a 4:40-4:50/km + 10' suaves. Alternativa: 2 x 18' a 4:38-4:48/km, recuperacion 2' suaves.",
                            intent: "Meter volumen real de tempo.",
                            minDuration: 60,
                            maxDuration: 80,
                            priority: .key,
                            notes: ["Usar alternativa si hay terreno duro o calor."]
                        ),
                        ImportedPlannedWorkout(
                            date: "2026-05-30",
                            type: .longRun,
                            title: "Tirada larga de asimilacion",
                            prescription: "12-13 km suaves, sin apretar, FC comoda.",
                            intent: "Cerrar el mes sin acumular fatiga excesiva.",
                            minDuration: 65,
                            maxDuration: 85,
                            priority: .key,
                            notes: nil
                        )
                    ]
                )
            ]
        )
    }

    private static func fetchRuns(modelContext: ModelContext) throws -> [Activity] {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        let all = try modelContext.fetch(descriptor)
        return all.filter { runTypes.contains($0.sportType.lowercased()) }
    }
}
