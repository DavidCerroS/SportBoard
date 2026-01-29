//
//  ActivitiesViewModel.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ActivitiesViewModel {
    var activities: [Activity] = []
    var filteredActivities: [Activity] = []
    
    var searchText: String = "" {
        didSet { applyFilters() }
    }
    
    var selectedSportType: String? {
        didSet { applyFilters() }
    }
    
    var sortOrder: SortOrder = .dateDescending {
        didSet { applyFilters() }
    }
    
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
    
    var sportTypes: [String] = []
    
    private var modelContext: ModelContext?
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Más recientes"
        case dateAscending = "Más antiguos"
        case distanceDescending = "Mayor distancia"
        case distanceAscending = "Menor distancia"
        case durationDescending = "Mayor duración"
        case durationAscending = "Menor duración"
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func loadActivities() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<Activity>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            
            activities = try context.fetch(descriptor)
            
            // Obtener tipos de deporte únicos
            sportTypes = Array(Set(activities.map { $0.sportType })).sorted()
            
            applyFilters()
            
        } catch {
            print("Error loading activities: \(error)")
        }
    }
    
    func applyFilters() {
        var result = activities
        
        // Filtro por búsqueda
        if !searchText.isEmpty {
            result = result.filter { activity in
                activity.name.localizedCaseInsensitiveContains(searchText) ||
                activity.sportType.sportDisplayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filtro por tipo de deporte
        if let sport = selectedSportType {
            result = result.filter { $0.sportType == sport }
        }
        
        // Filtro por rango de fechas
        if let start = dateRangeStart {
            result = result.filter { $0.startDate >= start }
        }
        
        if let end = dateRangeEnd {
            result = result.filter { $0.startDate <= end }
        }
        
        // Ordenamiento
        switch sortOrder {
        case .dateDescending:
            result.sort { $0.startDate > $1.startDate }
        case .dateAscending:
            result.sort { $0.startDate < $1.startDate }
        case .distanceDescending:
            result.sort { $0.distance > $1.distance }
        case .distanceAscending:
            result.sort { $0.distance < $1.distance }
        case .durationDescending:
            result.sort { $0.movingTime > $1.movingTime }
        case .durationAscending:
            result.sort { $0.movingTime < $1.movingTime }
        }
        
        filteredActivities = result
    }
    
    func clearFilters() {
        searchText = ""
        selectedSportType = nil
        dateRangeStart = nil
        dateRangeEnd = nil
        sortOrder = .dateDescending
        applyFilters()
    }
    
    var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedSportType != nil || dateRangeStart != nil || dateRangeEnd != nil
    }
    
    var filterDescription: String {
        var parts: [String] = []
        
        if let sport = selectedSportType {
            parts.append(sport.sportDisplayName)
        }
        
        if dateRangeStart != nil || dateRangeEnd != nil {
            parts.append("Rango de fechas")
        }
        
        if !searchText.isEmpty {
            parts.append("Búsqueda: \(searchText)")
        }
        
        return parts.isEmpty ? "Sin filtros" : parts.joined(separator: ", ")
    }
}
