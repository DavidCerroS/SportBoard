//
//  RunnerProfile.swift
//  SportBoardApp
//
//  Perfil de corredor calculado por la app (ritmo cómodo, umbral, variabilidad, ratio fácil/duro).
//  Base de toda la interpretación posterior. No introducido a mano.
//

import Foundation
import SwiftData

@Model
final class RunnerProfile {
    /// Ritmo cómodo (rodaje fácil) en m/s
    var easyPaceMs: Double
    /// Ritmo umbral estimado en m/s
    var thresholdPaceMs: Double
    /// Variabilidad semanal tolerable (ej. coeficiente de variación de volumen semanal)
    var weeklyVariability: Double
    /// Ratio natural fácil/duro (proporción de tiempo en Z1–Z2 vs total)
    var easyHardRatio: Double
    /// Nivel de confianza del perfil (0...1)
    var confidence: Double
    /// Última vez que se recalcularon los valores
    var lastComputedAt: Date
    /// Deporte al que aplica (ej. Run)
    var sportType: String
    
    init(
        easyPaceMs: Double = 0,
        thresholdPaceMs: Double = 0,
        weeklyVariability: Double = 0,
        easyHardRatio: Double = 0,
        confidence: Double = 0,
        lastComputedAt: Date = Date(),
        sportType: String = "Run"
    ) {
        self.easyPaceMs = easyPaceMs
        self.thresholdPaceMs = thresholdPaceMs
        self.weeklyVariability = weeklyVariability
        self.easyHardRatio = easyHardRatio
        self.confidence = confidence
        self.lastComputedAt = lastComputedAt
        self.sportType = sportType
    }
}

// MARK: - Computed helpers

extension RunnerProfile {
    /// Ritmo cómodo en segundos por km (para mostrar)
    var easyPaceSecPerKm: Int? {
        guard easyPaceMs > 0 else { return nil }
        return Int((1000 / easyPaceMs).rounded())
    }
    
    /// Ritmo umbral en segundos por km
    var thresholdPaceSecPerKm: Int? {
        guard thresholdPaceMs > 0 else { return nil }
        return Int((1000 / thresholdPaceMs).rounded())
    }
    
    /// Si el perfil tiene datos útiles (ritmo fácil y umbral)
    var isValid: Bool {
        easyPaceMs > 0 && thresholdPaceMs > 0 && confidence >= 0.3
    }
}
