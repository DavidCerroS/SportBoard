//
//  SyncState.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData

/// Estado de sincronización persistido para poder reanudar
@Model
final class SyncState {
    @Attribute(.unique) var id: String = "main"
    
    // Última sincronización exitosa
    var lastSyncedAt: Date?
    var lastActivityDate: Date?
    
    // Estado de la sincronización actual
    var isFirstSync: Bool
    var currentPhase: SyncPhase
    var totalActivities: Int
    var syncedActivities: Int
    var currentYear: Int?
    
    // Cursor para reanudar
    var currentPage: Int
    var lastProcessedActivityId: Int64?
    
    // Actividades con errores (para reintentar después)
    var failedActivityIds: [Int64]
    
    // Control de rate limiting
    var requestsThisPeriod: Int
    var periodStartTime: Date?
    
    init(
        id: String = "main",
        lastSyncedAt: Date? = nil,
        lastActivityDate: Date? = nil,
        isFirstSync: Bool = true,
        currentPhase: SyncPhase = .idle,
        totalActivities: Int = 0,
        syncedActivities: Int = 0,
        currentYear: Int? = nil,
        currentPage: Int = 1,
        lastProcessedActivityId: Int64? = nil,
        failedActivityIds: [Int64] = [],
        requestsThisPeriod: Int = 0,
        periodStartTime: Date? = nil
    ) {
        self.id = id
        self.lastSyncedAt = lastSyncedAt
        self.lastActivityDate = lastActivityDate
        self.isFirstSync = isFirstSync
        self.currentPhase = currentPhase
        self.totalActivities = totalActivities
        self.syncedActivities = syncedActivities
        self.currentYear = currentYear
        self.currentPage = currentPage
        self.lastProcessedActivityId = lastProcessedActivityId
        self.failedActivityIds = failedActivityIds
        self.requestsThisPeriod = requestsThisPeriod
        self.periodStartTime = periodStartTime
    }
    
    func reset() {
        currentPhase = .idle
        totalActivities = 0
        syncedActivities = 0
        currentYear = nil
        currentPage = 1
        lastProcessedActivityId = nil
        failedActivityIds = []
    }
    
    func markSyncComplete() {
        lastSyncedAt = Date()
        isFirstSync = false
        currentPhase = .idle
        currentPage = 1
        lastProcessedActivityId = nil
    }
}

// MARK: - Sync Phase

enum SyncPhase: String, Codable {
    case idle = "idle"
    case fetchingActivities = "fetching_activities"
    case fetchingDetails = "fetching_details"
    case fetchingLaps = "fetching_laps"
    case completed = "completed"
    case paused = "paused"
    case error = "error"
    
    var displayText: String {
        switch self {
        case .idle: return "Listo"
        case .fetchingActivities: return "Obteniendo actividades..."
        case .fetchingDetails: return "Descargando detalles..."
        case .fetchingLaps: return "Descargando parciales..."
        case .completed: return "Completado"
        case .paused: return "Pausado"
        case .error: return "Error"
        }
    }
}

// MARK: - Computed Properties

extension SyncState {
    var progressText: String {
        guard totalActivities > 0 else { return "" }
        return "\(syncedActivities)/\(totalActivities)"
    }
    
    var progressPercentage: Double {
        guard totalActivities > 0 else { return 0 }
        return Double(syncedActivities) / Double(totalActivities)
    }
    
    var yearText: String {
        guard let year = currentYear else { return "" }
        return "Va por \(year)..."
    }
    
    var lastSyncText: String {
        guard let date = lastSyncedAt else { return "Nunca sincronizado" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        return "Última sync: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
    
    var hasFailedActivities: Bool {
        !failedActivityIds.isEmpty
    }
    
    var failedCount: Int {
        failedActivityIds.count
    }
}
