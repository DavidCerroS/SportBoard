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
        // ritmo_medio, desnivel_positivo_m, fc_media, fc_max,
        // potencia_media, potencia_max, tipo_parciales, parciales
        
        // Usamos startDateLocal si existe, sino fallback a startDate
        let dateForExport = activity.startDateLocal ?? activity.startDate
        let fecha = formatFechaWeb(dateForExport)
        let distanciaKm = formatDistanceKm(activity.distance)
        let exportMovingTime = exportMovingTimeSeconds(activity)
        let tiempoTotal = formatDuration(exportMovingTime)
        let ritmoMedio = formatRitmoMedio(distance: activity.distance, movingTime: exportMovingTime, fallbackSpeed: activity.averageSpeed)
        let desnivelPositivo = Int(activity.totalElevationGain.rounded())
        let fcMedia = formatOptionalInt(activity.averageHeartrate)
        let fcMax = formatOptionalInt(activity.maxHeartrate)
        let isRun = isRunSportType(activity.sportType)
        let potenciaMedia = isRun ? formatOptionalInt(activity.averageWatts) : "null"
        let potenciaMax = isRun ? formatOptionalInt(activity.maxWatts) : "null"
        let weightedWatts = isRun ? formatOptionalInt(activity.weightedAverageWatts) : "null"
        
        // Determinar parciales
        let useLaps = (activity.sortedLaps?.count ?? 0) > 1
        let tipoParciales = useLaps ? "intervalos" : "kilometros"
        
        // Top-level fields
        lines.append("  \"nombre\": \(escapeString(activity.name)),")
        lines.append("  \"tipo\": \(escapeString(activity.sportType)),")
        lines.append("  \"fecha\": \(escapeString(fecha)),")
        lines.append("  \"distancia_km\": \(distanciaKm),")
        lines.append("  \"tiempo_total\": \(escapeString(tiempoTotal)),")
        lines.append("  \"tiempo_total_s\": \(exportMovingTime),")
        lines.append("  \"tiempo_transcurrido_s\": \(activity.elapsedTime),")
        lines.append("  \"tiempo_parado_s\": \(activity.streamSummary?.stoppedTimeSeconds ?? max(activity.elapsedTime - exportMovingTime, 0)),")
        lines.append("  \"ritmo_medio\": \(escapeString(ritmoMedio)),")
        lines.append("  \"desnivel_positivo_m\": \(desnivelPositivo),")
        lines.append("  \"fc_media\": \(fcMedia),")
        lines.append("  \"fc_max\": \(fcMax),")
        lines.append("  \"potencia_media\": \(potenciaMedia),")
        lines.append("  \"potencia_max\": \(potenciaMax),")
        lines.append("  \"potencia_normalizada_estimada\": \(weightedWatts),")
        lines.append("  \"calorias\": \(formatOptionalInt(activity.calories)),")
        lines.append("  \"tipo_entreno_strava\": \(formatOptionalInt(activity.workoutType.map(Double.init))),")
        lines.append("  \"zapatilla_id\": \(activity.gearId.map(escapeString) ?? "null"),")
        lines.append("  \"zapatilla\": \(formatValue(buildGearJSON(activity.gear))),")
        lines.append("  \"manual\": \(formatValue(activity.manual)),")
        lines.append("  \"privada\": \(formatValue(activity.isPrivate)),")
        lines.append("  \"flagged\": \(formatValue(activity.flagged)),")
        lines.append("  \"indoor\": \(formatValue(activity.trainer)),")
        lines.append("  \"altitud_max_m\": \(formatOptionalNumber(activity.elevHigh)),")
        lines.append("  \"altitud_min_m\": \(formatOptionalNumber(activity.elevLow)),")
        lines.append("  \"logros_count\": \(formatOptionalInt(activity.achievementCount.map(Double.init))),")
        lines.append("  \"kudos_count\": \(formatOptionalInt(activity.kudosCount.map(Double.init))),")
        lines.append("  \"comentarios_count\": \(formatOptionalInt(activity.commentCount.map(Double.init))),")
        lines.append("  \"atletas_count\": \(formatOptionalInt(activity.athleteCount.map(Double.init))),")
        lines.append("  \"fotos_count\": \(formatOptionalInt(activity.photoCount.map(Double.init))),")
        lines.append("  \"streams_resumen\": \(formatValue(buildStreamSummaryJSON(activity.streamSummary))),")
        lines.append("  \"zonas\": \(formatValue(buildZonesJSON(activity.zones ?? []))),")
        lines.append("  \"tiempo_zonas_fc_s\": \(formatValue(zoneTimes(activity.zones ?? [], type: "heartrate"))),")
        lines.append("  \"tiempo_zonas_potencia_s\": \(formatValue(zoneTimes(activity.zones ?? [], type: "power"))),")
        lines.append("  \"tipo_parciales\": \(escapeString(tipoParciales)),")
        
        // Parciales
        let parcialesJSON = buildParcialesJSON(activity: activity, useLaps: useLaps)
        lines.append("  \"parciales\": \(parcialesJSON),")
        lines.append("  \"segmentos\": \(formatValue(buildSegmentEffortsJSON(activity.sortedVisibleSegmentEfforts))),")
        lines.append("  \"tempo_detalle\": \(formatValue(buildTempoDetailJSON(activity.sortedTempoBlockSplits)))")
        
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
        // desnivel_m, desnivel_positivo_m, desnivel_negativo_m,
        // fc_media, fc_max, potencia_media, potencia_max, cadencia_media
        
        let distanciaKm = roundTo2Decimals(lap.distance / 1000)
        let movingTime = lap.movingTimeFromStream ?? lap.movingTime
        let tiempo = formatTime(movingTime)
        
        // ritmo_s_km es la fuente de la verdad: round(moving_time / (distance_m / 1000))
        let ritmoSKm: Int? = {
            let distanceKm = lap.distance / 1000
            guard distanceKm > 0 else { return nil }
            return Int((Double(movingTime) / distanceKm).rounded())
        }()
        
        // ritmo debe derivarse únicamente de ritmo_s_km, formateado como m:ss
        let ritmo: String = {
            guard let ritmoSKmValue = ritmoSKm else { return "-" }
            return formatPaceFromSeconds(ritmoSKmValue)
        }()
        
        let desnivelPositivoM = Int(lap.effectivePositiveElevationGain.rounded())
        let desnivelNegativoM = Int(lap.effectiveNegativeElevationLoss.rounded())
        let desnivelM = desnivelPositivoM - desnivelNegativoM
        
        return [
            "parcial": index,
            "nombre": lap.name ?? "Lap \(index)",
            "distancia_km": distanciaKm,
            "tiempo": tiempo,
            "tiempo_s": movingTime,
            "ritmo": ritmo,
            "ritmo_s_km": ritmoSKm ?? NSNull(),
            "desnivel_m": desnivelM,
            "desnivel_positivo_m": desnivelPositivoM,
            "desnivel_negativo_m": desnivelNegativoM,
            "fc_media": lap.averageHeartrate != nil ? Int(lap.averageHeartrate!.rounded()) : NSNull(),
            "fc_max": lap.maxHeartrate != nil ? Int(lap.maxHeartrate!.rounded()) : NSNull(),
            "potencia_media": lap.averageWatts != nil ? Int(lap.averageWatts!.rounded()) : NSNull(),
            "potencia_max": lap.maxWatts != nil ? Int(lap.maxWatts!.rounded()) : NSNull(),
            "cadencia_media": lap.averageCadence != nil ? Int(lap.averageCadence!.rounded()) : NSNull(),
            "pendiente_media_pct": lap.averageGrade ?? NSNull(),
            "tiempo_movimiento_s": movingTime
        ]
    }
    
    private static func buildSplitParcial(split: ActivitySplit, index: Int) -> [String: Any] {
        // Usar los valores ya calculados y consistentes del modelo
        // El modelo ya calcula ritmo_s_km desde elapsedTime y distance
        let distanciaKm = roundTo2Decimals(split.distance / 1000.0)
        let movingTime = split.movingTimeFromStream ?? split.movingTime
        let tiempo = formatTime(movingTime)
        let ritmoSKm: Int? = {
            let km = split.distance / 1000
            guard km > 0 else { return nil }
            return Int((Double(movingTime) / km).rounded())
        }()
        let ritmo = ritmoSKm.map(formatPaceFromSeconds) ?? "-"
        let ritmoSKmAny: Any = ritmoSKm ?? NSNull()
        
        let desnivelPositivoM = Int(split.effectivePositiveElevationGain.rounded())
        let desnivelNegativoM = Int(split.effectiveNegativeElevationLoss.rounded())
        let desnivelM = desnivelPositivoM - desnivelNegativoM
        
        return [
            "parcial": index,
            "nombre": "Km \(index)",
            "distancia_km": distanciaKm,
            "tiempo": tiempo,
            "tiempo_s": movingTime,
            "ritmo": ritmo,
            "ritmo_s_km": ritmoSKmAny,
            "desnivel_m": desnivelM,
            "desnivel_positivo_m": desnivelPositivoM,
            "desnivel_negativo_m": desnivelNegativoM,
            "fc_media": split.averageHeartrate != nil ? Int(split.averageHeartrate!.rounded()) : NSNull(),
            "fc_max": split.maxHeartrate != nil ? Int(split.maxHeartrate!.rounded()) : NSNull(),
            "potencia_media": split.averageWatts != nil ? Int(split.averageWatts!.rounded()) : NSNull(),
            "potencia_max": split.maxWatts != nil ? Int(split.maxWatts!.rounded()) : NSNull(),
            "cadencia_media": split.averageCadence != nil ? Int(split.averageCadence!.rounded()) : NSNull(),
            "pendiente_media_pct": split.averageGrade ?? NSNull(),
            "tiempo_movimiento_s": movingTime
        ]
    }
    
    private static func buildParcialJSON(_ parcial: [String: Any]) -> String {
        // Orden EXACTO de claves (sin incluir campos que siempre son null)
        let keys = [
            "parcial", "nombre", "distancia_km", "tiempo", "tiempo_s",
            "ritmo", "ritmo_s_km", "desnivel_m", "desnivel_positivo_m",
            "desnivel_negativo_m", "fc_media"
        ]
        
        // Campos opcionales que solo se incluyen si no son null
        let optionalKeys = ["fc_max", "potencia_media", "potencia_max", "cadencia_media", "pendiente_media_pct", "tiempo_movimiento_s"]
        
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

    private static func roundTo3Decimals(_ value: Double) -> Double {
        return (value * 1000).rounded() / 1000
    }

    private static func exportMovingTimeSeconds(_ activity: Activity) -> Int {
        guard let stoppedTime = activity.streamSummary?.stoppedTimeSeconds else {
            return activity.movingTime
        }
        return max(activity.movingTime - stoppedTime, 0)
    }

    private static func formatRitmoMedio(distance: Double, movingTime: Int, fallbackSpeed: Double) -> String {
        let speed = movingTime > 0 && distance > 0 ? distance / Double(movingTime) : fallbackSpeed
        return formatRitmoMedio(speed)
    }
    
    /// Formatea un Double opcional como Int o null
    private static func formatOptionalInt(_ value: Double?) -> String {
        guard let v = value else { return "null" }
        return String(Int(v.rounded()))
    }

    private static func formatOptionalNumber(_ value: Double?) -> String {
        guard let value else { return "null" }
        return formatValue(value)
    }

    private static func buildGearJSON(_ gear: StravaGear?) -> [String: Any]? {
        guard let gear else { return nil }
        return [
            "id": gear.id,
            "nombre": gear.name,
            "marca": gear.brandName ?? NSNull(),
            "modelo": gear.modelName ?? NSNull(),
            "distancia_total_km": gear.distanceMeters.map { roundTo2Decimals($0 / 1000) } ?? NSNull(),
            "retirada": gear.retired
        ]
    }

    private static func buildStreamSummaryJSON(_ summary: ActivityStreamSummary?) -> [String: Any]? {
        guard let summary else { return nil }
        return [
            "cadencia_media": summary.averageCadence.map { Int($0.rounded()) } ?? NSNull(),
            "cadencia_max": summary.maxCadence.map { Int($0.rounded()) } ?? NSNull(),
            "pendiente_media_pct": summary.averageGrade ?? NSNull(),
            "pendiente_max_pct": summary.maxGrade ?? NSNull(),
            "pendiente_min_pct": summary.minGrade ?? NSNull(),
            "ratio_movimiento": summary.movingRatio ?? NSNull(),
            "tiempo_parado_s": summary.stoppedTimeSeconds ?? NSNull(),
            "ritmo_medio_movimiento_s_km": summary.averageMovingPaceSecondsPerKm ?? NSNull(),
            "deriva_cardiaca_pct": summary.cardiacDriftPercent ?? NSNull(),
            "temperatura_media_c": summary.averageTemperature ?? NSNull()
        ]
    }

    private static func buildZonesJSON(_ zones: [ActivityZoneDistribution]) -> [[String: Any]] {
        zones.sorted { $0.zoneType < $1.zoneType }.map { zone in
            [
                "tipo": zone.zoneType,
                "sensor": zone.sensorBased,
                "score": zone.score ?? NSNull(),
                "distribucion": parseDistribution(zone.distributionJSON)
            ]
        }
    }

    private static func zoneTimes(_ zones: [ActivityZoneDistribution], type: String) -> [Int] {
        guard let zone = zones.first(where: { $0.zoneType == type }) else { return [] }
        return parseDistribution(zone.distributionJSON).compactMap { $0["time"] as? Int }
    }

    private static func parseDistribution(_ json: String) -> [[String: Any]] {
        guard
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }
        return object
    }

    private static func buildSegmentEffortsJSON(_ efforts: [ActivitySegmentEffort]) -> [[String: Any]] {
        efforts.map { effort in
            let paceSeconds: Any = {
                let km = effort.distance / 1000
                guard km > 0 else { return NSNull() }
                return Int((Double(effort.elapsedTime) / km).rounded())
            }()
            return [
                "nombre": effort.name,
                "segmento_id": effort.segmentId ?? NSNull(),
                "distancia_m": Int(effort.distance.rounded()),
                "tiempo_s": effort.elapsedTime,
                "ritmo_s_km": paceSeconds,
                "fc_media": effort.averageHeartrate.map { Int($0.rounded()) } ?? NSNull(),
                "fc_max": effort.maxHeartrate.map { Int($0.rounded()) } ?? NSNull(),
                "potencia_media": effort.averageWatts.map { Int($0.rounded()) } ?? NSNull(),
                "pr_rank": effort.prRank ?? NSNull(),
                "kom_rank": effort.komRank ?? NSNull()
            ]
        }
    }

    private static func buildTempoDetailJSON(_ splits: [ActivityTempoBlockSplit]) -> [[String: Any]] {
        splits.map { split in
            let movingTime = split.movingTime
            let paceSeconds: Int? = {
                let km = split.distance / 1000
                guard km > 0 else { return nil }
                return Int((Double(movingTime) / km).rounded())
            }()
            let desnivelPositivoM = Int(split.positiveElevationGain.rounded())
            let desnivelNegativoM = Int(split.negativeElevationLoss.rounded())
            return [
                "bloque_lap": split.blockLapIndex,
                "parcial": split.splitIndex,
                "nombre": split.name,
                "distancia_km": roundTo3Decimals(split.distance / 1000),
                "desde_km_bloque": roundTo3Decimals(split.startDistance / 1000),
                "hasta_km_bloque": roundTo3Decimals(split.endDistance / 1000),
                "tiempo": formatTime(movingTime),
                "tiempo_s": movingTime,
                "tiempo_movimiento_s": movingTime,
                "ritmo": paceSeconds.map(formatPaceFromSeconds) ?? "-",
                "ritmo_s_km": paceSeconds ?? NSNull(),
                "desnivel_m": desnivelPositivoM - desnivelNegativoM,
                "desnivel_positivo_m": desnivelPositivoM,
                "desnivel_negativo_m": desnivelNegativoM,
                "fc_media": split.averageHeartrate.map { Int($0.rounded()) } ?? NSNull(),
                "fc_max": split.maxHeartrate.map { Int($0.rounded()) } ?? NSNull(),
                "potencia_media": split.averageWatts.map { Int($0.rounded()) } ?? NSNull(),
                "potencia_max": split.maxWatts.map { Int($0.rounded()) } ?? NSNull(),
                "cadencia_media": split.averageCadence.map { Int($0.rounded()) } ?? NSNull(),
                "pendiente_media_pct": split.averageGrade ?? NSNull()
            ]
        }
    }

    private static func isRunSportType(_ sportType: String) -> Bool {
        ["run", "trailrun", "virtualrun"].contains(sportType.lowercased())
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
            } else if (num * 10).rounded() / 10 == num {
                return String(format: "%.1f", num)
            } else if (num * 100).rounded() / 100 == num {
                return String(format: "%.2f", num)
            } else {
                return String(format: "%.3f", num)
            }
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let array = value as? [Any] {
            return "[\(array.map(formatValue).joined(separator: ", "))]"
        } else if let array = value as? [[String: Any]] {
            return "[\(array.map { formatValue($0) }.joined(separator: ", "))]"
        } else if let dict = value as? [String: Any] {
            let pairs = dict.keys.sorted().map { key in
                "\(escapeString(key)): \(formatValue(dict[key]))"
            }
            return "{\(pairs.joined(separator: ", "))}"
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
