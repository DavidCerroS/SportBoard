//
//  ActivityLap.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData

/// Representa un "lap" o parcial de trabajo en una actividad.
/// Estos son los intervalos marcados manualmente por el usuario durante la actividad.
@Model
final class ActivityLap {
    var lapIndex: Int
    var name: String?
    var distance: Double // metros
    var movingTime: Int // segundos
    var elapsedTime: Int // segundos
    var startIndex: Int
    var endIndex: Int
    var averageSpeed: Double // m/s
    var maxSpeed: Double // m/s
    var averageHeartrate: Double?
    var totalElevationGain: Double
    
    var activity: Activity?
    
    init(
        lapIndex: Int,
        name: String? = nil,
        distance: Double = 0,
        movingTime: Int = 0,
        elapsedTime: Int = 0,
        startIndex: Int = 0,
        endIndex: Int = 0,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        averageHeartrate: Double? = nil,
        totalElevationGain: Double = 0,
        activity: Activity? = nil
    ) {
        self.lapIndex = lapIndex
        self.name = name
        self.distance = distance
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.averageHeartrate = averageHeartrate
        self.totalElevationGain = totalElevationGain
        self.activity = activity
    }
}

// MARK: - Computed Properties

extension ActivityLap {
    var formattedDistance: String {
        distance.formattedDistance
    }
    
    var formattedTime: String {
        TimeInterval(movingTime).formattedDuration
    }
    
    var formattedPace: String {
        averageSpeed.paceMinPerKm
    }
    
    var formattedSpeed: String {
        averageSpeed.speedKmh
    }
    
    var formattedHeartrate: String {
        guard let hr = averageHeartrate else { return "--" }
        return String(format: "%.0f", hr)
    }
    
    var displayName: String {
        name ?? "Parcial \(lapIndex + 1)"
    }
}

// MARK: - JSON Export (Formato idéntico a la web)

extension ActivityLap {
    
    func toExportJSON() -> [String: Any] {
        var json: [String: Any] = [
            "index": lapIndex,
            "distance": distance,
            "moving_time": movingTime,
            "elapsed_time": elapsedTime,
            "average_speed": averageSpeed,
            "max_speed": maxSpeed,
            "elevation_gain": totalElevationGain
        ]
        
        if let name = name {
            json["name"] = name
        }
        if let hr = averageHeartrate {
            json["average_heartrate"] = hr
        }
        
        return json
    }
    
    /// Formato idéntico al de la web:
    /// {
    ///   parcial: index + 1,
    ///   nombre: lap.name,
    ///   distancia_km: parseFloat((lap.distance / 1000).toFixed(2)),
    ///   tiempo: formatTime(lap.moving_time),
    ///   tiempo_s: lap.moving_time,
    ///   ritmo: formatPaceFromSpeed(lap.average_speed),
    ///   ritmo_s_km: lap.average_speed > 0 ? Math.round(1000 / lap.average_speed) : null,
    ///   desnivel_m: Math.round(lap.total_elevation_gain),
    ///   fc_media: lap.average_heartrate ? Math.round(lap.average_heartrate) : null,
    ///   fc_max: lap.max_heartrate ? Math.round(lap.max_heartrate) : null,
    ///   potencia_media: lap.average_watts ? Math.round(lap.average_watts) : null,
    ///   cadencia_media: lap.average_cadence ? Math.round(lap.average_cadence) : null,
    /// }
    func toExportJSONWeb(index: Int) -> [String: Any] {
        // distancia_km: parseFloat((lap.distance / 1000).toFixed(2))
        let distanciaKm = Double(String(format: "%.2f", distance / 1000))!
        
        // tiempo: formatTime(lap.moving_time) → "M:SS" o "H:MM:SS"
        let tiempo = Activity.formatTime(movingTime)
        
        // ritmo: formatPaceFromSpeed(lap.average_speed)
        let ritmo = Activity.formatPaceFromSpeed(averageSpeed)
        
        // ritmo_s_km: lap.average_speed > 0 ? Math.round(1000 / lap.average_speed) : null
        let ritmoSKm: Any = averageSpeed > 0 ? Int((1000 / averageSpeed).rounded()) : NSNull()
        
        // Construir en el mismo orden que la web
        var json: [String: Any] = [:]
        json["parcial"] = index
        json["nombre"] = name ?? "Lap \(index)"
        json["distancia_km"] = distanciaKm
        json["tiempo"] = tiempo
        json["tiempo_s"] = movingTime
        json["ritmo"] = ritmo
        json["ritmo_s_km"] = ritmoSKm
        json["desnivel_m"] = Int(totalElevationGain.rounded())
        json["fc_media"] = averageHeartrate != nil ? Int(averageHeartrate!.rounded()) : NSNull()
        json["fc_max"] = NSNull() // Strava no devuelve fc_max por parcial
        json["potencia_media"] = NSNull() // Strava no devuelve potencia por parcial
        json["cadencia_media"] = NSNull() // Strava no devuelve cadencia por parcial
        
        return json
    }
}
