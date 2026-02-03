//
//  Extensions.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftUI

// MARK: - Calendar (Europe/Madrid, Lunes como primer día)

private var _madridCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Madrid")!
    cal.locale = Locale(identifier: "es_ES")
    cal.firstWeekday = 2 // Lunes
    return cal
}()

extension Calendar {
    /// Calendario para agrupar por semana en España: Europe/Madrid, es_ES, firstWeekday = 2 (Lunes).
    static var sportBoardMadrid: Calendar { _madridCalendar }
}

extension Date {
    func startOfWeek(using calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func startOfNextWeek(using calendar: Calendar) -> Date {
        let start = startOfWeek(using: calendar)
        return calendar.date(byAdding: .day, value: 7, to: start) ?? start
    }
    
    func startOfMonth(using calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var startOfWeek: Date {
        startOfWeek(using: Calendar.current)
    }
    
    /// Inicio de la semana (Lunes 00:00) en Europe/Madrid. Usar para "esta semana" y consistencia.
    var startOfWeekMadrid: Date {
        startOfWeek(using: Calendar.sportBoardMadrid)
    }
    
    /// Inicio de la semana siguiente en Europe/Madrid. Rango de esta semana: [startOfWeekMadrid, startOfNextWeekMadrid).
    var startOfNextWeekMadrid: Date {
        startOfNextWeek(using: Calendar.sportBoardMadrid)
    }
    
    var startOfMonth: Date {
        startOfMonth(using: Calendar.current)
    }
    
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }
    
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
    
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: self)
    }
    
    var fullDateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: self)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedHoursMinutes: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Double Extensions

extension Double {
    var formattedDistance: String {
        if self >= 1000 {
            return String(format: "%.2f km", self / 1000)
        } else {
            return String(format: "%.0f m", self)
        }
    }
    
    var formattedDistanceKm: String {
        String(format: "%.2f km", self / 1000)
    }
    
    var formattedElevation: String {
        String(format: "%.0f m", self)
    }
    
    var formattedHeartRate: String {
        String(format: "%.0f bpm", self)
    }
    
    var formattedPower: String {
        String(format: "%.0f W", self)
    }
    
    /// Convierte m/s a min/km (ritmo)
    var paceMinPerKm: String {
        guard self > 0 else { return "--:--" }
        let secPerKm = 1000 / self
        let minutes = Int(secPerKm) / 60
        let seconds = Int(secPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Convierte m/s a km/h
    var speedKmh: String {
        String(format: "%.1f km/h", self * 3.6)
    }
}

// MARK: - Int Extensions

extension Int {
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Color Extensions

extension Color {
    static let stravaOrange = Color(red: 252/255, green: 82/255, blue: 0/255)
    
    static func sportColor(for sportType: String) -> Color {
        switch sportType.lowercased() {
        case "run", "virtualrun", "trailrun":
            return .orange
        case "ride", "virtualride", "mountainbikeride", "gravelride", "ebikeride":
            return .blue
        case "swim":
            return .cyan
        case "walk", "hike":
            return .green
        case "workout", "weighttraining", "crossfit":
            return .purple
        case "yoga", "pilates":
            return .pink
        default:
            return .gray
        }
    }
}

// MARK: - Sport Type Helpers

extension String {
    var sportIcon: String {
        switch self.lowercased() {
        case "run", "virtualrun":
            return "figure.run"
        case "trailrun":
            return "figure.hiking"
        case "ride", "virtualride":
            return "bicycle"
        case "mountainbikeride":
            return "figure.outdoor.cycle"
        case "gravelride":
            return "bicycle"
        case "ebikeride":
            return "bicycle"
        case "swim":
            return "figure.pool.swim"
        case "walk":
            return "figure.walk"
        case "hike":
            return "figure.hiking"
        case "workout", "weighttraining":
            return "dumbbell.fill"
        case "crossfit":
            return "figure.cross.training"
        case "yoga":
            return "figure.mind.and.body"
        case "pilates":
            return "figure.pilates"
        case "rowing", "indoorrowing":
            return "figure.rower"
        case "elliptical":
            return "figure.elliptical"
        case "stairstepper":
            return "figure.stairs"
        default:
            return "sportscourt"
        }
    }
    
    var sportDisplayName: String {
        switch self.lowercased() {
        case "run": return "Carrera"
        case "virtualrun": return "Carrera Virtual"
        case "trailrun": return "Trail Running"
        case "ride": return "Ciclismo"
        case "virtualride": return "Ciclismo Virtual"
        case "mountainbikeride": return "MTB"
        case "gravelride": return "Gravel"
        case "ebikeride": return "E-Bike"
        case "swim": return "Natación"
        case "walk": return "Caminata"
        case "hike": return "Senderismo"
        case "workout": return "Entrenamiento"
        case "weighttraining": return "Pesas"
        case "crossfit": return "CrossFit"
        case "yoga": return "Yoga"
        case "pilates": return "Pilates"
        case "rowing": return "Remo"
        case "indoorrowing": return "Remo Indoor"
        case "elliptical": return "Elíptica"
        case "stairstepper": return "Escaladora"
        default: return self
        }
    }
    
    /// Indica si este deporte usa ritmo (min/km) en lugar de velocidad (km/h)
    var usesPace: Bool {
        let paceTypes = ["run", "virtualrun", "trailrun", "walk", "hike"]
        return paceTypes.contains(self.lowercased())
    }
}
