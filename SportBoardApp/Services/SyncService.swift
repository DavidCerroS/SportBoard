//
//  SyncService.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData
import Combine

// MARK: - Sync Progress

@MainActor
final class SyncProgress: ObservableObject {
    @Published var phase: SyncPhase = .idle
    @Published var totalActivities: Int = 0
    @Published var syncedActivities: Int = 0
    @Published var currentYear: Int?
    @Published var lastActivityName: String?
    @Published var lastActivityDate: Date?
    @Published var errorMessage: String?
    @Published var failedCount: Int = 0
    
    // Rate Limit tracking
    @Published var isRateLimited: Bool = false
    @Published var rateLimitResetDate: Date?
    @Published var timerTick: Int = 0 // Fuerza actualización cada segundo
    
    var progressText: String {
        guard totalActivities > 0 else { return "" }
        return "Sincronizando \(syncedActivities)/\(totalActivities)"
    }
    
    var yearText: String {
        guard let year = currentYear else { return "" }
        return "Va por \(year)..."
    }
    
    var progressPercentage: Double {
        guard totalActivities > 0 else { return 0 }
        return Double(syncedActivities) / Double(totalActivities)
    }
    
    var isActive: Bool {
        switch phase {
        case .fetchingActivities, .fetchingDetails, .fetchingLaps:
            return true
        default:
            return false
        }
    }
    
    var rateLimitRemainingSeconds: Int {
        guard let resetDate = rateLimitResetDate else { return 0 }
        return max(0, Int(resetDate.timeIntervalSinceNow))
    }
    
    var rateLimitRemainingText: String {
        let seconds = rateLimitRemainingSeconds
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    func reset() {
        phase = .idle
        totalActivities = 0
        syncedActivities = 0
        currentYear = nil
        lastActivityName = nil
        lastActivityDate = nil
        errorMessage = nil
        failedCount = 0
        isRateLimited = false
        rateLimitResetDate = nil
    }
    
    func setRateLimited(resetIn seconds: Int = 900) {
        isRateLimited = true
        rateLimitResetDate = Date().addingTimeInterval(TimeInterval(seconds))
        phase = .paused
        errorMessage = "Límite de API alcanzado. Esperando..."
    }
    
    func clearRateLimit() {
        isRateLimited = false
        rateLimitResetDate = nil
        errorMessage = nil
    }
}

// MARK: - Sync Service

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var progress = SyncProgress()
    @Published var isCancelled = false
    
    private let api = StravaAPIService.shared
    private var syncTask: Task<Void, Never>?
    private var rateLimitTimerTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var periodStartTime: Date? // Cuándo empezó el período de 15 min
    
    private init() {}
    
    deinit {
        rateLimitTimerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Inicia la sincronización
    func startSync(fullSync: Bool = false) {
        // Si hay una tarea en ejecución, no iniciar otra
        if syncTask != nil && !progress.isRateLimited {
            return
        }
        
        // Limpiar tarea anterior si estaba en rate limit
        syncTask?.cancel()
        syncTask = nil
        rateLimitTimerTask?.cancel()
        rateLimitTimerTask = nil
        
        isCancelled = false
        
        // Solo resetear progreso si no estamos reanudando después de rate limit
        if !progress.isRateLimited {
            progress.reset()
            periodStartTime = Date() // Nuevo período empieza ahora
        } else {
            // Limpiar el rate limit pero mantener el progreso
            progress.isRateLimited = false
            progress.rateLimitResetDate = nil
            progress.errorMessage = nil
            periodStartTime = Date() // Nuevo período después del rate limit
        }
        
        syncTask = Task {
            await performSync(fullSync: fullSync)
            syncTask = nil
        }
    }
    
    /// Cancela la sincronización actual
    func cancelSync() {
        isCancelled = true
        syncTask?.cancel()
        progress.phase = .paused
    }
    
    /// Reanuda una sincronización pausada
    func resumeSync() {
        guard progress.phase == .paused else { return }
        // Al reanudar después de rate limit, hacer sync completa para continuar donde se quedó
        startSync(fullSync: true)
    }
    
    /// Carga los detalles de una actividad bajo demanda (laps y splits)
    func fetchActivityDetailsOnDemand(activity: Activity, context: ModelContext) async throws {
        if activity.detailsFetched {
            try await backfillElevationBreakdownsIfNeeded(activity: activity, context: context)
            return
        }
        
        let detail = try await api.getActivityDetail(id: activity.id, includeAllEfforts: true)
        
        // Debug: mostrar datos raw de Strava
        printStravaDebug(detail: detail, activityName: activity.name)

        applyActivityMetadata(detail, to: activity)
        activity.detailsFetched = true

        await applyActivityDetail(detail, to: activity, context: context)
        await fetchActivityEnrichment(activity: activity, detail: detail, context: context)
        try context.save()
    }

    func backfillElevationBreakdownsIfNeeded(activity: Activity, context: ModelContext) async throws {
        let laps = activity.sortedLaps ?? []
        let splits = activity.sortedSplits ?? []

        let needsPowerBackfill = isRunSportType(activity.sportType) && (
            laps.contains { $0.averageWatts == nil || $0.maxWatts == nil } ||
            splits.contains { $0.averageWatts == nil || $0.maxWatts == nil }
        )
        let needsBackfill = laps.contains { $0.positiveElevationGain == nil || $0.negativeElevationLoss == nil } ||
            splits.contains { $0.positiveElevationGain == nil || $0.negativeElevationLoss == nil } ||
            needsPowerBackfill ||
            (!laps.isEmpty && activity.sortedTempoBlockSplits.isEmpty)

        guard needsBackfill else { return }

        guard let breakdowns = await fetchMetricBreakdowns(
            activity: activity,
            activityId: activity.id,
            lapSegments: laps.map {
                LapElevationSegment(
                    lapIndex: $0.lapIndex,
                    name: $0.name,
                    distance: $0.distance,
                    movingTime: $0.movingTime,
                    elapsedTime: $0.elapsedTime,
                    startIndex: $0.startIndex,
                    endIndex: $0.endIndex,
                    positiveElevationGain: $0.totalElevationGain,
                    averageSpeed: $0.averageSpeed
                )
            },
            splitDistances: splits.map(\.distance),
            context: context
        ) else {
            return
        }

        for (lap, breakdown) in zip(laps, breakdowns.laps) {
            lap.positiveElevationGain = breakdown.elevation.positive
            lap.negativeElevationLoss = breakdown.elevation.negative
            lap.averageWatts = breakdown.power?.average
            lap.maxWatts = breakdown.power?.max
            lap.maxHeartrate = breakdown.maxHeartRate
            lap.averageCadence = breakdown.averageCadence
            lap.averageGrade = breakdown.averageGrade
            lap.movingTimeFromStream = breakdown.movingTimeSeconds
        }

        for (split, breakdown) in zip(splits, breakdowns.splits) {
            split.positiveElevationGain = breakdown.elevation.positive
            split.negativeElevationLoss = breakdown.elevation.negative
            split.averageWatts = breakdown.power?.average
            split.maxWatts = breakdown.power?.max
            split.maxHeartrate = breakdown.maxHeartRate
            split.averageCadence = breakdown.averageCadence
            split.averageGrade = breakdown.averageGrade
            split.movingTimeFromStream = breakdown.movingTimeSeconds
        }

        try context.save()
    }
    
    // MARK: - Private Methods
    
    private func performSync(fullSync: Bool) async {
        guard let context = modelContext else {
            progress.errorMessage = "Error de configuración"
            progress.phase = .error
            return
        }
        
        do {
            // Obtener o crear el estado de sincronización
            let syncState = try getSyncState(context: context)
            
            // Determinar si es primera sync
            let isFirstSync = syncState.lastSyncedAt == nil || fullSync
            
            progress.phase = .fetchingActivities
            
            if isFirstSync {
                // Primera sincronización: ventana de 90 días primero
                await performFirstSync(context: context, syncState: syncState)
            } else {
                // Sincronización incremental
                await performIncrementalSync(context: context, syncState: syncState)
            }
            
            // Solo marcar como completado si no hay rate limit ni cancelación
            if !isCancelled && !progress.isRateLimited {
                syncState.markSyncComplete()
                try context.save()
                progress.phase = .completed
            }
            
        } catch {
            progress.errorMessage = error.localizedDescription
            progress.phase = .error
        }
    }
    
    private func performFirstSync(context: ModelContext, syncState: SyncState) async {
        // Fase 1: Últimos 90 días (prioritario)
        let windowStart = Date().daysAgo(Constants.Sync.initialSyncWindowDays)
        
        do {
            // Obtener actividades de la ventana inicial
            var page = syncState.currentPage
            var hasMore = true
            var allActivities: [StravaActivitySummary] = []
            
            while hasMore && !isCancelled && !progress.isRateLimited {
                let activities = try await fetchWithRetry {
                    try await self.api.getActivities(page: page, perPage: Constants.Sync.activitiesPerPage, after: windowStart)
                }
                
                if activities.isEmpty {
                    hasMore = false
                } else {
                    allActivities.append(contentsOf: activities)
                    page += 1
                    
                    // Guardar cursor
                    syncState.currentPage = page
                    try? context.save()
                    
                    // Delay entre requests
                    try? await Task.sleep(nanoseconds: Constants.Sync.requestDelayMs)
                }
            }
            
            progress.totalActivities = allActivities.count
            
            // Procesar actividades de la ventana
            for (index, summary) in allActivities.enumerated() {
                guard !isCancelled && !progress.isRateLimited else { break }
                
                await processActivity(summary: summary, context: context, syncState: syncState)
                
                // Si se activó rate limit, salir
                if progress.isRateLimited { break }
                
                progress.syncedActivities = index + 1
                progress.lastActivityName = summary.name
                
                if let date = parseStravaDate(summary.startDate) {
                    progress.lastActivityDate = date
                    progress.currentYear = date.year
                }
            }
            
            // Fase 2: Resto histórico en segundo plano
            if !isCancelled && !progress.isRateLimited {
                await fetchHistoricalActivities(before: windowStart, context: context, syncState: syncState)
            }
            
        } catch {
            handleSyncError(error, context: context, syncState: syncState)
        }
    }
    
    private func performIncrementalSync(context: ModelContext, syncState: SyncState) async {
        guard let lastSync = syncState.lastSyncedAt else {
            // Si no hay última sync, hacer sync completa
            await performFirstSync(context: context, syncState: syncState)
            return
        }
        
        do {
            var page = 1
            var hasMore = true
            var newActivities: [StravaActivitySummary] = []
            
            while hasMore && !isCancelled && !progress.isRateLimited {
                let activities = try await fetchWithRetry {
                    try await self.api.getActivities(page: page, perPage: Constants.Sync.activitiesPerPage, after: lastSync)
                }
                
                if activities.isEmpty {
                    hasMore = false
                } else {
                    newActivities.append(contentsOf: activities)
                    page += 1
                    
                    try? await Task.sleep(nanoseconds: Constants.Sync.requestDelayMs)
                }
            }
            
            progress.totalActivities = newActivities.count
            
            for (index, summary) in newActivities.enumerated() {
                guard !isCancelled && !progress.isRateLimited else { break }
                
                await processActivity(summary: summary, context: context, syncState: syncState)
                
                // Si se activó rate limit, salir
                if progress.isRateLimited { break }
                
                progress.syncedActivities = index + 1
                progress.lastActivityName = summary.name
                
                if let date = parseStravaDate(summary.startDate) {
                    progress.lastActivityDate = date
                    progress.currentYear = date.year
                }
            }
            
        } catch {
            handleSyncError(error, context: context, syncState: syncState)
        }
    }
    
    private func fetchHistoricalActivities(before: Date, context: ModelContext, syncState: SyncState) async {
        do {
            var page = 1
            var hasMore = true
            
            while hasMore && !isCancelled && !progress.isRateLimited {
                let activities = try await fetchWithRetry {
                    try await self.api.getActivities(page: page, perPage: Constants.Sync.activitiesPerPage, before: before)
                }
                
                if activities.isEmpty {
                    hasMore = false
                } else {
                    progress.totalActivities += activities.count
                    
                    for summary in activities {
                        guard !isCancelled && !progress.isRateLimited else { return }
                        
                        await processActivity(summary: summary, context: context, syncState: syncState)
                        
                        // Si se activó rate limit durante processActivity, salir
                        if progress.isRateLimited { return }
                        
                        progress.syncedActivities += 1
                        progress.lastActivityName = summary.name
                        
                        if let date = parseStravaDate(summary.startDate) {
                            progress.lastActivityDate = date
                            progress.currentYear = date.year
                        }
                    }
                    
                    page += 1
                    syncState.currentPage = page
                    try? context.save()
                    
                    try? await Task.sleep(nanoseconds: Constants.Sync.requestDelayMs)
                }
            }
        } catch {
            // Manejar rate limit
            handleSyncError(error, context: context, syncState: syncState)
        }
    }
    
    private func processActivity(summary: StravaActivitySummary, context: ModelContext, syncState: SyncState) async {
        // Verificar si ya existe
        let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == summary.id })
        if let existing = try? context.fetch(descriptor).first {
            // Ya existe, actualizar si es necesario
            updateActivity(existing, from: summary)
            try? context.save()
            return
        }
        
        // Crear nueva actividad solo con datos del summary
        // Los detalles (laps/splits) se cargan bajo demanda cuando el usuario abre la actividad
        guard let startDate = parseStravaDate(summary.startDate) else { return }
        
        // Parsear fecha local (sin timezone, como la web usa startDateLocal)
        let startDateLocal = parseStravaDateLocal(summary.startDateLocal) ?? startDate
        
        let activity = Activity(
            id: summary.id,
            name: summary.name,
            sportType: summary.sportType,
            startDate: startDate,
            startDateLocal: startDateLocal,
            distance: summary.distance,
            movingTime: summary.movingTime,
            elapsedTime: summary.elapsedTime,
            totalElevationGain: summary.totalElevationGain,
            averageSpeed: summary.averageSpeed,
            maxSpeed: summary.maxSpeed,
            averageHeartrate: summary.averageHeartrate,
            maxHeartrate: summary.maxHeartrate,
            averageWatts: summary.averageWatts,
            maxWatts: summary.maxWatts,
            kilojoules: summary.kilojoules,
            hasHeartrate: summary.hasHeartrate ?? false,
            hasPowerMeter: summary.deviceWatts ?? false,
            workoutType: summary.workoutType,
            calories: summary.calories,
            gearId: summary.gearId,
            trainer: summary.trainer ?? false,
            manual: summary.manual ?? false,
            isPrivate: summary.isPrivate ?? false,
            flagged: summary.flagged ?? false,
            elevHigh: summary.elevHigh,
            elevLow: summary.elevLow,
            startLatitude: summary.startLatlng?.first,
            startLongitude: summary.startLatlng?.dropFirst().first,
            endLatitude: summary.endLatlng?.first,
            endLongitude: summary.endLatlng?.dropFirst().first,
            summaryPolyline: summary.map?.summaryPolyline,
            achievementCount: summary.achievementCount,
            kudosCount: summary.kudosCount,
            commentCount: summary.commentCount,
            athleteCount: summary.athleteCount,
            photoCount: summary.photoCount,
            weightedAverageWatts: summary.weightedAverageWatts
        )
        
        // NO llamar a fetchActivityDetails aquí
        // Los detalles se cargarán bajo demanda en ActivityDetailView
        activity.detailsFetched = false
        
        context.insert(activity)
        
        // Guardar después de procesar cada actividad
        try? context.save()
    }
    
    private func fetchActivityDetails(activity: Activity, context: ModelContext, syncState: SyncState) async {
        do {
            let detail = try await fetchWithRetry {
                try await self.api.getActivityDetail(id: activity.id, includeAllEfforts: true)
            }
            
            applyActivityMetadata(detail, to: activity)
            activity.detailsFetched = true
            await applyActivityDetail(detail, to: activity, context: context)
            await fetchActivityEnrichment(activity: activity, detail: detail, context: context)
            
            try? await Task.sleep(nanoseconds: Constants.Sync.requestDelayMs)
            
        } catch let error as StravaAPIError {
            if case .rateLimited(let retryAfter) = error {
                // Rate limit: activar timer y pausar
                let waitTime = retryAfter ?? calculateRateLimitResetTime()
                progress.setRateLimited(resetIn: max(waitTime, 60)) // Mínimo 1 minuto
                startRateLimitTimer()
                try? context.save()
            } else {
                // Otros errores: registrar y continuar
                syncState.failedActivityIds.append(activity.id)
                progress.failedCount += 1
                print("Error fetching details for activity \(activity.id): \(error)")
            }
        } catch {
            // Registrar error pero continuar
            syncState.failedActivityIds.append(activity.id)
            progress.failedCount += 1
            print("Error fetching details for activity \(activity.id): \(error)")
        }
    }
    
    private func updateActivity(_ activity: Activity, from summary: StravaActivitySummary) {
        activity.name = summary.name
        activity.distance = summary.distance
        activity.movingTime = summary.movingTime
        activity.elapsedTime = summary.elapsedTime
        activity.totalElevationGain = summary.totalElevationGain
        activity.averageSpeed = summary.averageSpeed
        activity.maxSpeed = summary.maxSpeed
        activity.averageHeartrate = summary.averageHeartrate
        activity.maxHeartrate = summary.maxHeartrate
        activity.averageWatts = summary.averageWatts
        activity.maxWatts = summary.maxWatts
        activity.kilojoules = summary.kilojoules
        activity.hasHeartrate = summary.hasHeartrate ?? activity.hasHeartrate
        activity.hasPowerMeter = summary.deviceWatts ?? activity.hasPowerMeter
        activity.workoutType = summary.workoutType ?? activity.workoutType
        activity.calories = summary.calories ?? activity.calories
        activity.gearId = summary.gearId ?? activity.gearId
        activity.trainer = summary.trainer ?? activity.trainer
        activity.manual = summary.manual ?? activity.manual
        activity.isPrivate = summary.isPrivate ?? activity.isPrivate
        activity.flagged = summary.flagged ?? activity.flagged
        activity.elevHigh = summary.elevHigh ?? activity.elevHigh
        activity.elevLow = summary.elevLow ?? activity.elevLow
        activity.startLatitude = summary.startLatlng?.first ?? activity.startLatitude
        activity.startLongitude = summary.startLatlng?.dropFirst().first ?? activity.startLongitude
        activity.endLatitude = summary.endLatlng?.first ?? activity.endLatitude
        activity.endLongitude = summary.endLatlng?.dropFirst().first ?? activity.endLongitude
        activity.summaryPolyline = summary.map?.summaryPolyline ?? activity.summaryPolyline
        activity.achievementCount = summary.achievementCount ?? activity.achievementCount
        activity.kudosCount = summary.kudosCount ?? activity.kudosCount
        activity.commentCount = summary.commentCount ?? activity.commentCount
        activity.athleteCount = summary.athleteCount ?? activity.athleteCount
        activity.photoCount = summary.photoCount ?? activity.photoCount
        activity.weightedAverageWatts = summary.weightedAverageWatts ?? activity.weightedAverageWatts
        activity.syncedAt = Date()
    }
    
    // MARK: - Retry Logic
    
    private func fetchWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        var delay = Constants.Sync.initialRetryDelay
        
        for attempt in 0..<Constants.Sync.maxRetries {
            do {
                let result = try await operation()
                // Actualizar info de rate limit después de cada llamada exitosa
                await updateRateLimitInfo()
                return result
            } catch let error as StravaAPIError {
                lastError = error
                
                // Actualizar info de rate limit incluso en error
                await updateRateLimitInfo()
                
                switch error {
                case .rateLimited:
                    // No reintentar rate limit, propagarlo para manejar con timer
                    throw error
                case .unauthorized:
                    // Errores no recuperables: no reintentar
                    throw error
                default:
                    // Errores recuperables: aplicar backoff y reintentar
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2 // Backoff exponencial
                    print("Retry attempt \(attempt + 1) after error: \(error)")
                }
            } catch {
                throw error
            }
        }
        
        throw lastError ?? StravaAPIError.unknown
    }
    
    // MARK: - Helpers
    
    private func getSyncState(context: ModelContext) throws -> SyncState {
        let descriptor = FetchDescriptor<SyncState>(predicate: #Predicate { $0.id == "main" })
        
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        
        let newState = SyncState()
        context.insert(newState)
        try context.save()
        return newState
    }
    
    private func parseStravaDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Intentar sin fracciones de segundo
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    /// Parsea la fecha local de Strava (start_date_local)
    /// Strava devuelve "2026-01-29T11:03:15Z" donde la hora YA ES la hora local del atleta
    /// Ignoramos la Z y parseamos los valores tal cual
    private func parseStravaDateLocal(_ dateString: String) -> Date? {
        // Strava start_date_local viene como "2026-01-29T11:03:15Z"
        // La "Z" es engañosa - los valores ya son la hora local del atleta
        // Parseamos ignorando timezone para preservar h:m:s exactos
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Interpretar como UTC para no modificar valores
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Intentar con fracciones de segundo
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.date(from: dateString)
    }
    
    private func handleSyncError(_ error: Error, context: ModelContext, syncState: SyncState) {
        progress.errorMessage = error.localizedDescription
        
        if let apiError = error as? StravaAPIError {
            switch apiError {
            case .rateLimited(let retryAfter):
                // Usar el tiempo del header si existe, sino calcular basado en el período
                let waitTime = retryAfter ?? calculateRateLimitResetTime()
                progress.setRateLimited(resetIn: max(waitTime, 60)) // Mínimo 1 minuto
                startRateLimitTimer()
                // Guardar estado para reanudar
                try? context.save()
            case .unauthorized:
                progress.phase = .error
            default:
                progress.phase = .error
            }
        } else {
            progress.phase = .error
        }
    }
    
    // MARK: - Rate Limit Timer
    
    private func startRateLimitTimer() {
        // Cancelar timer anterior si existe
        rateLimitTimerTask?.cancel()
        
        rateLimitTimerTask = Task {
            while !Task.isCancelled && progress.isRateLimited {
                // Esperar 1 segundo
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Incrementar tick para forzar actualización de UI
                progress.timerTick += 1
                
                // Verificar si terminó el tiempo
                if progress.rateLimitRemainingSeconds <= 0 {
                    progress.clearRateLimit()
                    
                    // Auto-reanudar si no fue cancelado
                    if !isCancelled {
                        resumeSync()
                    }
                    break
                }
            }
        }
    }
    
    private func updateRateLimitInfo() async {
        // Solo trackear el inicio del período para calcular tiempo restante
        if let rateLimitInfo = await api.getRateLimitInfo() {
            if periodStartTime == nil && rateLimitInfo.usageFifteenMinutes > 0 {
                periodStartTime = Date()
            }
        }
    }
    
    /// Calcula el tiempo restante basado en cuándo empezó el período de 15 minutos
    private func calculateRateLimitResetTime() -> Int {
        guard let startTime = periodStartTime else {
            return 900 // 15 minutos por defecto
        }
        
        let elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        let totalPeriod = 900 // 15 minutos
        let remaining = max(0, totalPeriod - elapsedSeconds)
        
        return remaining
    }
    
    // MARK: - Debug & Force Resync
    
    /// Fuerza la resincronización de una actividad específica
    /// Borra laps/splits existentes y vuelve a cargar desde Strava
    func forceResyncActivity(activity: Activity, context: ModelContext) async throws {
        print("\n========== FORCE RESYNC ACTIVITY ==========")
        print("Activity ID: \(activity.id)")
        print("Activity Name: \(activity.name)")
        
        // Borrar laps existentes
        if let laps = activity.laps {
            for lap in laps {
                context.delete(lap)
            }
        }
        activity.laps = nil
        activity.hasLaps = false
        
        // Borrar splits existentes
        if let splits = activity.splitsMetric {
            for split in splits {
                context.delete(split)
            }
        }
        activity.splitsMetric = nil
        activity.hasSplitsMetric = false

        if let zones = activity.zones {
            for zone in zones {
                context.delete(zone)
            }
        }
        activity.zones = nil
        activity.zonesFetched = false

        if let streamSummary = activity.streamSummary {
            context.delete(streamSummary)
        }
        activity.streamSummary = nil
        activity.streamsSummaryFetched = false

        if let efforts = activity.segmentEfforts {
            for effort in efforts {
                context.delete(effort)
            }
        }
        activity.segmentEfforts = nil
        activity.segmentEffortsFetched = false

        if let tempoSplits = activity.tempoBlockSplits {
            for split in tempoSplits {
                context.delete(split)
            }
        }
        activity.tempoBlockSplits = nil
        activity.gearFetched = false
        
        // Marcar como no fetcheado
        activity.detailsFetched = false
        
        try context.save()
        
        // Volver a cargar desde Strava
        let detail = try await api.getActivityDetail(id: activity.id, includeAllEfforts: true)
        
        // Debug: mostrar datos raw de Strava
        printStravaDebug(detail: detail, activityName: activity.name)
        
        // Actualizar fecha local si viene
        if let localDateStr = detail.startDateLocal as String?,
           let localDate = parseStravaDateLocal(localDateStr) {
            activity.startDateLocal = localDate
            print("Updated startDateLocal: \(localDateStr)")
        }
        
        applyActivityMetadata(detail, to: activity)
        activity.detailsFetched = true
        await applyActivityDetail(detail, to: activity, context: context)
        await fetchActivityEnrichment(activity: activity, detail: detail, context: context)
        
        try context.save()
        
        // Debug: mostrar datos guardados
        printStoredActivityDebug(activity: activity)
        
        print("========== RESYNC COMPLETE ==========\n")
    }
    
    /// Imprime los datos raw que devuelve Strava
    private func printStravaDebug(detail: StravaActivityDetail, activityName: String) {
        print("\n---------- STRAVA RAW DATA ----------")
        print("Activity: \(activityName)")
        print("start_date: \(detail.startDate)")
        print("start_date_local: \(detail.startDateLocal)")
        print("total_elevation_gain: \(detail.totalElevationGain)")
        
        if let laps = detail.laps {
            print("\nLAPS (\(laps.count) total):")
            for (i, lap) in laps.enumerated() {
                print("  Lap \(i+1): distance=\(lap.distance)m, time=\(lap.movingTime)s, total_elevation_gain=\(lap.totalElevationGain ?? -1)")
                print("    fc_media=\(lap.averageHeartrate ?? -1), fc_max=\(lap.maxHeartrate ?? -1)")
                print("    potencia_media=\(lap.averageWatts ?? -1)")
            }
        } else {
            print("\nLAPS: none")
        }
        
        if let splits = detail.splitsMetric {
            print("\nSPLITS_METRIC (\(splits.count) total):")
            for (i, split) in splits.enumerated() {
                print("  Km \(i+1): distance=\(split.distance)m, time=\(split.movingTime)s, elevation_difference=\(split.elevationDifference)")
                print("    fc_media=\(split.averageHeartrate ?? -1), fc_max=\(split.maxHeartrate ?? -1)")
                print("    potencia_media=\(split.averageWatts ?? -1)")
            }
        } else {
            print("\nSPLITS_METRIC: none")
        }
        
        print("---------- END STRAVA RAW ----------\n")
    }

    private func applyActivityDetail(_ detail: StravaActivityDetail, to activity: Activity, context: ModelContext) async {
        let lapPayloads = (detail.laps?.count ?? 0) > 1 ? (detail.laps ?? []) : []
        let splitPayloads = detail.splitsMetric ?? []
        let metricBreakdowns = await fetchMetricBreakdowns(
            activity: activity,
            activityId: activity.id,
            lapSegments: lapPayloads.map {
                LapElevationSegment(
                    lapIndex: $0.lapIndex,
                    name: $0.name,
                    distance: $0.distance,
                    movingTime: $0.movingTime,
                    elapsedTime: $0.elapsedTime,
                    startIndex: $0.startIndex,
                    endIndex: $0.endIndex,
                    positiveElevationGain: $0.totalElevationGain ?? 0,
                    averageSpeed: $0.averageSpeed
                )
            },
            splitDistances: splitPayloads.map(\.distance),
            context: context
        )

        activity.hasLaps = !lapPayloads.isEmpty
        activity.hasSplitsMetric = !splitPayloads.isEmpty

        for (index, lap) in lapPayloads.enumerated() {
            let breakdown = metricBreakdowns?.laps.indices.contains(index) == true ? metricBreakdowns?.laps[index] : nil
            let activityLap = ActivityLap(
                lapIndex: lap.lapIndex,
                name: lap.name,
                distance: lap.distance,
                movingTime: lap.movingTime,
                elapsedTime: lap.elapsedTime,
                startIndex: lap.startIndex,
                endIndex: lap.endIndex,
                averageSpeed: lap.averageSpeed,
                maxSpeed: lap.maxSpeed,
                averageHeartrate: lap.averageHeartrate,
                totalElevationGain: lap.totalElevationGain ?? 0,
                positiveElevationGain: breakdown?.elevation.positive,
                negativeElevationLoss: breakdown?.elevation.negative,
                averageWatts: lap.averageWatts ?? breakdown?.power?.average,
                maxWatts: breakdown?.power?.max,
                maxHeartrate: lap.maxHeartrate,
                averageCadence: lap.averageCadence,
                averageGrade: breakdown?.averageGrade,
                movingTimeFromStream: breakdown?.movingTimeSeconds,
                activity: activity
            )
            context.insert(activityLap)
        }

        for (index, split) in splitPayloads.enumerated() {
            let breakdown = metricBreakdowns?.splits.indices.contains(index) == true ? metricBreakdowns?.splits[index] : nil
            let activitySplit = ActivitySplit(
                splitIndex: split.split - 1,
                distance: split.distance,
                movingTime: split.movingTime,
                elapsedTime: split.elapsedTime,
                averageSpeed: split.averageSpeed,
                averageHeartrate: split.averageHeartrate,
                elevationDifference: split.elevationDifference,
                positiveElevationGain: breakdown?.elevation.positive,
                negativeElevationLoss: breakdown?.elevation.negative,
                averageWatts: split.averageWatts ?? breakdown?.power?.average,
                maxWatts: breakdown?.power?.max,
                maxHeartrate: split.maxHeartrate,
                averageCadence: breakdown?.averageCadence,
                averageGrade: breakdown?.averageGrade,
                movingTimeFromStream: breakdown?.movingTimeSeconds,
                paceZone: split.paceZone,
                activity: activity
            )
            context.insert(activitySplit)
        }

        if let efforts = detail.segmentEfforts {
            for effort in efforts {
                let model = ActivitySegmentEffort(
                    id: effort.id,
                    name: effort.name,
                    segmentId: effort.segment?.id,
                    distance: effort.distance,
                    elapsedTime: effort.elapsedTime,
                    movingTime: effort.movingTime,
                    startIndex: effort.startIndex,
                    endIndex: effort.endIndex,
                    averageHeartrate: effort.averageHeartrate,
                    maxHeartrate: effort.maxHeartrate,
                    averageWatts: effort.averageWatts,
                    prRank: effort.prRank,
                    komRank: effort.komRank,
                    isKom: effort.isKom ?? false,
                    hidden: effort.hidden ?? false,
                    activity: activity
                )
                context.insert(model)
            }
            activity.segmentEffortsFetched = true
        }
    }

    private func applyActivityMetadata(_ detail: StravaActivityDetail, to activity: Activity) {
        activity.name = detail.name
        activity.sportType = detail.sportType
        activity.distance = detail.distance
        activity.movingTime = detail.movingTime
        activity.elapsedTime = detail.elapsedTime
        activity.totalElevationGain = detail.totalElevationGain
        activity.averageSpeed = detail.averageSpeed
        activity.maxSpeed = detail.maxSpeed
        activity.averageHeartrate = detail.averageHeartrate
        activity.maxHeartrate = detail.maxHeartrate
        activity.averageWatts = detail.averageWatts
        activity.maxWatts = detail.maxWatts
        activity.kilojoules = detail.kilojoules
        activity.hasHeartrate = detail.hasHeartrate ?? activity.hasHeartrate
        activity.hasPowerMeter = detail.deviceWatts ?? activity.hasPowerMeter
        activity.activityDescription = detail.description
        activity.deviceName = detail.deviceName
        activity.workoutType = detail.workoutType
        activity.calories = detail.calories
        activity.gearId = detail.gearId
        activity.trainer = detail.trainer ?? false
        activity.manual = detail.manual ?? false
        activity.isPrivate = detail.isPrivate ?? false
        activity.flagged = detail.flagged ?? false
        activity.elevHigh = detail.elevHigh
        activity.elevLow = detail.elevLow
        activity.startLatitude = detail.startLatlng?.first
        activity.startLongitude = detail.startLatlng?.dropFirst().first
        activity.endLatitude = detail.endLatlng?.first
        activity.endLongitude = detail.endLatlng?.dropFirst().first
        activity.summaryPolyline = detail.map?.summaryPolyline ?? detail.map?.polyline
        activity.achievementCount = detail.achievementCount
        activity.kudosCount = detail.kudosCount
        activity.commentCount = detail.commentCount
        activity.athleteCount = detail.athleteCount
        activity.photoCount = detail.photoCount
        activity.weightedAverageWatts = detail.weightedAverageWatts
        if let localDate = parseStravaDateLocal(detail.startDateLocal) {
            activity.startDateLocal = localDate
        }
    }

    private func fetchActivityEnrichment(activity: Activity, detail: StravaActivityDetail, context: ModelContext) async {
        await fetchActivityZonesIfNeeded(activity: activity, context: context)
        await fetchGearIfNeeded(activity: activity, detail: detail, context: context)
    }

    private func fetchActivityZonesIfNeeded(activity: Activity, context: ModelContext) async {
        guard !activity.zonesFetched else { return }
        do {
            let zones = try await api.getActivityZones(id: activity.id)
            if let oldZones = activity.zones {
                for zone in oldZones {
                    context.delete(zone)
                }
            }
            activity.zones = []
            for zone in zones {
                let distributionJSON = zoneDistributionJSON(zone.distributionBuckets)
                let model = ActivityZoneDistribution(
                    zoneType: zone.type,
                    sensorBased: zone.sensorBased,
                    score: zone.score,
                    distributionJSON: distributionJSON,
                    activity: activity
                )
                context.insert(model)
            }
            activity.zonesFetched = true
        } catch {
            print("No se pudieron cargar zonas para actividad \(activity.id): \(error)")
        }
    }

    private func fetchGearIfNeeded(activity: Activity, detail: StravaActivityDetail, context: ModelContext) async {
        guard let gearId = detail.gearId ?? activity.gearId, !gearId.isEmpty else { return }
        activity.gearId = gearId
        do {
            let descriptor = FetchDescriptor<StravaGear>(predicate: #Predicate { $0.id == gearId })
            if let existing = try? context.fetch(descriptor).first {
                activity.gear = existing
                activity.gearFetched = true
                return
            }

            let gear = try await api.getGear(id: gearId)
            let model = StravaGear(
                id: gear.id,
                name: gear.name,
                brandName: gear.brandName,
                modelName: gear.modelName,
                distanceMeters: gear.distance,
                retired: gear.retired ?? false
            )
            context.insert(model)
            activity.gear = model
            activity.gearFetched = true
        } catch {
            print("No se pudo cargar gear \(gearId): \(error)")
        }
    }

    private func fetchMetricBreakdowns(
        activity: Activity,
        activityId: Int64,
        lapSegments: [LapElevationSegment],
        splitDistances: [Double],
        context: ModelContext
    ) async -> (laps: [MetricBreakdown], splits: [MetricBreakdown])? {
        guard !lapSegments.isEmpty || !splitDistances.isEmpty else { return nil }

        do {
            let shouldFetchPower = isRunSportType(activity.sportType)
            let streams = try await api.getActivityMetricStreams(id: activityId, includeWatts: shouldFetchPower)
            guard
                let distanceStream = streams.distance?.data,
                let altitudeStream = streams.altitude?.data
            else {
                print("\n---------- STRAVA STREAMS SUMMARY ----------")
                print("Activity ID: \(activityId)")
                print("distance stream: \(streams.distance?.data.count ?? 0) puntos")
                print("altitude stream: \(streams.altitude?.data.count ?? 0) puntos")
                print("Streams incompletos, no se puede calcular desnivel +/- ni potencia por parcial")
                print("---------- END STRAVA STREAMS SUMMARY ----------\n")
                return nil
            }

            let timeStream = streams.time?.data
            let wattsStream = shouldFetchPower ? streams.watts?.data : nil
            let heartRateStream = streams.heartrate?.data
            let cadenceStream = streams.cadence?.data
            let gradeStream = streams.gradeSmooth?.data
            let movingStream = streams.moving?.data
            let velocityStream = streams.velocitySmooth?.data
            let temperatureStream = streams.temp?.data

            print("\n---------- STRAVA STREAMS SUMMARY ----------")
            print("Activity ID: \(activityId)")
            print("distance stream: \(distanceStream.count) puntos")
            print("altitude stream: \(altitudeStream.count) puntos")
            print("time stream: \(timeStream?.count ?? 0) puntos")
            print("watts stream: \(wattsStream?.count ?? 0) puntos")
            print("heartrate stream: \(heartRateStream?.count ?? 0) puntos")
            print("cadence stream: \(cadenceStream?.count ?? 0) puntos")
            if let firstDistance = distanceStream.first, let lastDistance = distanceStream.last {
                print("distance first/last: \(firstDistance)m -> \(lastDistance)m")
            }
            if let firstAltitude = altitudeStream.first, let lastAltitude = altitudeStream.last {
                print("altitude first/last: \(firstAltitude)m -> \(lastAltitude)m")
            }

            let calculatedLapBreakdowns = ElevationBreakdownCalculator.calculateIndexBreakdowns(
                indexRanges: lapSegments.map { ($0.startIndex, $0.endIndex) },
                altitudeStream: altitudeStream
            ) ?? []
            let lapBreakdowns = zip(lapSegments, calculatedLapBreakdowns).map { segment, breakdown in
                ElevationBreakdown(
                    positive: segment.positiveElevationGain,
                    negative: breakdown.negative
                )
            }
            let lapPowerBreakdowns = wattsStream.flatMap {
                PowerBreakdownCalculator.calculateIndexBreakdowns(
                    indexRanges: lapSegments.map { ($0.startIndex, $0.endIndex) },
                    timeStream: timeStream,
                    wattsStream: $0
                )
            } ?? []
            let lapStreamBreakdowns = calculateIndexStreamBreakdowns(
                indexRanges: lapSegments.map { ($0.startIndex, $0.endIndex) },
                heartRateStream: heartRateStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream
            )
            let lapBreakdownsWithPower = lapBreakdowns.enumerated().map { index, elevation in
                MetricBreakdown(
                    elevation: elevation,
                    power: lapPowerBreakdowns.indices.contains(index) ? lapPowerBreakdowns[index] : nil,
                    maxHeartRate: lapStreamBreakdowns.indices.contains(index) ? lapStreamBreakdowns[index].maxHeartRate : nil,
                    averageCadence: lapStreamBreakdowns.indices.contains(index) ? lapStreamBreakdowns[index].averageCadence : nil,
                    averageGrade: lapStreamBreakdowns.indices.contains(index) ? lapStreamBreakdowns[index].averageGrade : nil,
                    movingTimeSeconds: lapStreamBreakdowns.indices.contains(index) ? lapStreamBreakdowns[index].movingTimeSeconds : nil
                )
            }

            if !lapSegments.isEmpty {
                print("LAP BREAKDOWNS:")
                for (index, segment) in lapSegments.enumerated() {
                    let breakdown = lapBreakdownsWithPower.indices.contains(index) ? lapBreakdownsWithPower[index] : MetricBreakdown(elevation: ElevationBreakdown(positive: 0, negative: 0), power: nil)
                    let powerSummary = breakdown.power.map { ", \(Int($0.average.rounded()))W avg, \(Int($0.max.rounded()))W max" } ?? ""
                    print("  Lap \(index + 1): distance=\(segment.distance)m, idx=\(segment.startIndex)->\(segment.endIndex), +\(Int(breakdown.elevation.positive.rounded()))m, -\(Int(breakdown.elevation.negative.rounded()))m\(powerSummary)")
                }
            }

            let splitBreakdowns = ElevationBreakdownCalculator.calculateSequentialBreakdowns(
                segmentDistances: splitDistances,
                distanceStream: distanceStream,
                altitudeStream: altitudeStream
            ) ?? []
            let splitPowerBreakdowns = wattsStream.flatMap {
                PowerBreakdownCalculator.calculateSequentialBreakdowns(
                    segmentDistances: splitDistances,
                    distanceStream: distanceStream,
                    timeStream: timeStream,
                    wattsStream: $0
                )
            } ?? []
            let splitStreamBreakdowns = calculateSequentialStreamBreakdowns(
                segmentDistances: splitDistances,
                distanceStream: distanceStream,
                heartRateStream: heartRateStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream
            )
            let splitBreakdownsWithPower = splitBreakdowns.enumerated().map { index, elevation in
                MetricBreakdown(
                    elevation: elevation,
                    power: splitPowerBreakdowns.indices.contains(index) ? splitPowerBreakdowns[index] : nil,
                    maxHeartRate: splitStreamBreakdowns.indices.contains(index) ? splitStreamBreakdowns[index].maxHeartRate : nil,
                    averageCadence: splitStreamBreakdowns.indices.contains(index) ? splitStreamBreakdowns[index].averageCadence : nil,
                    averageGrade: splitStreamBreakdowns.indices.contains(index) ? splitStreamBreakdowns[index].averageGrade : nil,
                    movingTimeSeconds: splitStreamBreakdowns.indices.contains(index) ? splitStreamBreakdowns[index].movingTimeSeconds : nil
                )
            }

            if let summary = buildStreamSummary(
                timeStream: timeStream,
                distanceStream: distanceStream,
                heartRateStream: heartRateStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream,
                velocityStream: velocityStream,
                temperatureStream: temperatureStream
            ) {
                if let oldSummary = activity.streamSummary {
                    activity.streamSummary = nil
                    context.delete(oldSummary)
                }
                summary.activity = activity
                context.insert(summary)
                activity.streamSummary = summary
                activity.streamsSummaryFetched = true
            }

            rebuildTempoBlockSplits(
                activity: activity,
                lapSegments: lapSegments,
                distanceStream: distanceStream,
                timeStream: timeStream,
                altitudeStream: altitudeStream,
                heartRateStream: heartRateStream,
                wattsStream: wattsStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream,
                context: context
            )

            if !splitDistances.isEmpty {
                print("SPLIT BREAKDOWNS:")
                for (index, distance) in splitDistances.enumerated() {
                    let breakdown = splitBreakdownsWithPower.indices.contains(index) ? splitBreakdownsWithPower[index] : MetricBreakdown(elevation: ElevationBreakdown(positive: 0, negative: 0), power: nil)
                    let powerSummary = breakdown.power.map { ", \(Int($0.average.rounded()))W avg, \(Int($0.max.rounded()))W max" } ?? ""
                    print("  Split \(index + 1): distance=\(distance)m, +\(Int(breakdown.elevation.positive.rounded()))m, -\(Int(breakdown.elevation.negative.rounded()))m\(powerSummary)")
                }
            }

            print("---------- END STRAVA STREAMS SUMMARY ----------\n")

            return (lapBreakdownsWithPower, splitBreakdownsWithPower)
        } catch {
            print("No se pudieron calcular métricas por parcial para actividad \(activityId): \(error)")
            return nil
        }
    }

    private func isRunSportType(_ sportType: String) -> Bool {
        ["run", "trailrun", "virtualrun"].contains(sportType.lowercased())
    }

    private func rebuildTempoBlockSplits(
        activity: Activity,
        lapSegments: [LapElevationSegment],
        distanceStream: [Double],
        timeStream: [Int]?,
        altitudeStream: [Double],
        heartRateStream: [Int]?,
        wattsStream: [Int]?,
        cadenceStream: [Int]?,
        gradeStream: [Double]?,
        movingStream: [Bool]?,
        context: ModelContext
    ) {
        if let oldSplits = activity.tempoBlockSplits {
            for split in oldSplits {
                context.delete(split)
            }
        }
        activity.tempoBlockSplits = []

        guard
            isRunSportType(activity.sportType),
            let tempoLap = tempoCandidate(from: lapSegments),
            let generated = tempoBlockSplits(
                activity: activity,
                lap: tempoLap,
                distanceStream: distanceStream,
                timeStream: timeStream,
                altitudeStream: altitudeStream,
                heartRateStream: heartRateStream,
                wattsStream: wattsStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream
            ),
            !generated.isEmpty
        else {
            return
        }

        for split in generated {
            context.insert(split)
        }
        activity.tempoBlockSplits = generated
    }

    private func tempoCandidate(from laps: [LapElevationSegment]) -> LapElevationSegment? {
        guard laps.count >= 3 else { return nil }

        let namedTempo = laps.first { lap in
            let normalizedName = (lap.name ?? "").lowercased()
            return lap.distance >= 2_000 &&
                lap.movingTime >= 600 &&
                (normalizedName.contains("tempo") ||
                 normalizedName.contains("ritmo") ||
                 normalizedName.contains("threshold") ||
                 normalizedName.contains("umbral"))
        }
        if let namedTempo {
            return namedTempo
        }

        if laps.count == 3 {
            let warmup = laps[0]
            let tempo = laps[1]
            let cooldown = laps[2]
            let tempoIsSustained = tempo.distance >= 2_000 && tempo.movingTime >= 600
            let tempoIsFaster = tempo.averageSpeed > warmup.averageSpeed * 1.08 &&
                tempo.averageSpeed > cooldown.averageSpeed * 1.08
            if tempoIsSustained && tempoIsFaster {
                return tempo
            }
        }

        return laps.dropFirst().dropLast()
            .filter { $0.distance >= 2_000 && $0.movingTime >= 600 }
            .max { $0.averageSpeed < $1.averageSpeed }
    }

    private func tempoBlockSplits(
        activity: Activity,
        lap: LapElevationSegment,
        distanceStream: [Double],
        timeStream: [Int]?,
        altitudeStream: [Double],
        heartRateStream: [Int]?,
        wattsStream: [Int]?,
        cadenceStream: [Int]?,
        gradeStream: [Double]?,
        movingStream: [Bool]?
    ) -> [ActivityTempoBlockSplit]? {
        let startIndex = min(max(lap.startIndex, 0), max(distanceStream.count - 1, 0))
        let endIndex = min(max(lap.endIndex, startIndex), distanceStream.count - 1)
        guard startIndex < endIndex else { return nil }

        let lapStartDistance = distanceStream[startIndex]
        let lapEndDistance = lapStartDistance + lap.distance
        guard lap.distance >= 1_500 else { return nil }

        let fullLapIndexes = Array(startIndex...endIndex)
        let fullLapElevation = elevationBreakdown(altitudes: values(from: altitudeStream, indexes: fullLapIndexes))
        let targetPositiveElevation = lap.positiveElevationGain
        let targetNegativeElevation = fullLapElevation.negative
        let fullLapMovingValues = values(from: movingStream, indexes: fullLapIndexes)
        let targetMovingTime = fullLapMovingValues.isEmpty ? lap.movingTime : fullLapMovingValues.filter { $0 }.count

        var splits: [ActivityTempoBlockSplit] = []
        var chunkStart = lapStartDistance
        var splitIndex = 1

        while chunkStart < lapEndDistance {
            let chunkEnd = min(chunkStart + 1_000, lapEndDistance)
            let chunkDistance = chunkEnd - chunkStart
            guard chunkDistance >= 250 else { break }

            let indexes = (startIndex...endIndex).filter {
                distanceStream[$0] >= chunkStart && distanceStream[$0] <= chunkEnd
            }
            if let model = tempoBlockSplit(
                activity: activity,
                lap: lap,
                splitIndex: splitIndex,
                distance: chunkDistance,
                startDistance: chunkStart - lapStartDistance,
                endDistance: chunkEnd - lapStartDistance,
                indexes: indexes,
                timeStream: timeStream,
                altitudeStream: altitudeStream,
                heartRateStream: heartRateStream,
                wattsStream: wattsStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream
            ) {
                splits.append(model)
                splitIndex += 1
            }

            chunkStart = chunkEnd
        }

        normalizeTempoSplits(
            &splits,
            targetDistance: lap.distance,
            targetMovingTime: targetMovingTime,
            targetPositiveElevation: targetPositiveElevation,
            targetNegativeElevation: targetNegativeElevation
        )

        return splits.count >= 2 ? splits : nil
    }

    private func normalizeTempoSplits(
        _ splits: inout [ActivityTempoBlockSplit],
        targetDistance: Double,
        targetMovingTime: Int,
        targetPositiveElevation: Double,
        targetNegativeElevation: Double
    ) {
        guard !splits.isEmpty, let last = splits.last else { return }

        let previousDistance = splits.dropLast().reduce(0.0) { $0 + $1.distance }
        let previousMovingTime = splits.dropLast().reduce(0) { $0 + $1.movingTime }

        last.distance = max(targetDistance - previousDistance, 0)
        last.endDistance = targetDistance
        last.movingTime = max(targetMovingTime - previousMovingTime, 0)
        last.elapsedTime = last.movingTime
        if last.movingTime > 0 {
            last.averageSpeed = last.distance / Double(last.movingTime)
        }

        normalizeElevation(
            splits: splits,
            targetPositiveElevation: targetPositiveElevation,
            targetNegativeElevation: targetNegativeElevation
        )
    }

    private func normalizeElevation(
        splits: [ActivityTempoBlockSplit],
        targetPositiveElevation: Double,
        targetNegativeElevation: Double
    ) {
        guard !splits.isEmpty else { return }

        let positiveTotal = splits.reduce(0.0) { $0 + $1.positiveElevationGain }
        let negativeTotal = splits.reduce(0.0) { $0 + $1.negativeElevationLoss }
        let positiveScale = positiveTotal > 0 ? targetPositiveElevation / positiveTotal : 1
        let negativeScale = negativeTotal > 0 ? targetNegativeElevation / negativeTotal : 1

        for split in splits {
            split.positiveElevationGain *= positiveScale
            split.negativeElevationLoss *= negativeScale
        }

        if let last = splits.last {
            let previousPositive = splits.dropLast().reduce(0.0) { $0 + $1.positiveElevationGain }
            let previousNegative = splits.dropLast().reduce(0.0) { $0 + $1.negativeElevationLoss }
            last.positiveElevationGain = max(targetPositiveElevation - previousPositive, 0)
            last.negativeElevationLoss = max(targetNegativeElevation - previousNegative, 0)
        }

        for split in splits {
            split.elevationDifference = split.positiveElevationGain - split.negativeElevationLoss
        }
    }

    private func tempoBlockSplit(
        activity: Activity,
        lap: LapElevationSegment,
        splitIndex: Int,
        distance: Double,
        startDistance: Double,
        endDistance: Double,
        indexes: [Int],
        timeStream: [Int]?,
        altitudeStream: [Double],
        heartRateStream: [Int]?,
        wattsStream: [Int]?,
        cadenceStream: [Int]?,
        gradeStream: [Double]?,
        movingStream: [Bool]?
    ) -> ActivityTempoBlockSplit? {
        guard indexes.count >= 2, let firstIndex = indexes.first, let lastIndex = indexes.last else {
            return nil
        }

        let elapsedTime = elapsedSeconds(timeStream: timeStream, firstIndex: firstIndex, lastIndex: lastIndex)
        guard elapsedTime > 0 else { return nil }

        let movingValues = values(from: movingStream, indexes: indexes)
        let movingTime = movingValues.isEmpty ? elapsedTime : movingValues.filter { $0 }.count
        let paceTime = max(movingTime, 1)
        let altitudes = values(from: altitudeStream, indexes: indexes)
        let elevation = elevationBreakdown(altitudes: altitudes)
        let heartRates = values(from: heartRateStream, indexes: indexes).map(Double.init)
        let watts = values(from: wattsStream, indexes: indexes).map(Double.init)
        let cadences = values(from: cadenceStream, indexes: indexes).map(Double.init)
        let grades = values(from: gradeStream, indexes: indexes)

        return ActivityTempoBlockSplit(
            blockLapIndex: lap.lapIndex,
            splitIndex: splitIndex,
            name: "Tempo \(splitIndex)",
            distance: distance,
            elapsedTime: elapsedTime,
            movingTime: movingTime,
            averageSpeed: distance / Double(paceTime),
            elevationDifference: (altitudes.last ?? 0) - (altitudes.first ?? 0),
            positiveElevationGain: elevation.positive,
            negativeElevationLoss: elevation.negative,
            averageHeartrate: average(heartRates),
            maxHeartrate: heartRates.max(),
            averageWatts: average(watts),
            maxWatts: watts.max(),
            averageCadence: average(cadences),
            averageGrade: average(grades),
            startDistance: startDistance,
            endDistance: endDistance,
            activity: activity
        )
    }

    private func elapsedSeconds(timeStream: [Int]?, firstIndex: Int, lastIndex: Int) -> Int {
        guard
            let timeStream,
            timeStream.indices.contains(firstIndex),
            timeStream.indices.contains(lastIndex)
        else {
            return max(lastIndex - firstIndex, 0)
        }
        return max(timeStream[lastIndex] - timeStream[firstIndex], 0)
    }

    private func elevationBreakdown(altitudes: [Double]) -> ElevationBreakdown {
        guard altitudes.count >= 2 else {
            return ElevationBreakdown(positive: 0, negative: 0)
        }

        var positive = 0.0
        var negative = 0.0
        for index in 1..<altitudes.count {
            let delta = altitudes[index] - altitudes[index - 1]
            if delta > 0 {
                positive += delta
            } else {
                negative += abs(delta)
            }
        }
        return ElevationBreakdown(positive: positive, negative: negative)
    }

    private func zoneDistributionJSON(_ buckets: [StravaZoneBucket]) -> String {
        let payload = buckets.map { ["min": $0.min, "max": $0.max, "time": $0.time] }
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }

    private func calculateIndexStreamBreakdowns(
        indexRanges: [(Int, Int)],
        heartRateStream: [Int]?,
        cadenceStream: [Int]?,
        gradeStream: [Double]?,
        movingStream: [Bool]?
    ) -> [SegmentStreamBreakdown] {
        indexRanges.map { range in
            let start = max(range.0, 0)
            let end = max(range.1, start)
            return streamBreakdown(
                indexes: Array(start...end),
                heartRateStream: heartRateStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream
            )
        }
    }

    private func calculateSequentialStreamBreakdowns(
        segmentDistances: [Double],
        distanceStream: [Double],
        heartRateStream: [Int]?,
        cadenceStream: [Int]?,
        gradeStream: [Double]?,
        movingStream: [Bool]?
    ) -> [SegmentStreamBreakdown] {
        var startDistance = 0.0
        return segmentDistances.map { segmentDistance in
            let endDistance = startDistance + max(segmentDistance, 0)
            let indexes = distanceStream.indices.filter {
                distanceStream[$0] >= startDistance && distanceStream[$0] <= endDistance
            }
            startDistance = endDistance
            return streamBreakdown(
                indexes: indexes,
                heartRateStream: heartRateStream,
                cadenceStream: cadenceStream,
                gradeStream: gradeStream,
                movingStream: movingStream
            )
        }
    }

    private func streamBreakdown(
        indexes: [Int],
        heartRateStream: [Int]?,
        cadenceStream: [Int]?,
        gradeStream: [Double]?,
        movingStream: [Bool]?
    ) -> SegmentStreamBreakdown {
        let heartRates = values(from: heartRateStream, indexes: indexes).map(Double.init)
        let cadences = values(from: cadenceStream, indexes: indexes).map(Double.init)
        let grades = values(from: gradeStream, indexes: indexes)
        let movingValues = values(from: movingStream, indexes: indexes)

        return SegmentStreamBreakdown(
            maxHeartRate: heartRates.max(),
            averageCadence: average(cadences),
            averageGrade: average(grades),
            movingTimeSeconds: movingValues.isEmpty ? nil : movingValues.filter { $0 }.count
        )
    }

    private func buildStreamSummary(
        timeStream: [Int]?,
        distanceStream: [Double],
        heartRateStream: [Int]?,
        cadenceStream: [Int]?,
        gradeStream: [Double]?,
        movingStream: [Bool]?,
        velocityStream: [Double]?,
        temperatureStream: [Int]?
    ) -> ActivityStreamSummary? {
        let cadences = cadenceStream?.map(Double.init) ?? []
        let grades = gradeStream ?? []
        let movingValues = movingStream ?? []
        let movingCount = movingValues.filter { $0 }.count
        let stoppedCount = movingValues.isEmpty ? nil : max(movingValues.count - movingCount, 0)
        let movingRatio = movingValues.isEmpty ? nil : Double(movingCount) / Double(movingValues.count)
        let movingSpeeds = zip(velocityStream ?? [], movingValues.isEmpty ? Array(repeating: true, count: velocityStream?.count ?? 0) : movingValues)
            .compactMap { speed, isMoving in isMoving && speed > 0 ? speed : nil }
        let avgMovingSpeed = average(movingSpeeds)
        let cardiacDrift = cardiacDriftPercent(heartRateStream: heartRateStream, distanceStream: distanceStream)

        guard !cadences.isEmpty || !grades.isEmpty || movingRatio != nil || avgMovingSpeed != nil || cardiacDrift != nil || temperatureStream != nil || timeStream != nil else {
            return nil
        }

        return ActivityStreamSummary(
            averageCadence: average(cadences),
            maxCadence: cadences.max(),
            averageGrade: average(grades),
            maxGrade: grades.max(),
            minGrade: grades.min(),
            movingRatio: movingRatio,
            stoppedTimeSeconds: stoppedCount,
            averageMovingPaceSecondsPerKm: avgMovingSpeed.map { Int((1000 / $0).rounded()) },
            cardiacDriftPercent: cardiacDrift,
            averageTemperature: average(temperatureStream?.map(Double.init) ?? [])
        )
    }

    private func cardiacDriftPercent(heartRateStream: [Int]?, distanceStream: [Double]) -> Double? {
        guard let heartRateStream, heartRateStream.count > 10, heartRateStream.count == distanceStream.count else {
            return nil
        }
        let midpoint = heartRateStream.count / 2
        let firstHalf = heartRateStream[..<midpoint].map(Double.init)
        let secondHalf = heartRateStream[midpoint...].map(Double.init)
        guard let firstAverage = average(Array(firstHalf)), firstAverage > 0, let secondAverage = average(Array(secondHalf)) else {
            return nil
        }
        return ((secondAverage - firstAverage) / firstAverage) * 100
    }

    private func values<T>(from source: [T]?, indexes: [Int]) -> [T] {
        guard let source else { return [] }
        return indexes.compactMap { source.indices.contains($0) ? source[$0] : nil }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private struct MetricBreakdown {
        let elevation: ElevationBreakdown
        let power: PowerBreakdown?
        let maxHeartRate: Double?
        let averageCadence: Double?
        let averageGrade: Double?
        let movingTimeSeconds: Int?

        init(
            elevation: ElevationBreakdown,
            power: PowerBreakdown? = nil,
            maxHeartRate: Double? = nil,
            averageCadence: Double? = nil,
            averageGrade: Double? = nil,
            movingTimeSeconds: Int? = nil
        ) {
            self.elevation = elevation
            self.power = power
            self.maxHeartRate = maxHeartRate
            self.averageCadence = averageCadence
            self.averageGrade = averageGrade
            self.movingTimeSeconds = movingTimeSeconds
        }
    }

    private struct SegmentStreamBreakdown {
        let maxHeartRate: Double?
        let averageCadence: Double?
        let averageGrade: Double?
        let movingTimeSeconds: Int?
    }

    private struct LapElevationSegment {
        let lapIndex: Int
        let name: String?
        let distance: Double
        let movingTime: Int
        let elapsedTime: Int
        let startIndex: Int
        let endIndex: Int
        let positiveElevationGain: Double
        let averageSpeed: Double
    }

    /// Imprime los datos almacenados de una actividad
    private func printStoredActivityDebug(activity: Activity) {
        print("\n---------- STORED ACTIVITY DATA ----------")
        print("ID: \(activity.id)")
        print("Name: \(activity.name)")
        print("startDate: \(activity.startDate)")
        print("startDateLocal: \(activity.startDateLocal?.description ?? "nil")")
        print("fc_media: \(activity.averageHeartrate ?? -1)")
        print("fc_max: \(activity.maxHeartrate ?? -1)")
        print("potencia_media: \(activity.averageWatts ?? -1)")
        
        if let laps = activity.sortedLaps {
            print("\nSTORED LAPS (\(laps.count) total):")
            for (i, lap) in laps.prefix(3).enumerated() {
                print("  Lap \(i+1): \(lap.name ?? "unnamed")")
                print("    fc_media=\(lap.averageHeartrate ?? -1)")
                print("    potencia_media=\(lap.averageWatts ?? -1), potencia_max=\(lap.maxWatts ?? -1)")
            }
        }
        
        if let splits = activity.sortedSplits {
            print("\nSTORED SPLITS (\(splits.count) total):")
            for (i, split) in splits.prefix(3).enumerated() {
                print("  Km \(i+1):")
                print("    fc_media=\(split.averageHeartrate ?? -1)")
                print("    potencia_media=\(split.averageWatts ?? -1), potencia_max=\(split.maxWatts ?? -1)")
            }
        }
        
        print("---------- END STORED DATA ----------\n")
    }
}
