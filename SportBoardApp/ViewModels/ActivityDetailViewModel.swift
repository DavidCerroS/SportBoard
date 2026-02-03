//
//  ActivityDetailViewModel.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@MainActor
@Observable
final class ActivityDetailViewModel {
    let activity: Activity
    
    var showCopiedAlert = false
    var showExportError = false
    var errorMessage: String = ""
    var isLoadingDetails = false
    var detailsLoadError: String?
    var isResyncing = false
    var resyncSuccess = false
    
    /// Inteligencia local: clasificación y detector de rodaje mal ejecutado (solo carrera)
    var runClassification: RunClassification?
    var badRunInsight: BadRunInsight?
    
    private let syncService = SyncService.shared
    
    init(activity: Activity) {
        self.activity = activity
    }
    
    /// Carga clasificación y insight de rodaje (requiere contexto y opcionalmente detalles ya cargados).
    func loadIntelligence(context: ModelContext) {
        let runTypes = ["run", "virtualrun", "trailrun"]
        guard runTypes.contains(activity.sportType.lowercased()) else { return }
        
        let profile = try? RunnerProfileService.fetchProfile(modelContext: context)
        let easyMs = profile?.easyPaceMs
        let threshMs = profile?.thresholdPaceMs
        
        runClassification = RunClassifier.classify(
            activity: activity,
            splits: activity.sortedSplits,
            laps: activity.sortedLaps,
            easyPaceMs: easyMs,
            thresholdPaceMs: threshMs
        )
        
        var previousDay: Activity?
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: activity.startDate)
        let previousDayStart = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
        let previousDayEnd = calendar.date(byAdding: .day, value: 1, to: previousDayStart) ?? previousDayStart
        var descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        descriptor.fetchLimit = 50
        let recent = (try? context.fetch(descriptor)) ?? []
        previousDay = recent.first { act in
            act.id != activity.id && act.startDate >= previousDayStart && act.startDate < previousDayEnd
        }
        
        badRunInsight = BadRunDetector.evaluate(
            activity: activity,
            splits: activity.sortedSplits,
            profile: profile,
            previousDayActivity: previousDay
        )
    }
    
    // MARK: - Load Details On Demand
    
    func loadDetailsIfNeeded(context: ModelContext) async {
        // Si ya tiene detalles, no hacer nada
        guard !activity.detailsFetched else { return }
        
        isLoadingDetails = true
        detailsLoadError = nil
        
        do {
            try await syncService.fetchActivityDetailsOnDemand(activity: activity, context: context)
        } catch {
            detailsLoadError = "Error al cargar detalles: \(error.localizedDescription)"
        }
        
        isLoadingDetails = false
    }
    
    // MARK: - Force Resync
    
    /// Fuerza la resincronización de esta actividad con Strava
    /// Los datos raw se imprimen en consola para debug
    func forceResync(context: ModelContext) async {
        isResyncing = true
        resyncSuccess = false
        detailsLoadError = nil
        
        do {
            try await syncService.forceResyncActivity(activity: activity, context: context)
            resyncSuccess = true
            
            // Ocultar el mensaje de éxito después de 3 segundos
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                resyncSuccess = false
            }
        } catch {
            detailsLoadError = "Error resync: \(error.localizedDescription)"
        }
        
        isResyncing = false
    }
    
    /// Imprime los datos actuales de la actividad en consola (debug)
    func printDebugData() {
        print("\n========== DEBUG: ACTIVITY DATA ==========")
        print("ID: \(activity.id)")
        print("Name: \(activity.name)")
        print("Sport: \(activity.sportType)")
        print("startDate: \(activity.startDate)")
        print("startDateLocal: \(activity.startDateLocal?.description ?? "nil")")
        print("Distance: \(activity.distance)m")
        print("Moving Time: \(activity.movingTime)s")
        print("fc_media: \(activity.averageHeartrate ?? -1)")
        print("fc_max: \(activity.maxHeartrate ?? -1)")
        print("potencia_media: \(activity.averageWatts ?? -1)")
        print("detailsFetched: \(activity.detailsFetched)")
        
        if let laps = activity.sortedLaps {
            print("\nLAPS (\(laps.count) total):")
            for lap in laps {
                print("  [\(lap.lapIndex)] \(lap.name ?? "unnamed"): dist=\(lap.distance)m, time=\(lap.movingTime)s")
                print("       fc_media=\(lap.averageHeartrate ?? -1) (fc_max y potencia no disponibles)")
            }
        } else {
            print("\nLAPS: none")
        }
        
        if let splits = activity.sortedSplits {
            print("\nSPLITS (\(splits.count) total):")
            for split in splits {
                print("  Km \(split.splitIndex + 1): dist=\(split.distance)m, time=\(split.movingTime)s")
                print("       fc_media=\(split.averageHeartrate ?? -1) (fc_max y potencia no disponibles)")
            }
        } else {
            print("\nSPLITS: none")
        }
        
        print("\n--- EXPORT JSON PREVIEW ---")
        let json = WebJSONExporter.exportActivityAsWebJSON(activity)
        print(json)
        print("========== END DEBUG ==========\n")
    }
    
    // MARK: - Export Functions (Formato idéntico a la web)
    
    func copyJSONToClipboard() {
        let jsonString = WebJSONExporter.exportActivityAsWebJSON(activity)
        UIPasteboard.general.string = jsonString
        showCopiedAlert = true
    }
    
    func exportJSONToFile() -> URL? {
        let jsonString = WebJSONExporter.exportActivityAsWebJSON(activity)
        guard let data = jsonString.data(using: .utf8) else {
            errorMessage = "Error al generar JSON"
            showExportError = true
            return nil
        }
        
        let fileName = sanitizeFileName(activity.name) + "_\(activity.id).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            errorMessage = "Error al guardar archivo: \(error.localizedDescription)"
            showExportError = true
            return nil
        }
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
            .prefix(50)
            .description
    }
    
    // MARK: - Computed Properties
    
    var hasLaps: Bool {
        activity.sortedLaps != nil
    }
    
    var hasSplits: Bool {
        activity.sortedSplits != nil
    }
    
    var showLapsSection: Bool {
        // Mostrar laps si hay laps reales (más de 1)
        hasLaps
    }
    
    var showSplitsSection: Bool {
        // Mostrar splits solo si no hay laps O si los splits existen
        hasSplits && !hasLaps
    }
    
    var laps: [ActivityLap] {
        activity.sortedLaps ?? []
    }
    
    var splits: [ActivitySplit] {
        activity.sortedSplits ?? []
    }
}
