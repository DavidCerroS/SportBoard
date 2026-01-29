//
//  WebJSONExporter.swift
//  SportBoardApp
//
//  Exportador canónico de JSON idéntico a la web.
//  Garantiza: mismo orden de claves, mismo formato, mismos valores.
//

import Foundation

/// Exportador que genera JSON idéntico byte-a-byte al de la web
struct WebJSONExporter {
    
    // MARK: - Public API
    
    /// Exporta una actividad como JSON canónico idéntico a la web
    static func exportActivityAsWebJSON(_ activity: Activity) -> String {
        var lines: [String] = []
        lines.append("{")
        
        // Orden EXACTO top-level (web):
        // nombre, tipo, fecha, distancia_km, tiempo_total, tiempo_total_s,
        // ritmo_medio, desnivel_positivo_m, fc_media, fc_max, tipo_parciales, parciales
        
        // Usamos startDateLocal si existe, sino fallback a startDate
        let dateForExport = activity.startDateLocal ?? activity.startDate
        let fecha = formatFechaWeb(dateForExport)
        let distanciaKm = formatDistanceKm(activity.distance)
        let tiempoTotal = formatDuration(activity.movingTime)
        let ritmoMedio = formatRitmoMedio(activity.averageSpeed)
        let desnivelPositivo = Int(activity.totalElevationGain.rounded())
        let fcMedia = formatOptionalInt(activity.averageHeartrate)
        let fcMax = formatOptionalInt(activity.maxHeartrate)
        
        // Determinar parciales
        let useLaps = (activity.sortedLaps?.count ?? 0) > 1
        let tipoParciales = useLaps ? "intervalos" : "kilometros"
        
        // Top-level fields
        lines.append("  \"nombre\": \(escapeString(activity.name)),")
        lines.append("  \"tipo\": \(escapeString(activity.sportType)),")
        lines.append("  \"fecha\": \(escapeString(fecha)),")
        lines.append("  \"distancia_km\": \(distanciaKm),")
        lines.append("  \"tiempo_total\": \(escapeString(tiempoTotal)),")
        lines.append("  \"tiempo_total_s\": \(activity.movingTime),")
        lines.append("  \"ritmo_medio\": \(escapeString(ritmoMedio)),")
        lines.append("  \"desnivel_positivo_m\": \(desnivelPositivo),")
        lines.append("  \"fc_media\": \(fcMedia),")
        lines.append("  \"fc_max\": \(fcMax),")
        lines.append("  \"tipo_parciales\": \(escapeString(tipoParciales)),")
        
        // Parciales
        let parcialesJSON = buildParcialesJSON(activity: activity, useLaps: useLaps)
        lines.append("  \"parciales\": \(parcialesJSON)")
        
        lines.append("}")
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Parciales
    
    private static func buildParcialesJSON(activity: Activity, useLaps: Bool) -> String {
        var parciales: [[String: Any]] = []
        
        if useLaps, let laps = activity.sortedLaps {
            for (index, lap) in laps.enumerated() {
                parciales.append(buildLapParcial(lap: lap, index: index + 1))
            }
        } else if let splits = activity.sortedSplits, !splits.isEmpty {
            for (index, split) in splits.enumerated() {
                parciales.append(buildSplitParcial(split: split, index: index + 1))
            }
        }
        
        if parciales.isEmpty {
            return "[]"
        }
        
        // Construir array de parciales con formato web
        var arrayLines: [String] = []
        arrayLines.append("[")
        
        for (i, parcial) in parciales.enumerated() {
            let isLast = (i == parciales.count - 1)
            let parcialJSON = buildParcialJSON(parcial)
            
            // Indentar cada línea del parcial
            let indentedLines = parcialJSON.split(separator: "\n").map { "    " + $0 }
            let parcialStr = indentedLines.joined(separator: "\n")
            
            if isLast {
                arrayLines.append(parcialStr)
            } else {
                // Añadir coma después del cierre }
                var lines = parcialStr.split(separator: "\n").map { String($0) }
                if let lastIdx = lines.indices.last {
                    lines[lastIdx] = lines[lastIdx] + ","
                }
                arrayLines.append(lines.joined(separator: "\n"))
            }
        }
        
        arrayLines.append("  ]")
        
        return arrayLines.joined(separator: "\n")
    }
    
    private static func buildLapParcial(lap: ActivityLap, index: Int) -> [String: Any] {
        // Orden EXACTO de cada parcial (web):
        // parcial, nombre, distancia_km, tiempo, tiempo_s, ritmo, ritmo_s_km,
        // desnivel_m, fc_media, fc_max, potencia_media, cadencia_media
        
        let distanciaKm = roundTo2Decimals(lap.distance / 1000)
        let tiempo = formatTime(lap.movingTime)
        
        // ritmo_s_km es la fuente de la verdad: round(moving_time / (distance_m / 1000))
        let ritmoSKm: Int? = {
            let distanceKm = lap.distance / 1000
            guard distanceKm > 0 else { return nil }
            return Int((Double(lap.movingTime) / distanceKm).rounded())
        }()
        
        // ritmo debe derivarse únicamente de ritmo_s_km, formateado como m:ss
        let ritmo: String = {
            guard let ritmoSKmValue = ritmoSKm else { return "-" }
            return formatPaceFromSeconds(ritmoSKmValue)
        }()
        
        let desnivelM = Int(lap.totalElevationGain.rounded())
        
        return [
            "parcial": index,
            "nombre": lap.name ?? "Lap \(index)",
            "distancia_km": distanciaKm,
            "tiempo": tiempo,
            "tiempo_s": lap.movingTime,
            "ritmo": ritmo,
            "ritmo_s_km": ritmoSKm ?? NSNull(),
            "desnivel_m": desnivelM,
            "fc_media": lap.averageHeartrate != nil ? Int(lap.averageHeartrate!.rounded()) : NSNull(),
            "fc_max": NSNull(), // Strava no devuelve fc_max por parcial
            "potencia_media": NSNull(), // Strava no devuelve potencia por parcial
            "cadencia_media": NSNull() // Strava no devuelve cadencia por parcial
        ]
    }
    
    private static func buildSplitParcial(split: ActivitySplit, index: Int) -> [String: Any] {
        // Usar los valores ya calculados y consistentes del modelo
        // El modelo ya calcula ritmo_s_km desde elapsedTime y distance
        let distanciaKm = roundTo2Decimals(split.distance / 1000.0)
        let tiempo = formatTime(split.elapsedTime) // Usar elapsedTime, no movingTime
        let ritmo = split.formattedPace // Ya calculado desde ritmo_s_km
        let ritmoSKmAny: Any = split.ritmoSKm.map { $0 } ?? NSNull() // Ya calculado desde elapsedTime
        
        let desnivelM = Int(split.elevationDifference.rounded())
        
        return [
            "parcial": index,
            "nombre": "Km \(index)",
            "distancia_km": distanciaKm,
            "tiempo": tiempo,
            "tiempo_s": split.elapsedTime, // Usar elapsedTime
            "ritmo": ritmo,
            "ritmo_s_km": ritmoSKmAny,
            "desnivel_m": desnivelM,
            "fc_media": split.averageHeartrate != nil ? Int(split.averageHeartrate!.rounded()) : NSNull()
            // NO incluir fc_max, potencia_media, cadencia_media (Strava no los devuelve)
        ]
    }
    
    private static func buildParcialJSON(_ parcial: [String: Any]) -> String {
        // Orden EXACTO de claves (sin incluir campos que siempre son null)
        let keys = [
            "parcial", "nombre", "distancia_km", "tiempo", "tiempo_s",
            "ritmo", "ritmo_s_km", "desnivel_m", "fc_media"
        ]
        
        // Campos opcionales que solo se incluyen si no son null
        let optionalKeys = ["fc_max", "potencia_media", "cadencia_media"]
        
        var lines: [String] = []
        lines.append("{")
        
        // Primero los campos obligatorios
        var allKeys = keys
        for key in optionalKeys {
            if let value = parcial[key], !(value is NSNull) {
                allKeys.append(key)
            }
        }
        
        for (i, key) in allKeys.enumerated() {
            let isLast = (i == allKeys.count - 1)
            let value = parcial[key]
            let valueStr = formatValue(value)
            let comma = isLast ? "" : ","
            lines.append("  \"\(key)\": \(valueStr)\(comma)")
        }
        
        lines.append("}")
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Formatting Helpers
    
    /// Fecha en formato: "d/M/yyyy, H:mm:ss"
    /// startDateLocal ya contiene la hora local tal cual vino de Strava
    /// Formateamos con UTC (secondsFromGMT: 0) para no modificar los valores
    private static func formatFechaWeb(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M/yyyy, H:mm:ss"
        formatter.locale = Locale(identifier: "es_ES")
        // UTC para no modificar los valores - startDateLocal ya tiene la hora correcta
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
    
    /// Duración en formato web: "Xh Ym" o "Xm Ys" o "Xs"
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
    
    /// Tiempo de parcial en formato web: "H:MM:SS" o "M:SS"
    private static func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        
        if mins >= 60 {
            let hours = mins / 60
            let remainingMins = mins % 60
            return "\(hours):\(String(format: "%02d", remainingMins)):\(String(format: "%02d", secs))"
        }
        return "\(mins):\(String(format: "%02d", secs))"
    }
    
    /// Ritmo medio en formato web: "M:SS /km"
    private static func formatRitmoMedio(_ speedMs: Double) -> String {
        guard speedMs > 0 else { return "0:00 /km" }
        let paceSeconds = 1000 / speedMs
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds.rounded()) % 60
        return "\(minutes):\(String(format: "%02d", seconds)) /km"
    }
    
    /// Ritmo de parcial en formato web: "M:SS" o "-"
    /// DEPRECATED: Usar formatPaceFromSeconds en su lugar
    private static func formatPaceFromSpeed(_ speedMs: Double) -> String {
        guard speedMs > 0 else { return "-" }
        let paceSeconds = 1000 / speedMs
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds.rounded()) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    /// Formatea ritmo desde segundos por km: "M:SS"
    /// Esta es la función correcta para derivar ritmo de ritmo_s_km
    private static func formatPaceFromSeconds(_ secondsPerKm: Int) -> String {
        let minutes = secondsPerKm / 60
        let seconds = secondsPerKm % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    /// Distancia en km con formato web: parseFloat((distance / 1000).toFixed(2))
    /// Esto devuelve el número sin trailing zeros: 9.30 -> 9.3, 9.00 -> 9
    private static func formatDistanceKm(_ meters: Double) -> String {
        let km = meters / 1000
        let rounded = roundTo2Decimals(km)
        
        // Formatear sin trailing zeros (como JavaScript parseFloat)
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        } else if (rounded * 10).truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.1f", rounded)
        } else {
            return String(format: "%.2f", rounded)
        }
    }
    
    /// Redondea a 2 decimales
    private static func roundTo2Decimals(_ value: Double) -> Double {
        return (value * 100).rounded() / 100
    }
    
    /// Formatea un Double opcional como Int o null
    private static func formatOptionalInt(_ value: Double?) -> String {
        guard let v = value else { return "null" }
        return String(Int(v.rounded()))
    }
    
    /// Formatea cualquier valor para JSON
    private static func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "null" }
        
        if value is NSNull {
            return "null"
        } else if let str = value as? String {
            return escapeString(str)
        } else if let num = value as? Int {
            return String(num)
        } else if let num = value as? Double {
            // Formatear sin trailing zeros
            if num == num.rounded() {
                return String(format: "%.0f", num)
            } else if (num * 10).truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.1f", num)
            } else {
                return String(format: "%.2f", num)
            }
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        
        return "null"
    }
    
    /// Escapa un string para JSON
    private static func escapeString(_ str: String) -> String {
        var escaped = str
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}
