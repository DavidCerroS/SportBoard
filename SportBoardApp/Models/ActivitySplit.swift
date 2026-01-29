//
//  ActivitySplit.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData

/// Representa un "split" o división por kilómetro en una actividad.
/// Strava genera automáticamente splits cada kilómetro.
@Model
final class ActivitySplit {
    var splitIndex: Int
    var distance: Double // metros (normalmente ~1000)
    var movingTime: Int // segundos
    var elapsedTime: Int // segundos
    var averageSpeed: Double // m/s
    var averageHeartrate: Double?
    var elevationDifference: Double // diferencia de elevación en este split
    var paceZone: Int? // zona de ritmo (1-5)
    
    var activity: Activity?
    
    init(
        splitIndex: Int,
        distance: Double = 0,
        movingTime: Int = 0,
        elapsedTime: Int = 0,
        averageSpeed: Double = 0,
        averageHeartrate: Double? = nil,
        elevationDifference: Double = 0,
        paceZone: Int? = nil,
        activity: Activity? = nil
    ) {
        self.splitIndex = splitIndex
        self.distance = distance
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.averageSpeed = averageSpeed
        self.averageHeartrate = averageHeartrate
        self.elevationDifference = elevationDifference
        self.paceZone = paceZone
        self.activity = activity
    }
}

// MARK: - Computed Properties

extension ActivitySplit {
    var formattedKm: String {
        "Km \(splitIndex + 1)"
    }
    
    /// Tiempo del split usando elapsed_time (fuente única de verdad según Strava splits_metric)
    var formattedTime: String {
        TimeInterval(elapsedTime).formattedDuration
    }
    
    /// Calcula ritmo_s_km desde elapsedTime y distance (misma fuente que formattedTime)
    /// REGLA: ritmo_s_km = round(elapsed_time / (distance/1000))
    /// Esta es la fuente única de verdad para todos los cálculos de ritmo
    var ritmoSKm: Int? {
        let distanceKm = distance / 1000.0
        guard distanceKm > 0 else { return nil }
        return Int((Double(elapsedTime) / distanceKm).rounded())
    }
    
    /// Formatea el ritmo desde ritmo_s_km (formato: "M:SS")
    /// BUG CORREGIDO: Ahora usa elapsedTime (no movingTime, no averageSpeed) como fuente única
    var formattedPace: String {
        guard let secondsPerKm = ritmoSKm else { return "--:--" }
        let minutes = secondsPerKm / 60
        let seconds = secondsPerKm % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedSpeed: String {
        averageSpeed.speedKmh
    }
    
    var formattedHeartrate: String {
        guard let hr = averageHeartrate else { return "--" }
        return String(format: "%.0f", hr)
    }
    
    var formattedElevation: String {
        let sign = elevationDifference >= 0 ? "+" : ""
        return "\(sign)\(Int(elevationDifference))m"
    }
    
    // MARK: - Debug Validation
    
    /// Valida que el ritmo calculado sea consistente con el tiempo mostrado
    /// Para splits de ~1km, el ritmo debería ser similar al tiempo (diferencia <= 1 segundo)
    /// Retorna true si es correcto, false si hay inconsistencia
    func validatePaceConsistency() -> Bool {
        guard let secondsPerKm = ritmoSKm else { return true }
        
        // Para splits de ~1km (950-1050m), el ritmo debería ser similar al tiempo
        if distance >= 950 && distance <= 1050 {
            let difference = abs(secondsPerKm - elapsedTime)
            if difference > 1 {
                #if DEBUG
                print("⚠️ Inconsistencia detectada en split \(splitIndex + 1):")
                print("   Tiempo (elapsed): \(elapsedTime)s, Ritmo calculado: \(secondsPerKm)s/km, Diferencia: \(difference)s")
                print("   Distancia: \(distance)m, distanceKm: \(distance/1000)")
                #endif
                return false
            }
        }
        return true
    }
    
    // MARK: - Unit Tests Helpers
    
    /// Tests unitarios para validar el cálculo de ritmo
    /// Ejemplos de casos de prueba:
    /// - 1000m, 307s -> ritmo_s_km=307 (5:07)
    /// - 1000m, 304s -> ritmo_s_km=304 (5:04)
    /// - 290m, 84s -> ritmo_s_km=round(84/0.29)=290 (4:50)
    static func runPaceCalculationTests() {
        #if DEBUG
        print("\n========== TESTS DE CÁLCULO DE RITMO ==========")
        
        // Test 1: 1000m, 307s -> ritmo_s_km=307 (5:07)
        let test1 = ActivitySplit(
            splitIndex: 0,
            distance: 1000.0,
            movingTime: 307,
            elapsedTime: 307,
            averageSpeed: 1000.0 / 307.0
        )
        assert(test1.ritmoSKm == 307, "Test 1 falló: esperado 307, obtenido \(test1.ritmoSKm ?? -1)")
        assert(test1.formattedPace == "5:07", "Test 1 formato falló: esperado '5:07', obtenido '\(test1.formattedPace)'")
        print("✅ Test 1: 1000m, 307s -> ritmo_s_km=307 (5:07)")
        
        // Test 2: 1000m, 304s -> ritmo_s_km=304 (5:04)
        let test2 = ActivitySplit(
            splitIndex: 1,
            distance: 1000.0,
            movingTime: 304,
            elapsedTime: 304,
            averageSpeed: 1000.0 / 304.0
        )
        assert(test2.ritmoSKm == 304, "Test 2 falló: esperado 304, obtenido \(test2.ritmoSKm ?? -1)")
        assert(test2.formattedPace == "5:04", "Test 2 formato falló: esperado '5:04', obtenido '\(test2.formattedPace)'")
        print("✅ Test 2: 1000m, 304s -> ritmo_s_km=304 (5:04)")
        
        // Test 3: 290m, 84s -> ritmo_s_km=round(84/0.29)=290 (4:50)
        let test3 = ActivitySplit(
            splitIndex: 2,
            distance: 290.0,
            movingTime: 84,
            elapsedTime: 84,
            averageSpeed: 290.0 / 84.0
        )
        let expected3 = Int((84.0 / 0.29).rounded()) // 290
        assert(test3.ritmoSKm == expected3, "Test 3 falló: esperado \(expected3), obtenido \(test3.ritmoSKm ?? -1)")
        print("✅ Test 3: 290m, 84s -> ritmo_s_km=\(expected3) (\(test3.formattedPace))")
        
        // Test 4: Verificar consistencia tiempo vs ritmo para ~1km
        let test4 = ActivitySplit(
            splitIndex: 3,
            distance: 1000.0,
            movingTime: 314,
            elapsedTime: 314,
            averageSpeed: 1000.0 / 314.0
        )
        assert(test4.validatePaceConsistency(), "Test 4 falló: inconsistencia detectada")
        print("✅ Test 4: Consistencia validada para split de 1km")
        
        print("========== FIN TESTS ==========\n")
        #endif
    }
}

// MARK: - JSON Export (Formato idéntico a la web)

extension ActivitySplit {
    
    func toExportJSON() -> [String: Any] {
        var json: [String: Any] = [
            "split": splitIndex + 1,
            "distance": distance,
            "moving_time": movingTime,
            "elapsed_time": elapsedTime,
            "average_speed": averageSpeed,
            "elevation_difference": elevationDifference
        ]
        
        if let hr = averageHeartrate {
            json["average_heartrate"] = hr
        }
        if let zone = paceZone {
            json["pace_zone"] = zone
        }
        
        return json
    }
    
    /// Formato para export JSON web
    /// Usa elapsedTime como fuente única (según reglas de splits_metric de Strava)
    func toExportJSONWeb(index: Int) -> [String: Any] {
        // distancia_km: redondeado a 2 decimales SOLO para display/export
        // pero el cálculo de ritmo usa distance en metros exactos
        let distanciaKm = roundTo2Decimals(distance / 1000.0)
        
        // tiempo: formato de elapsedTime
        let tiempo = Activity.formatTime(elapsedTime)
        
        // ritmo_s_km: calculado desde elapsedTime y distance (misma fuente que tiempo)
        let ritmoSKmValue: Any = ritmoSKm != nil ? ritmoSKm! : NSNull()
        
        // ritmo: formato de ritmo_s_km
        let ritmo = formattedPace
        
        // Construir en el mismo orden que la web
        var json: [String: Any] = [:]
        json["parcial"] = index
        json["nombre"] = "Km \(index)"
        json["distancia_km"] = distanciaKm
        json["tiempo"] = tiempo
        json["tiempo_s"] = elapsedTime
        json["ritmo"] = ritmo
        json["ritmo_s_km"] = ritmoSKmValue
        json["desnivel_m"] = Int(elevationDifference.rounded())
        json["fc_media"] = averageHeartrate != nil ? Int(averageHeartrate!.rounded()) : NSNull()
        // NO incluir fc_max, potencia_media, cadencia_media (Strava no los devuelve por split)
        
        return json
    }
    
    /// Helper para redondear a 2 decimales (solo para display)
    private func roundTo2Decimals(_ value: Double) -> Double {
        return (value * 100).rounded() / 100
    }
}

