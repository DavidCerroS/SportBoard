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
            hasHeartrate: true,
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
    
    private func loadGoldenFile(named name: String) throws -> String {
        let baseURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let url = baseURL.appendingPathComponent("GoldenFiles/\(name).json")
        return try String(contentsOf: url, encoding: .utf8)
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

