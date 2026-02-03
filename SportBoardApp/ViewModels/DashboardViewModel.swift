//
//  DashboardViewModel.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class DashboardViewModel {
    var totalActivities: Int = 0
    var totalDistance: Double = 0
    var totalTime: Int = 0
    var totalElevation: Double = 0
    var averageHeartrate: Double?
    
    var thisWeekDistance: Double = 0
    var thisWeekTime: Int = 0
    var thisWeekActivities: Int = 0
    
    var thisMonthDistance: Double = 0
    var thisMonthTime: Int = 0
    var thisMonthActivities: Int = 0
    
    var sportTypeCounts: [String: Int] = [:]
    var recentActivities: [Activity] = []
    
    var selectedSportFilter: String?
    
    // Inteligencia local (carrera)
    var profile: RunnerProfile?
    var consistencyBreakdown: ConsistencyBreakdown?
    var fatigueDiagnosis: FatigueDiagnosis?
    var weeklyNarrative: String = ""
    var nextWorkoutSuggestion: NextWorkoutSuggestion?
    var silentAlerts: [SilentAlert] = []
    var efficiencyTrend: EfficiencyTrendResult?
    var suspiciousPeak: SuspiciousPeakResult?
    
    private var modelContext: ModelContext?
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func loadStats() {
        guard let context = modelContext else { return }
        
        do {
            // Obtener todas las actividades
            var descriptor = FetchDescriptor<Activity>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            
            if let sport = selectedSportFilter {
                descriptor.predicate = #Predicate { $0.sportType == sport }
            }
            
            let activities = try context.fetch(descriptor)
            
            // Stats totales
            totalActivities = activities.count
            totalDistance = activities.reduce(0) { $0 + $1.distance }
            totalTime = activities.reduce(0) { $0 + $1.movingTime }
            totalElevation = activities.reduce(0) { $0 + $1.totalElevationGain }
            
            // FC media (solo actividades con HR)
            let activitiesWithHR = activities.filter { $0.averageHeartrate != nil }
            if !activitiesWithHR.isEmpty {
                averageHeartrate = activitiesWithHR.compactMap { $0.averageHeartrate }.reduce(0, +) / Double(activitiesWithHR.count)
            } else {
                averageHeartrate = nil
            }
            
            // Stats esta semana: rango [startOfWeek, startOfNextWeek) en Europe/Madrid, solo Run
            let now = Date()
            let weekStart = now.startOfWeekMadrid
            let weekEnd = now.startOfNextWeekMadrid
            let runTypes = ["run", "virtualrun", "trailrun"]
            let thisWeekRuns = activities.filter { act in
                runTypes.contains(act.sportType.lowercased())
                    && act.startDate >= weekStart
                    && act.startDate < weekEnd
            }
            self.thisWeekActivities = thisWeekRuns.count
            thisWeekDistance = thisWeekRuns.reduce(0) { $0 + $1.distance }
            thisWeekTime = thisWeekRuns.reduce(0) { $0 + $1.movingTime }
            #if DEBUG
            let df = ISO8601DateFormatter()
            df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            print("[SportBoard] Esta semana: startOfWeek=\(df.string(from: weekStart)) startOfNextWeek=\(df.string(from: weekEnd)) runs=\(thisWeekRuns.count) fechas=\(thisWeekRuns.map { df.string(from: $0.startDate) })")
            #endif
            
            // Stats este mes
            let monthStart = Date().startOfMonth
            let thisMonthActivities = activities.filter { $0.startDate >= monthStart }
            self.thisMonthActivities = thisMonthActivities.count
            thisMonthDistance = thisMonthActivities.reduce(0) { $0 + $1.distance }
            thisMonthTime = thisMonthActivities.reduce(0) { $0 + $1.movingTime }
            
            // Conteo por tipo de deporte (sin filtro)
            let allActivities = try context.fetch(FetchDescriptor<Activity>())
            var counts: [String: Int] = [:]
            for activity in allActivities {
                counts[activity.sportType, default: 0] += 1
            }
            sportTypeCounts = counts
            
            // Actividades recientes
            recentActivities = Array(activities.prefix(5))
            
        } catch {
            print("Error loading stats: \(error)")
        }
        
        loadIntelligence()
    }
    
    /// Carga perfil, consistencia, fatiga, narrativa, sugerencia y alertas (solo datos locales).
    private func loadIntelligence() {
        guard let context = modelContext else { return }
        
        do {
            if try RunnerProfileService.shouldRecompute(modelContext: context) {
                try RunnerProfileService.computeAndSave(modelContext: context)
            }
            profile = try RunnerProfileService.fetchProfile(modelContext: context)
        } catch {
            profile = nil
        }
        
        do {
            consistencyBreakdown = try ConsistencyService.compute(modelContext: context, profile: profile)
        } catch {
            consistencyBreakdown = nil
        }
        
        do {
            fatigueDiagnosis = try FatigueService.compute(modelContext: context, profile: profile)
        } catch {
            fatigueDiagnosis = nil
        }
        
        do {
            efficiencyTrend = try EfficiencyTrendService.compute(modelContext: context, profile: profile, fatigue: fatigueDiagnosis)
        } catch {
            efficiencyTrend = nil
        }
        
        do {
            weeklyNarrative = try WeeklyNarrativeService.generate(
                modelContext: context,
                profile: profile,
                consistency: consistencyBreakdown,
                fatigue: fatigueDiagnosis,
                efficiencyTrend: efficiencyTrend?.direction
            )
        } catch {
            weeklyNarrative = ""
        }
        
        do {
            nextWorkoutSuggestion = try NextWorkoutSuggestionService.suggest(
                modelContext: context,
                profile: profile,
                fatigue: fatigueDiagnosis,
                consistency: consistencyBreakdown
            )
        } catch {
            nextWorkoutSuggestion = nil
        }
        
        do {
            silentAlerts = try SilentAlertsService.evaluate(
                modelContext: context,
                profile: profile,
                efficiencyTrend: efficiencyTrend,
                consistency: consistencyBreakdown,
                fatigue: fatigueDiagnosis
            )
        } catch {
            silentAlerts = []
        }
        
        do {
            suspiciousPeak = try SuspiciousPeakDetector.evaluate(modelContext: context, profile: profile)
        } catch {
            suspiciousPeak = nil
        }
    }
    
    func setSportFilter(_ sport: String?) {
        selectedSportFilter = sport
        loadStats()
    }
    
    var sortedSportTypes: [(sport: String, count: Int)] {
        sportTypeCounts
            .map { (sport: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    var formattedTotalDistance: String {
        totalDistance.formattedDistanceKm
    }
    
    var formattedTotalTime: String {
        TimeInterval(totalTime).formattedHoursMinutes
    }
    
    var formattedTotalElevation: String {
        totalElevation.formattedElevation
    }
    
    var formattedThisWeekDistance: String {
        thisWeekDistance.formattedDistanceKm
    }
    
    var formattedThisMonthDistance: String {
        thisMonthDistance.formattedDistanceKm
    }
}
