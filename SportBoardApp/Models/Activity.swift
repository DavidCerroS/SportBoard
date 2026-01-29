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
    var hasHeartrate: Bool
    var hasPowerMeter: Bool
    var deviceName: String?
    var activityDescription: String?
    
    // Flags para saber qué datos tiene
    var hasLaps: Bool
    var hasSplitsMetric: Bool
    
    // Relaciones
    @Relationship(deleteRule: .cascade, inverse: \ActivityLap.activity)
    var laps: [ActivityLap]?
    
    @Relationship(deleteRule: .cascade, inverse: \ActivitySplit.activity)
    var splitsMetric: [ActivitySplit]?
    
    // Metadatos de sincronización
    var syncedAt: Date
    var detailsFetched: Bool
    
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
        hasLaps: Bool = false,
        hasSplitsMetric: Bool = false,
        laps: [ActivityLap]? = nil,
        splitsMetric: [ActivitySplit]? = nil,
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
        self.hasLaps = hasLaps
        self.hasSplitsMetric = hasSplitsMetric
        self.laps = laps
        self.splitsMetric = splitsMetric
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
