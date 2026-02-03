//
//  PostActivityReflection.swift
//  SportBoardApp
//
//  Reflexión post-entreno: sensación, ¿forcé de más?, ¿repetiría hoy?
//  Uso: fatiga, clasificación, sugerencias.
//

import Foundation
import SwiftData

@Model
final class PostActivityReflection {
    /// ID de la actividad (Strava o local)
    var activityId: Int64
    /// Fecha de la reflexión (normalmente mismo día que la actividad)
    var date: Date
    /// Sensación 1–5 (1 = muy mal, 5 = muy bien)
    var feelingScore: Int
    /// ¿Forcé de más?
    var pushedTooHard: Bool
    /// ¿Repetiría este entreno hoy?
    var wouldRepeatToday: Bool
    
    init(
        activityId: Int64,
        date: Date = Date(),
        feelingScore: Int = 3,
        pushedTooHard: Bool = false,
        wouldRepeatToday: Bool = true
    ) {
        self.activityId = activityId
        self.date = date
        self.feelingScore = min(5, max(1, feelingScore))
        self.pushedTooHard = pushedTooHard
        self.wouldRepeatToday = wouldRepeatToday
    }
}
