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
            
            // Stats esta semana
            let weekStart = Date().startOfWeek
            let thisWeekActivities = activities.filter { $0.startDate >= weekStart }
            self.thisWeekActivities = thisWeekActivities.count
            thisWeekDistance = thisWeekActivities.reduce(0) { $0 + $1.distance }
            thisWeekTime = thisWeekActivities.reduce(0) { $0 + $1.movingTime }
            
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
