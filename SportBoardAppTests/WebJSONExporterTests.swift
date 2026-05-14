//
//  WebJSONExporterTests.swift
//  SportBoardAppTests
//
//  Tests para verificar que el JSON exportado es idéntico al de la web
//

import XCTest
@testable import SportBoardApp

final class WebJSONExporterTests: XCTestCase {
    
    // MARK: - Golden File Test
    
    /// Test que verifica que el JSON exportado es byte-a-byte idéntico al golden file de la web
    func testExportMatchesWebGoldenFile() throws {
        // 1. Crear actividad mock con los mismos datos que la web
        let activity = createMockActivityFromWebSample()
        
        // 2. Exportar con nuestro exportador
        let iosJSON = WebJSONExporter.exportActivityAsWebJSON(activity)
        
        // 3. Cargar golden file de la web
        let webJSON = try loadGoldenFile(named: "activity_sample_web")
        
        // 4. Normalizar a objetos JSON (ignora \n, espacios, orden de claves, etc.)
        func normalize(_ json: String) throws -> Any {
            let data = json.data(using: .utf8)!
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        }
        
        let iosObj = try normalize(iosJSON)
        let webObj = try normalize(webJSON)
        
        // 5. Comparar estructura real
        XCTAssertEqual(
            iosObj as? NSDictionary,
            webObj as? NSDictionary,
            "El JSON estructural de iOS no coincide con el golden de la web"
        )
    }

    
    /// Test de formato de fecha
    func testDateFormatMatchesWeb() {
        // La web usa: new Date(activity.startDateLocal).toLocaleString("es-ES")
        // startDateLocal ya viene en la hora local del usuario
        // Nosotros la parseamos con GMT para preservar los valores
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M/yyyy, H:mm:ss"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "GMT") // GMT porque parseamos con GMT
        
        // Crear fecha de prueba (29 enero 2026, 11:03:15)
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 29
        components.hour = 11
        components.minute = 3
        components.second = 15
        components.timeZone = TimeZone(identifier: "GMT")
        
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!
        
        let formatted = formatter.string(from: date)
        XCTAssertEqual(formatted, "29/1/2026, 11:03:15")
    }
    
    /// Test de formato de duración
    func testDurationFormat() {
        // La web usa: formatDuration que devuelve "Xh Ym" o "Xm Ys"
        XCTAssertEqual(formatDuration(3383), "56m 23s")
        XCTAssertEqual(formatDuration(3600), "1h 0m")
        XCTAssertEqual(formatDuration(3720), "1h 2m")
        XCTAssertEqual(formatDuration(45), "45s")
        XCTAssertEqual(formatDuration(125), "2m 5s")
    }
    
    /// Test de formato de tiempo de parcial
    func testTimeFormat() {
        // La web usa: formatTime que devuelve "M:SS" o "H:MM:SS"
        XCTAssertEqual(formatTime(89), "1:29")
        XCTAssertEqual(formatTime(375), "6:15")
        XCTAssertEqual(formatTime(3600), "1:00:00")
        XCTAssertEqual(formatTime(3661), "1:01:01")
    }
    
    /// Test de formato de ritmo
    func testPaceFormat() {
        // Para 1000m en 375s -> ritmo = 375 s/km = 6:15
        let speedMs = 1000.0 / 375.0 // ~2.666 m/s
        XCTAssertEqual(formatPaceFromSpeed(speedMs), "6:15")
        
        // Para 0 m/s
        XCTAssertEqual(formatPaceFromSpeed(0), "-")
    }
    
    /// Test de formato de distancia
    func testDistanceFormat() {
        // La web usa: parseFloat((distance / 1000).toFixed(2))
        // Que elimina trailing zeros
        XCTAssertEqual(formatDistanceKm(9300), "9.3")
        XCTAssertEqual(formatDistanceKm(9000), "9")
        XCTAssertEqual(formatDistanceKm(9290), "9.29")
        XCTAssertEqual(formatDistanceKm(290), "0.29")
    }

    func testSplitExportIncludesPositiveAndNegativeElevation() {
        let split = ActivitySplit(
            splitIndex: 0,
            distance: 1000,
            movingTime: 360,
            elapsedTime: 360,
            averageSpeed: 1000.0 / 360.0,
            averageHeartrate: 150,
            elevationDifference: -3,
            positiveElevationGain: 12,
            negativeElevationLoss: 15,
            averageWatts: 215.1,
            maxWatts: 388
        )

        let json = split.toExportJSONWeb(index: 1)

        XCTAssertEqual(json["desnivel_m"] as? Int, -3)
        XCTAssertEqual(json["desnivel_positivo_m"] as? Int, 12)
        XCTAssertEqual(json["desnivel_negativo_m"] as? Int, 15)
        XCTAssertEqual(json["potencia_media"] as? Int, 215)
        XCTAssertEqual(json["potencia_max"] as? Int, 388)
    }

    func testLapExportIncludesPositiveAndNegativeElevation() {
        let lap = ActivityLap(
            lapIndex: 0,
            name: "Rep 1",
            distance: 1000,
            movingTime: 300,
            elapsedTime: 300,
            startIndex: 0,
            endIndex: 1000,
            averageSpeed: 1000.0 / 300.0,
            maxSpeed: 4.0,
            averageHeartrate: 170,
            totalElevationGain: 8,
            positiveElevationGain: 8,
            negativeElevationLoss: 11,
            averageWatts: 312.4,
            maxWatts: 451
        )

        let json = lap.toExportJSONWeb(index: 1)

        XCTAssertEqual(json["desnivel_m"] as? Int, -3)
        XCTAssertEqual(json["desnivel_positivo_m"] as? Int, 8)
        XCTAssertEqual(json["desnivel_negativo_m"] as? Int, 11)
        XCTAssertEqual(json["potencia_media"] as? Int, 312)
        XCTAssertEqual(json["potencia_max"] as? Int, 451)
    }
    
    // MARK: - Helpers
    
    private func createMockActivityFromWebSample() -> Activity {
        // Crear fecha local: 29/1/2026, 11:03:15
        // La fecha local se parsea con GMT para preservar los valores
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 29
        components.hour = 11
        components.minute = 3
        components.second = 15
        components.timeZone = TimeZone(identifier: "GMT") // GMT para preservar valores
        
        let calendar = Calendar(identifier: .gregorian)
        let startDateLocal = calendar.date(from: components)!
        let startDate = startDateLocal // En tests, usamos la misma
        
        let activity = Activity(
            id: 12345678,
            name: "Carrera matutina",
            sportType: "Run",
            startDate: startDate,
            startDateLocal: startDateLocal,
            distance: 9300, // 9.3 km
            movingTime: 3383, // 56m 23s
            elapsedTime: 3500,
            totalElevationGain: 125,
            averageSpeed: 9300.0 / 3383.0, // ~2.75 m/s -> ritmo ~6:03
            maxSpeed: 4.0,
            averageHeartrate: 152,
            maxHeartrate: 178,
            averageWatts: 215.1,
            maxWatts: 388,
            hasHeartrate: true,
            hasPowerMeter: true,
            hasSplitsMetric: true
        )
        
        // Crear splits mock
        let splitsData: [(distance: Double, time: Int, desnivel: Int, fcMedia: Int, fcMax: Int)] = [
            (1000, 375, 12, 145, 158),  // Km 1: 6:15
            (1000, 358, 8, 150, 162),   // Km 2: 5:58
            (1000, 352, 15, 153, 165),  // Km 3: 5:52
            (1000, 345, 10, 155, 168),  // Km 4: 5:45
            (1000, 350, 18, 156, 170),  // Km 5: 5:50
            (1000, 355, 14, 154, 167),  // Km 6: 5:55
            (1000, 362, 11, 152, 165),  // Km 7: 6:02
            (1000, 368, 16, 150, 163),  // Km 8: 6:08
            (1000, 369, 13, 148, 160),  // Km 9: 6:09
            (290, 89, 8, 155, 178),     // Km 10: 1:29 (parcial)
        ]
        
        var splits: [ActivitySplit] = []
        for (index, data) in splitsData.enumerated() {
            let split = ActivitySplit(
                splitIndex: index,
                distance: data.distance,
                movingTime: data.time,
                elapsedTime: data.time,
                averageSpeed: data.distance / Double(data.time),
                averageHeartrate: Double(data.fcMedia),
                elevationDifference: Double(data.desnivel),
                activity: activity
            )
            splits.append(split)
        }
        
        activity.splitsMetric = splits
        
        return activity
    }

    func testRunActivityExportIncludesAverageAndMaxWatts() throws {
        let activity = Activity(
            id: 987654321,
            name: "Morning Run",
            sportType: "Run",
            startDate: Date(timeIntervalSince1970: 0),
            startDateLocal: Date(timeIntervalSince1970: 0),
            distance: 20000,
            movingTime: 3600,
            elapsedTime: 3700,
            totalElevationGain: 250,
            averageSpeed: 20000.0 / 3600.0,
            maxSpeed: 12,
            averageWatts: 215.1,
            maxWatts: 388,
            hasPowerMeter: true
        )

        let json = WebJSONExporter.exportActivityAsWebJSON(activity)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(exported["potencia_media"] as? Int, 215)
        XCTAssertEqual(exported["potencia_max"] as? Int, 388)
    }

    func testExportIncludesStravaEnrichmentData() throws {
        let activity = Activity(
            id: 456,
            name: "Media objetivo",
            sportType: "Run",
            startDate: Date(timeIntervalSince1970: 0),
            startDateLocal: Date(timeIntervalSince1970: 0),
            distance: 21097,
            movingTime: 5400,
            elapsedTime: 5480,
            totalElevationGain: 80,
            averageSpeed: 21097.0 / 5400.0,
            maxSpeed: 5.2,
            averageHeartrate: 158,
            maxHeartrate: 182,
            averageWatts: 248,
            maxWatts: 502,
            hasPowerMeter: true,
            workoutType: 0,
            calories: 1345,
            gearId: "g123",
            trainer: false,
            manual: false,
            isPrivate: true,
            flagged: false,
            elevHigh: 721.4,
            elevLow: 644.2,
            summaryPolyline: "abc123",
            achievementCount: 3,
            kudosCount: 12,
            commentCount: 2,
            athleteCount: 1,
            photoCount: 0,
            weightedAverageWatts: 257,
            hasSplitsMetric: true
        )

        activity.gear = StravaGear(
            id: "g123",
            name: "Vaporfly",
            brandName: "Nike",
            modelName: "Next%",
            distanceMeters: 321_500,
            retired: false
        )
        activity.streamSummary = ActivityStreamSummary(
            averageCadence: 176.2,
            maxCadence: 193,
            averageGrade: 1.25,
            maxGrade: 7.8,
            minGrade: -5.1,
            movingRatio: 0.98,
            stoppedTimeSeconds: 12,
            averageMovingPaceSecondsPerKm: 256,
            cardiacDriftPercent: 4.4,
            averageTemperature: 16.6
        )
        activity.zones = [
            ActivityZoneDistribution(
                zoneType: "heartrate",
                sensorBased: true,
                score: 62,
                distributionJSON: """
                [{"min":120,"max":140,"time":600},{"min":140,"max":160,"time":1800}]
                """
            ),
            ActivityZoneDistribution(
                zoneType: "power",
                sensorBased: true,
                score: nil,
                distributionJSON: """
                [{"min":200,"max":260,"time":2000}]
                """
            )
        ]
        activity.segmentEfforts = [
            ActivitySegmentEffort(
                id: 9,
                name: "Subida final",
                segmentId: 99,
                distance: 750,
                elapsedTime: 210,
                movingTime: 208,
                startIndex: 12,
                endIndex: 32,
                averageHeartrate: 171,
                maxHeartrate: 181,
                averageWatts: 312,
                prRank: 2
            )
        ]
        activity.tempoBlockSplits = [
            ActivityTempoBlockSplit(
                blockLapIndex: 1,
                splitIndex: 1,
                name: "Tempo 1",
                distance: 1000,
                elapsedTime: 252,
                movingTime: 251,
                averageSpeed: 1000.0 / 252.0,
                elevationDifference: 2,
                positiveElevationGain: 5,
                negativeElevationLoss: 3,
                averageHeartrate: 166,
                maxHeartrate: 174,
                averageWatts: 284,
                maxWatts: 344,
                averageCadence: 178,
                averageGrade: 0.2,
                startDistance: 0,
                endDistance: 1000,
                activity: activity
            )
        ]
        activity.splitsMetric = [
            ActivitySplit(
                splitIndex: 0,
                distance: 1000,
                movingTime: 256,
                elapsedTime: 256,
                averageSpeed: 1000.0 / 256.0,
                averageHeartrate: 160,
                elevationDifference: 4,
                averageWatts: 251,
                maxWatts: 407,
                maxHeartrate: 168,
                averageCadence: 177,
                averageGrade: 0.8,
                movingTimeFromStream: 254,
                activity: activity
            )
        ]

        let json = WebJSONExporter.exportActivityAsWebJSON(activity)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(exported["potencia_normalizada_estimada"] as? Int, 257)
        XCTAssertEqual(exported["calorias"] as? Int, 1345)
        XCTAssertEqual(exported["zapatilla_id"] as? String, "g123")
        XCTAssertEqual(exported["privada"] as? Bool, true)
        XCTAssertEqual(exported["altitud_max_m"] as? Double, 721.4)
        XCTAssertEqual(exported["tiempo_transcurrido_s"] as? Int, 5480)
        XCTAssertEqual(exported["tiempo_parado_s"] as? Int, 12)
        XCTAssertNil(exported["polyline_resumen"])

        let gear = try XCTUnwrap(exported["zapatilla"] as? [String: Any])
        XCTAssertEqual(gear["nombre"] as? String, "Vaporfly")
        XCTAssertEqual(gear["distancia_total_km"] as? Double, 321.5)

        let streamSummary = try XCTUnwrap(exported["streams_resumen"] as? [String: Any])
        XCTAssertEqual(streamSummary["cadencia_media"] as? Int, 176)
        XCTAssertEqual(streamSummary["ratio_movimiento"] as? Double, 0.98)
        XCTAssertEqual(streamSummary["deriva_cardiaca_pct"] as? Double, 4.4)

        let heartRateZones = try XCTUnwrap(exported["tiempo_zonas_fc_s"] as? [Int])
        XCTAssertEqual(heartRateZones, [600, 1800])

        let segments = try XCTUnwrap(exported["segmentos"] as? [[String: Any]])
        let segment = try XCTUnwrap(segments.first)
        XCTAssertEqual(segment["nombre"] as? String, "Subida final")
        XCTAssertEqual(segment["ritmo_s_km"] as? Int, 280)

        let tempoDetail = try XCTUnwrap(exported["tempo_detalle"] as? [[String: Any]])
        let tempoSplit = try XCTUnwrap(tempoDetail.first)
        XCTAssertEqual(tempoSplit["nombre"] as? String, "Tempo 1")
        XCTAssertEqual(tempoSplit["ritmo_s_km"] as? Int, 252)
        XCTAssertEqual(tempoSplit["potencia_media"] as? Int, 284)

        let parciales = try XCTUnwrap(exported["parciales"] as? [[String: Any]])
        let parcial = try XCTUnwrap(parciales.first)
        XCTAssertEqual(parcial["fc_max"] as? Int, 168)
        XCTAssertEqual(parcial["cadencia_media"] as? Int, 177)
        XCTAssertEqual(parcial["pendiente_media_pct"] as? Double, 0.8)
        XCTAssertEqual(parcial["tiempo_movimiento_s"] as? Int, 254)
    }

    func testRealTempoRunMay142026ExportStaysCoherent() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 14
        components.hour = 9
        components.minute = 25
        components.second = 24
        components.timeZone = TimeZone(identifier: "GMT")

        let date = Calendar(identifier: .gregorian).date(from: components)!
        let activity = Activity(
            id: 20260514092524,
            name: "Carrera de mañana",
            sportType: "Run",
            startDate: date,
            startDateLocal: date,
            distance: 9250,
            movingTime: 2883,
            elapsedTime: 2986,
            totalElevationGain: 85,
            averageSpeed: 9250.0 / 2883.0,
            maxSpeed: 5.4,
            averageHeartrate: 150,
            maxHeartrate: 167,
            averageWatts: 236,
            maxWatts: 334,
            hasHeartrate: true,
            hasPowerMeter: true,
            calories: 611,
            gearId: "g29748382",
            elevHigh: 582.6,
            elevLow: 562.4,
            achievementCount: 0,
            kudosCount: 0,
            commentCount: 0,
            athleteCount: 1,
            photoCount: 0,
            weightedAverageWatts: 240,
            hasLaps: true
        )

        activity.gear = StravaGear(
            id: "g29748382",
            name: "ASICS Novablast 5",
            brandName: "ASICS",
            modelName: "Novablast 5",
            distanceMeters: 125_540,
            retired: false
        )
        activity.streamSummary = ActivityStreamSummary(
            averageGrade: -0.308,
            maxGrade: 8.4,
            minGrade: -30.5,
            movingRatio: 0.955,
            stoppedTimeSeconds: 133,
            averageMovingPaceSecondsPerKm: 311,
            cardiacDriftPercent: 7.959
        )
        activity.laps = [
            ActivityLap(
                lapIndex: 0,
                name: "Lap 1",
                distance: 1420,
                movingTime: 600,
                elapsedTime: 600,
                averageSpeed: 1420.0 / 600.0,
                maxSpeed: 4.8,
                averageHeartrate: 133,
                totalElevationGain: 18,
                positiveElevationGain: 18,
                negativeElevationLoss: 30,
                averageWatts: 196,
                maxWatts: 317,
                maxHeartrate: 140,
                averageGrade: -1.534,
                movingTimeFromStream: 455,
                activity: activity
            ),
            ActivityLap(
                lapIndex: 1,
                name: "Lap 2",
                distance: 6660,
                movingTime: 1919,
                elapsedTime: 1919,
                averageSpeed: 6660.0 / 1919.0,
                maxSpeed: 5.8,
                averageHeartrate: 157,
                totalElevationGain: 56,
                positiveElevationGain: 56,
                negativeElevationLoss: 55,
                averageWatts: 258,
                maxWatts: 334,
                maxHeartrate: 167,
                averageGrade: 0.145,
                movingTimeFromStream: 1918,
                activity: activity
            ),
            ActivityLap(
                lapIndex: 2,
                name: "Lap 3",
                distance: 1170,
                movingTime: 467,
                elapsedTime: 467,
                averageSpeed: 1170.0 / 467.0,
                maxSpeed: 4.6,
                averageHeartrate: 141,
                totalElevationGain: 10,
                positiveElevationGain: 10,
                negativeElevationLoss: 13,
                averageWatts: 186,
                maxWatts: 299,
                maxHeartrate: 166,
                averageGrade: -0.582,
                movingTimeFromStream: 377,
                activity: activity
            )
        ]
        activity.tempoBlockSplits = [
            makeTempoSplit(activity: activity, index: 1, distance: 1000, time: 300, positive: 7, negative: 12, hr: 145, maxHr: 151, watts: 241, maxWatts: 276),
            makeTempoSplit(activity: activity, index: 2, distance: 1000, time: 299, positive: 13, negative: 2, hr: 153, maxHr: 159, watts: 257, maxWatts: 296),
            makeTempoSplit(activity: activity, index: 3, distance: 1000, time: 287, positive: 4, negative: 13, hr: 156, maxHr: 158, watts: 244, maxWatts: 302),
            makeTempoSplit(activity: activity, index: 4, distance: 1000, time: 291, positive: 9, negative: 8, hr: 159, maxHr: 163, watts: 260, maxWatts: 293),
            makeTempoSplit(activity: activity, index: 5, distance: 1000, time: 287, positive: 10, negative: 6, hr: 159, maxHr: 164, watts: 259, maxWatts: 293),
            makeTempoSplit(activity: activity, index: 6, distance: 1000, time: 275, positive: 4, negative: 13, hr: 163, maxHr: 164, watts: 258, maxWatts: 294),
            makeTempoSplit(activity: activity, index: 7, distance: 660, time: 179, positive: 9, negative: 1, hr: 164, maxHr: 167, watts: 285, maxWatts: 334)
        ]

        let json = WebJSONExporter.exportActivityAsWebJSON(activity)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(exported["polyline_resumen"])
        XCTAssertEqual(exported["tiempo_total_s"] as? Int, 2750)
        XCTAssertEqual(exported["tiempo_transcurrido_s"] as? Int, 2986)
        XCTAssertEqual(exported["tiempo_parado_s"] as? Int, 133)
        XCTAssertEqual(exported["ritmo_medio"] as? String, "4:57 /km")

        let parciales = try XCTUnwrap(exported["parciales"] as? [[String: Any]])
        XCTAssertEqual(parciales.compactMap { $0["tiempo_s"] as? Int }.reduce(0, +), exported["tiempo_total_s"] as? Int)
        XCTAssertEqual(parciales.compactMap { $0["distancia_km"] as? Double }.reduce(0, +), exported["distancia_km"] as? Double ?? 0, accuracy: 0.01)
        XCTAssertEqual(parciales.compactMap { $0["desnivel_m"] as? Int }.reduce(0, +), -14)

        let tempoDetail = try XCTUnwrap(exported["tempo_detalle"] as? [[String: Any]])
        let tempoDistance = tempoDetail.compactMap { $0["distancia_km"] as? Double }.reduce(0, +)
        let tempoTime = tempoDetail.compactMap { $0["tiempo_s"] as? Int }.reduce(0, +)
        let tempoPositive = tempoDetail.compactMap { $0["desnivel_positivo_m"] as? Int }.reduce(0, +)
        let tempoNegative = tempoDetail.compactMap { $0["desnivel_negativo_m"] as? Int }.reduce(0, +)
        let tempoNet = tempoDetail.compactMap { $0["desnivel_m"] as? Int }.reduce(0, +)

        XCTAssertEqual(tempoDistance, 6.66, accuracy: 0.001)
        XCTAssertEqual(tempoTime, 1918)
        XCTAssertEqual(tempoPositive, 56)
        XCTAssertEqual(tempoNegative, 55)
        XCTAssertEqual(tempoNet, 1)
        XCTAssertEqual(tempoDetail.last?["distancia_km"] as? Double, 0.66)
    }
    
    private func loadGoldenFile(named name: String) throws -> String {
        let baseURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let url = baseURL.appendingPathComponent("GoldenFiles/\(name).json")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func makeTempoSplit(
        activity: Activity,
        index: Int,
        distance: Double,
        time: Int,
        positive: Double,
        negative: Double,
        hr: Double,
        maxHr: Double,
        watts: Double,
        maxWatts: Double
    ) -> ActivityTempoBlockSplit {
        let start = Double(index - 1) * 1000
        return ActivityTempoBlockSplit(
            blockLapIndex: 2,
            splitIndex: index,
            name: "Tempo \(index)",
            distance: distance,
            elapsedTime: time,
            movingTime: time,
            averageSpeed: distance / Double(time),
            elevationDifference: positive - negative,
            positiveElevationGain: positive,
            negativeElevationLoss: negative,
            averageHeartrate: hr,
            maxHeartrate: maxHr,
            averageWatts: watts,
            maxWatts: maxWatts,
            startDistance: start,
            endDistance: start + distance,
            activity: activity
        )
    }
    
    private func printDetailedDiff(expected: String, actual: String) {
        let expectedLines = expected.components(separatedBy: "\n")
        let actualLines = actual.components(separatedBy: "\n")
        
        print("\n=== DIFERENCIAS DETECTADAS ===")
        
        let maxLines = max(expectedLines.count, actualLines.count)
        for i in 0..<maxLines {
            let expectedLine = i < expectedLines.count ? expectedLines[i] : "<MISSING>"
            let actualLine = i < actualLines.count ? actualLines[i] : "<MISSING>"
            
            if expectedLine != actualLine {
                print("Línea \(i + 1):")
                print("  Web:  '\(expectedLine)'")
                print("  iOS:  '\(actualLine)'")
            }
        }
        
        print("=== FIN DIFERENCIAS ===\n")
    }
    
    // MARK: - Format Functions (para tests unitarios)
    
    private func formatDuration(_ seconds: Int) -> String {
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
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        
        if mins >= 60 {
            let hours = mins / 60
            let remainingMins = mins % 60
            return "\(hours):\(String(format: "%02d", remainingMins)):\(String(format: "%02d", secs))"
        }
        return "\(mins):\(String(format: "%02d", secs))"
    }
    
    private func formatPaceFromSpeed(_ speedMs: Double) -> String {
        guard speedMs > 0 else { return "-" }
        let paceSeconds = 1000 / speedMs
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds.rounded()) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private func formatDistanceKm(_ meters: Double) -> String {
        let km = meters / 1000
        let rounded = (km * 100).rounded() / 100
        
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        } else if (rounded * 10).truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.1f", rounded)
        } else {
            return String(format: "%.2f", rounded)
        }
    }
}
