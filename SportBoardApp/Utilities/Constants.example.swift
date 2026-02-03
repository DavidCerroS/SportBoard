//
//  Constants.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation

enum ConstantsExample {
    enum Strava {
        // MARK: - Configurar con tus credenciales de Strava
        static let clientId = "<SET_ME>"
        static let clientSecret = "<SET_ME>"
        static let redirectUri = "<SET_ME>"
        
        // MARK: - API URLs
        static let authorizeURL = "https://www.strava.com/oauth/mobile/authorize"
        static let tokenURL = "https://www.strava.com/oauth/token"
        static let apiBaseURL = "https://www.strava.com/api/v3"
        
        // MARK: - Scopes
        static let scopes = "read,activity:read_all"
        
        // MARK: - Rate Limits
        static let requestsPerFifteenMinutes = 100
        static let requestsPerDay = 1000
    }
    
    enum Keychain {
        static let accessTokenKey = "strava_access_token"
        static let refreshTokenKey = "strava_refresh_token"
        static let expiresAtKey = "strava_expires_at"
        static let athleteIdKey = "strava_athlete_id"
    }
    
    enum Sync {
        static let activitiesPerPage = 100 // Mismo que la web para ser eficientes
        static let initialSyncWindowDays = 90
        static let maxRetries = 3
        static let initialRetryDelay: TimeInterval = 1.0
        static let requestDelayMs: UInt64 = 200_000_000 // 200ms entre requests (igual que la web)
    }
}
