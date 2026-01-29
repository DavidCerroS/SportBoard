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
        guard !activity.detailsFetched else { return }
        
        let detail = try await api.getActivityDetail(id: activity.id)
        
        // Debug: mostrar datos raw de Strava
        printStravaDebug(detail: detail, activityName: activity.name)
        
        // Actualizar campos adicionales
        activity.activityDescription = detail.description
        activity.deviceName = detail.deviceName
        activity.detailsFetched = true
        
        // Procesar laps (parciales de trabajo)
        if let laps = detail.laps, laps.count > 1 {
            activity.hasLaps = true
            
            for lap in laps {
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
                    activity: activity
                )
                context.insert(activityLap)
            }
        }
        
        // Procesar splits (por kilómetro)
        if let splits = detail.splitsMetric, !splits.isEmpty {
            activity.hasSplitsMetric = true
            
            for split in splits {
                let activitySplit = ActivitySplit(
                    splitIndex: split.split - 1,
                    distance: split.distance,
                    movingTime: split.movingTime,
                    elapsedTime: split.elapsedTime,
                    averageSpeed: split.averageSpeed,
                    averageHeartrate: split.averageHeartrate,
                    elevationDifference: split.elevationDifference,
                    paceZone: split.paceZone,
                    activity: activity
                )
                context.insert(activitySplit)
            }
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
            hasPowerMeter: summary.deviceWatts ?? false
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
                try await self.api.getActivityDetail(id: activity.id)
            }
            
            // Actualizar campos adicionales
            activity.activityDescription = detail.description
            activity.deviceName = detail.deviceName
            activity.detailsFetched = true
            
            // Procesar laps (parciales de trabajo)
            if let laps = detail.laps, laps.count > 1 {
                // Solo guardar laps si hay más de 1 (si hay 1 solo, es la actividad completa)
                activity.hasLaps = true
                
                for lap in laps {
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
                        activity: activity
                    )
                    context.insert(activityLap)
                }
            }
            
            // Procesar splits (por kilómetro)
            if let splits = detail.splitsMetric, !splits.isEmpty {
                activity.hasSplitsMetric = true
                
                for split in splits {
                    let activitySplit = ActivitySplit(
                        splitIndex: split.split - 1, // Strava usa 1-based
                        distance: split.distance,
                        movingTime: split.movingTime,
                        elapsedTime: split.elapsedTime,
                        averageSpeed: split.averageSpeed,
                        averageHeartrate: split.averageHeartrate,
                        elevationDifference: split.elevationDifference,
                        paceZone: split.paceZone,
                        activity: activity
                    )
                    context.insert(activitySplit)
                }
            }
            
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
        
        // Marcar como no fetcheado
        activity.detailsFetched = false
        
        try context.save()
        
        // Volver a cargar desde Strava
        let detail = try await api.getActivityDetail(id: activity.id)
        
        // Debug: mostrar datos raw de Strava
        printStravaDebug(detail: detail, activityName: activity.name)
        
        // Actualizar fecha local si viene
        if let localDateStr = detail.startDateLocal as String?,
           let localDate = parseStravaDateLocal(localDateStr) {
            activity.startDateLocal = localDate
            print("Updated startDateLocal: \(localDateStr)")
        }
        
        // Actualizar campos adicionales
        activity.activityDescription = detail.description
        activity.deviceName = detail.deviceName
        activity.detailsFetched = true
        
        // Procesar laps
        if let laps = detail.laps, laps.count > 1 {
            activity.hasLaps = true
            
            for lap in laps {
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
                    activity: activity
                )
                context.insert(activityLap)
            }
        }
        
        // Procesar splits
        if let splits = detail.splitsMetric, !splits.isEmpty {
            activity.hasSplitsMetric = true
            
            for split in splits {
                let activitySplit = ActivitySplit(
                    splitIndex: split.split - 1,
                    distance: split.distance,
                    movingTime: split.movingTime,
                    elapsedTime: split.elapsedTime,
                    averageSpeed: split.averageSpeed,
                    averageHeartrate: split.averageHeartrate,
                    elevationDifference: split.elevationDifference,
                    paceZone: split.paceZone,
                    activity: activity
                )
                context.insert(activitySplit)
            }
        }
        
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
        
        if let laps = detail.laps {
            print("\nLAPS (\(laps.count) total):")
            for (i, lap) in laps.prefix(3).enumerated() {
                print("  Lap \(i+1): distance=\(lap.distance)m, time=\(lap.movingTime)s")
                print("    fc_media=\(lap.averageHeartrate ?? -1), fc_max=\(lap.maxHeartrate ?? -1)")
                print("    potencia_media=\(lap.averageWatts ?? -1)")
            }
            if laps.count > 3 { print("  ... and \(laps.count - 3) more") }
        } else {
            print("\nLAPS: none")
        }
        
        if let splits = detail.splitsMetric {
            print("\nSPLITS_METRIC (\(splits.count) total):")
            for (i, split) in splits.prefix(3).enumerated() {
                print("  Km \(i+1): distance=\(split.distance)m, time=\(split.movingTime)s")
                print("    fc_media=\(split.averageHeartrate ?? -1), fc_max=\(split.maxHeartrate ?? -1)")
                print("    potencia_media=\(split.averageWatts ?? -1)")
            }
            if splits.count > 3 { print("  ... and \(splits.count - 3) more") }
        } else {
            print("\nSPLITS_METRIC: none")
        }
        
        print("---------- END STRAVA RAW ----------\n")
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
                print("    (fc_max y potencia_media no disponibles - Strava no los devuelve)")
            }
        }
        
        if let splits = activity.sortedSplits {
            print("\nSTORED SPLITS (\(splits.count) total):")
            for (i, split) in splits.prefix(3).enumerated() {
                print("  Km \(i+1):")
                print("    fc_media=\(split.averageHeartrate ?? -1)")
                print("    (fc_max y potencia_media no disponibles - Strava no los devuelve)")
            }
        }
        
        print("---------- END STORED DATA ----------\n")
    }
}

