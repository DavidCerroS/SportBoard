//
//  Activity.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: Int64
    var name: String
    var sportType: String
    var startDate: Date // Fecha UTC
    var startDateLocal: Date? // Fecha local del usuario (para export JSON) - opcional para migración
    var distance: Double // metros
    var movingTime: Int // segundos
    var elapsedTime: Int // segundos
    var totalElevationGain: Double // metros
    var averageSpeed: Double // m/s
    var maxSpeed: Double // m/s
    var averageHeartrate: Double?
    var maxHeartrate: Double?
    var averageWatts: Double?
    var maxWatts: Double?
    var kilojoules: Double?
    var hasHeartrate: Bool = false
    var hasPowerMeter: Bool = false
    var deviceName: String?
    var activityDescription: String?
    var workoutType: Int?
    var calories: Double?
    var gearId: String?
    var trainer: Bool = false
    var manual: Bool = false
    var isPrivate: Bool = false
    var flagged: Bool = false
    var elevHigh: Double?
    var elevLow: Double?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var summaryPolyline: String?
    var achievementCount: Int?
    var kudosCount: Int?
    var commentCount: Int?
    var athleteCount: Int?
    var photoCount: Int?
    var weightedAverageWatts: Double?
    
    // Flags para saber qué datos tiene
    var hasLaps: Bool = false
    var hasSplitsMetric: Bool = false
    var zonesFetched: Bool = false
    var streamsSummaryFetched: Bool = false
    var gearFetched: Bool = false
    var segmentEffortsFetched: Bool = false
    
    // Relaciones
    @Relationship(deleteRule: .cascade, inverse: \ActivityLap.activity)
    var laps: [ActivityLap]?
    
    @Relationship(deleteRule: .cascade, inverse: \ActivitySplit.activity)
    var splitsMetric: [ActivitySplit]?

    @Relationship(deleteRule: .cascade, inverse: \ActivityZoneDistribution.activity)
    var zones: [ActivityZoneDistribution]?

    @Relationship(deleteRule: .cascade, inverse: \ActivityStreamSummary.activity)
    var streamSummary: ActivityStreamSummary?

    var gear: StravaGear?

    @Relationship(deleteRule: .cascade, inverse: \ActivitySegmentEffort.activity)
    var segmentEfforts: [ActivitySegmentEffort]?

    @Relationship(deleteRule: .cascade, inverse: \ActivityTempoBlockSplit.activity)
    var tempoBlockSplits: [ActivityTempoBlockSplit]?
    
    // Metadatos de sincronización
    var syncedAt: Date
    var detailsFetched: Bool = false
    
    init(
        id: Int64,
        name: String,
        sportType: String,
        startDate: Date,
        startDateLocal: Date? = nil, // Si no se proporciona, usa startDate
        distance: Double = 0,
        movingTime: Int = 0,
        elapsedTime: Int = 0,
        totalElevationGain: Double = 0,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        averageHeartrate: Double? = nil,
        maxHeartrate: Double? = nil,
        averageWatts: Double? = nil,
        maxWatts: Double? = nil,
        kilojoules: Double? = nil,
        hasHeartrate: Bool = false,
        hasPowerMeter: Bool = false,
        deviceName: String? = nil,
        activityDescription: String? = nil,
        workoutType: Int? = nil,
        calories: Double? = nil,
        gearId: String? = nil,
        trainer: Bool = false,
        manual: Bool = false,
        isPrivate: Bool = false,
        flagged: Bool = false,
        elevHigh: Double? = nil,
        elevLow: Double? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        summaryPolyline: String? = nil,
        achievementCount: Int? = nil,
        kudosCount: Int? = nil,
        commentCount: Int? = nil,
        athleteCount: Int? = nil,
        photoCount: Int? = nil,
        weightedAverageWatts: Double? = nil,
        hasLaps: Bool = false,
        hasSplitsMetric: Bool = false,
        zonesFetched: Bool = false,
        streamsSummaryFetched: Bool = false,
        gearFetched: Bool = false,
        segmentEffortsFetched: Bool = false,
        laps: [ActivityLap]? = nil,
        splitsMetric: [ActivitySplit]? = nil,
        zones: [ActivityZoneDistribution]? = nil,
        streamSummary: ActivityStreamSummary? = nil,
        gear: StravaGear? = nil,
        segmentEfforts: [ActivitySegmentEffort]? = nil,
        tempoBlockSplits: [ActivityTempoBlockSplit]? = nil,
        syncedAt: Date = Date(),
        detailsFetched: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sportType = sportType
        self.startDate = startDate
        self.startDateLocal = startDateLocal
        self.distance = distance
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.totalElevationGain = totalElevationGain
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.averageHeartrate = averageHeartrate
        self.maxHeartrate = maxHeartrate
        self.averageWatts = averageWatts
        self.maxWatts = maxWatts
        self.kilojoules = kilojoules
        self.hasHeartrate = hasHeartrate
        self.hasPowerMeter = hasPowerMeter
        self.deviceName = deviceName
        self.activityDescription = activityDescription
        self.workoutType = workoutType
        self.calories = calories
        self.gearId = gearId
        self.trainer = trainer
        self.manual = manual
        self.isPrivate = isPrivate
        self.flagged = flagged
        self.elevHigh = elevHigh
        self.elevLow = elevLow
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.summaryPolyline = summaryPolyline
        self.achievementCount = achievementCount
        self.kudosCount = kudosCount
        self.commentCount = commentCount
        self.athleteCount = athleteCount
        self.photoCount = photoCount
        self.weightedAverageWatts = weightedAverageWatts
        self.hasLaps = hasLaps
        self.hasSplitsMetric = hasSplitsMetric
        self.zonesFetched = zonesFetched
        self.streamsSummaryFetched = streamsSummaryFetched
        self.gearFetched = gearFetched
        self.segmentEffortsFetched = segmentEffortsFetched
        self.laps = laps
        self.splitsMetric = splitsMetric
        self.zones = zones
        self.streamSummary = streamSummary
        self.gear = gear
        self.segmentEfforts = segmentEfforts
        self.tempoBlockSplits = tempoBlockSplits
        self.syncedAt = syncedAt
        self.detailsFetched = detailsFetched
    }
}

// MARK: - Computed Properties

extension Activity {
    var formattedDistance: String {
        distance.formattedDistanceKm
    }
    
    var formattedMovingTime: String {
        TimeInterval(movingTime).formattedDuration
    }
    
    var formattedPace: String {
        averageSpeed.paceMinPerKm
    }
    
    var formattedSpeed: String {
        averageSpeed.speedKmh
    }
    
    var formattedSpeedOrPace: String {
        sportType.usesPace ? formattedPace : formattedSpeed
    }
    
    var speedOrPaceLabel: String {
        sportType.usesPace ? "Ritmo" : "Velocidad"
    }
    
    var speedOrPaceUnit: String {
        sportType.usesPace ? "min/km" : "km/h"
    }
    
    var formattedElevation: String {
        totalElevationGain.formattedElevation
    }
    
    var formattedHeartrate: String {
        guard let hr = averageHeartrate else { return "--" }
        return hr.formattedHeartRate
    }
    
    var formattedPower: String {
        guard let watts = averageWatts else { return "--" }
        return watts.formattedPower
    }
    
    /// Devuelve los laps ordenados si existen, o nil si no hay laps reales
    var sortedLaps: [ActivityLap]? {
        guard hasLaps, let laps = laps, !laps.isEmpty else { return nil }
        return laps.sorted { $0.lapIndex < $1.lapIndex }
    }
    
    /// Devuelve los splits ordenados si existen
    var sortedSplits: [ActivitySplit]? {
        guard hasSplitsMetric, let splits = splitsMetric, !splits.isEmpty else { return nil }
        return splits.sorted { $0.splitIndex < $1.splitIndex }
    }

    var sortedVisibleSegmentEfforts: [ActivitySegmentEffort] {
        (segmentEfforts ?? [])
            .filter { !$0.hidden }
            .sorted { $0.startIndex ?? 0 < $1.startIndex ?? 0 }
    }

    var sortedTempoBlockSplits: [ActivityTempoBlockSplit] {
        (tempoBlockSplits ?? [])
            .sorted {
                if $0.blockLapIndex == $1.blockLapIndex {
                    return $0.splitIndex < $1.splitIndex
                }
                return $0.blockLapIndex < $1.blockLapIndex
            }
    }
}

// MARK: - JSON Export (Formato idéntico a la web)

extension Activity {
    
    /// Formatea duración como la web: "Xh Ym" o "Xm Ys" o "Xs"
    /// Usado para tiempo_total en el objeto principal
    private static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
    
    /// Formatea tiempo como la web: "H:MM:SS" o "M:SS"
    /// Usado para tiempo en parciales
    static func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        
        if mins >= 60 {
            let hours = mins / 60
            let remainingMins = mins % 60
            return "\(hours):\(String(format: "%02d", remainingMins)):\(String(format: "%02d", secs))"
        }
        return "\(mins):\(String(format: "%02d", secs))"
    }
    
    /// Formatea ritmo desde m/s: "M:SS" o "-"
    static func formatPaceFromSpeed(_ speedMs: Double) -> String {
        guard speedMs > 0 else { return "-" }
        let paceSeconds = 1000 / speedMs // segundos por km
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds.rounded()) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    func toExportJSON() -> [String: Any] {
        // Formato de fecha español con zona horaria Europe/Madrid
        // Igual que: new Date(activity.startDateLocal).toLocaleString("es-ES")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d/M/yyyy, H:mm:ss"
        dateFormatter.locale = Locale(identifier: "es_ES")
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        
        // Calcular ritmo medio: "M:SS /km"
        let avgPaceSeconds = averageSpeed > 0 ? 1000 / averageSpeed : 0
        let paceMin = Int(avgPaceSeconds) / 60
        let paceSec = Int(avgPaceSeconds.rounded()) % 60
        let ritmoMedio = "\(paceMin):\(String(format: "%02d", paceSec)) /km"
        
        // Tiempo total formateado: "Xh Ym" o "Xm Ys"
        let tiempoTotal = Activity.formatDuration(movingTime)
        
        // Distancia con 2 decimales: parseFloat((distance / 1000).toFixed(2))
        let distanciaKm = Double(String(format: "%.2f", distance / 1000))!
        
        // Determinar parciales (igual que la web)
        // Si hay más de 1 lap, usar laps (intervalos)
        // Si no, usar splits (kilómetros)
        let useLapsFromStrava = (sortedLaps?.count ?? 0) > 1
        
        let tipoParciales: String
        let parciales: [[String: Any]]
        
        if useLapsFromStrava, let laps = sortedLaps {
            tipoParciales = "intervalos"
            parciales = laps.enumerated().map { index, lap in
                lap.toExportJSONWeb(index: index + 1)
            }
        } else if let splits = sortedSplits, !splits.isEmpty {
            tipoParciales = "kilometros"
            parciales = splits.enumerated().map { index, split in
                split.toExportJSONWeb(index: index + 1)
            }
        } else {
            tipoParciales = "kilometros"
            parciales = []
        }
        
        // Construir JSON en el mismo orden que la web
        var json: [String: Any] = [:]
        json["nombre"] = name
        json["tipo"] = sportType
        json["fecha"] = dateFormatter.string(from: startDate)
        json["distancia_km"] = distanciaKm
        json["tiempo_total"] = tiempoTotal
        json["tiempo_total_s"] = movingTime
        json["ritmo_medio"] = ritmoMedio
        json["desnivel_positivo_m"] = Int(totalElevationGain.rounded())
        json["fc_media"] = averageHeartrate != nil ? Int(averageHeartrate!.rounded()) : NSNull()
        json["fc_max"] = maxHeartrate != nil ? Int(maxHeartrate!.rounded()) : NSNull()
        if ["run", "trailrun", "virtualrun"].contains(sportType.lowercased()) {
            json["potencia_media"] = averageWatts != nil ? Int(averageWatts!.rounded()) : NSNull()
            json["potencia_max"] = maxWatts != nil ? Int(maxWatts!.rounded()) : NSNull()
        } else {
            json["potencia_media"] = NSNull()
            json["potencia_max"] = NSNull()
        }
        json["tipo_parciales"] = tipoParciales
        json["parciales"] = parciales
        
        return json
    }
    
    func toExportJSONString(prettyPrinted: Bool = true) -> String? {
        let json = toExportJSON()
        var options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        options.insert(.withoutEscapingSlashes)
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: options) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
