//
//  StravaAPIService.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation

// MARK: - Strava API Errors

enum StravaAPIError: Error {
    case invalidURL
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case serverError(statusCode: Int)
    case decodingError(Error)
    case unknown
}

// MARK: - API Response Models

struct StravaActivitySummary: Codable {
    let id: Int64
    let name: String
    let sportType: String
    let startDate: String
    let startDateLocal: String // Fecha en zona horaria local del usuario
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let totalElevationGain: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let averageWatts: Double?
    let maxWatts: Double?
    let kilojoules: Double?
    let hasHeartrate: Bool?
    let deviceWatts: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, distance, kilojoules
        case sportType = "sport_type"
        case startDate = "start_date"
        case startDateLocal = "start_date_local"
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case averageWatts = "average_watts"
        case maxWatts = "max_watts"
        case hasHeartrate = "has_heartrate"
        case deviceWatts = "device_watts"
    }
}

struct StravaActivityDetail: Codable {
    let id: Int64
    let name: String
    let sportType: String
    let startDate: String
    let startDateLocal: String // Fecha en zona horaria local del usuario
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let totalElevationGain: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let averageWatts: Double?
    let maxWatts: Double?
    let kilojoules: Double?
    let hasHeartrate: Bool?
    let deviceWatts: Bool?
    let description: String?
    let deviceName: String?
    let laps: [StravaLap]?
    let splitsMetric: [StravaSplit]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, distance, kilojoules, description
        case sportType = "sport_type"
        case startDate = "start_date"
        case startDateLocal = "start_date_local"
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case averageWatts = "average_watts"
        case maxWatts = "max_watts"
        case hasHeartrate = "has_heartrate"
        case deviceWatts = "device_watts"
        case deviceName = "device_name"
        case laps
        case splitsMetric = "splits_metric"
    }
}

struct StravaLap: Codable {
    let id: Int64
    let name: String?
    let lapIndex: Int
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let startIndex: Int
    let endIndex: Int
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let averageWatts: Double?
    let totalElevationGain: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, distance
        case lapIndex = "lap_index"
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case startIndex = "start_index"
        case endIndex = "end_index"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case averageWatts = "average_watts"
        case totalElevationGain = "total_elevation_gain"
    }
}

struct StravaSplit: Codable {
    let split: Int
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let averageSpeed: Double
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let averageWatts: Double?
    let elevationDifference: Double
    let paceZone: Int?
    
    enum CodingKeys: String, CodingKey {
        case split, distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case averageSpeed = "average_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case averageWatts = "average_watts"
        case elevationDifference = "elevation_difference"
        case paceZone = "pace_zone"
    }
}

// MARK: - Rate Limit Info

struct RateLimitInfo {
    let limitFifteenMinutes: Int
    let limitDaily: Int
    let usageFifteenMinutes: Int
    let usageDaily: Int
}

// MARK: - Athlete Stats Response

struct AthleteStatsResponse: Codable {
    let allRunTotals: ActivityTotals?
    let allRideTotals: ActivityTotals?
    let allSwimTotals: ActivityTotals?
    let recentRunTotals: ActivityTotals?
    let recentRideTotals: ActivityTotals?
    let recentSwimTotals: ActivityTotals?
    let ytdRunTotals: ActivityTotals?
    let ytdRideTotals: ActivityTotals?
    let ytdSwimTotals: ActivityTotals?
    
    enum CodingKeys: String, CodingKey {
        case allRunTotals = "all_run_totals"
        case allRideTotals = "all_ride_totals"
        case allSwimTotals = "all_swim_totals"
        case recentRunTotals = "recent_run_totals"
        case recentRideTotals = "recent_ride_totals"
        case recentSwimTotals = "recent_swim_totals"
        case ytdRunTotals = "ytd_run_totals"
        case ytdRideTotals = "ytd_ride_totals"
        case ytdSwimTotals = "ytd_swim_totals"
    }
}

struct ActivityTotals: Codable {
    let count: Int?
    let distance: Double?
    let movingTime: Int?
    let elapsedTime: Int?
    let elevationGain: Double?
    
    enum CodingKeys: String, CodingKey {
        case count, distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case elevationGain = "elevation_gain"
    }
}

// MARK: - Athlete Response

struct AthleteResponse: Codable {
    let id: Int64
    let username: String?
    let firstName: String?
    let lastName: String?
    let profile: String?
    let profileMedium: String?
    let city: String?
    let state: String?
    let country: String?
    let sex: String?
    let weight: Double?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, username, city, state, country, sex, weight
        case firstName = "firstname"
        case lastName = "lastname"
        case profile = "profile"
        case profileMedium = "profile_medium"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Strava API Service

actor StravaAPIService {
    static let shared = StravaAPIService()
    
    private let baseURL = Constants.Strava.apiBaseURL
    private var rateLimitInfo: RateLimitInfo?
    
    private init() {}
    
    /// Devuelve la última información de rate limit conocida a partir de las respuestas HTTP
    func getRateLimitInfo() async -> RateLimitInfo? {
        return rateLimitInfo
    }
    
    // MARK: - Public Methods
    
    /// Obtiene las actividades del atleta con paginación
    func getActivities(page: Int = 1, perPage: Int = 30, after: Date? = nil, before: Date? = nil) async throws -> [StravaActivitySummary] {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: "\(Int(after.timeIntervalSince1970))"))
        }
        
        if let before = before {
            queryItems.append(URLQueryItem(name: "before", value: "\(Int(before.timeIntervalSince1970))"))
        }
        
        return try await request(endpoint: "/athlete/activities", queryItems: queryItems)
    }
    
    /// Obtiene los detalles completos de una actividad
    func getActivityDetail(id: Int64) async throws -> StravaActivityDetail {
        return try await request(endpoint: "/activities/\(id)")
    }
    
    /// Obtiene los laps de una actividad
    func getActivityLaps(id: Int64) async throws -> [StravaLap] {
        return try await request(endpoint: "/activities/\(id)/laps")
    }
    
    // MARK: - Private Methods
    
    private func request<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET"
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: baseURL + endpoint) else {
            throw StravaAPIError.invalidURL
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw StravaAPIError.invalidURL
        }
        
        // AuthService está aislado al MainActor, así que podemos llamarlo directamente
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaAPIError.unknown
        }
        
        // Actualizar info de rate limits
        updateRateLimits(from: httpResponse)
        
        // Manejar errores HTTP
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw StravaAPIError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw StravaAPIError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw StravaAPIError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw StravaAPIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Imprimir respuesta raw para getActivityDetail
        if endpoint.contains("/activities/") && !endpoint.contains("/laps") {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("\n========== STRAVA RAW JSON RESPONSE ==========")
                print("Endpoint: \(endpoint)")
                print("Response JSON:")
                // Intentar formatear el JSON para mejor legibilidad
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print(prettyString)
                } else {
                    print(jsonString)
                }
                print("========== END STRAVA RAW JSON ==========\n")
            }
        }
        
        // Decodificar en contexto no aislado para evitar problemas de actor isolation en Swift 6
        return try await Task.detached {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        }.value
    }
    
    private func updateRateLimits(from response: HTTPURLResponse) {
        // Headers de Strava: X-RateLimit-Limit, X-RateLimit-Usage
        // Formato: "100,1000" (15min, diario)
        guard let limitHeader = response.value(forHTTPHeaderField: "X-RateLimit-Limit"),
              let usageHeader = response.value(forHTTPHeaderField: "X-RateLimit-Usage") else {
            return
        }
        
        let limits = limitHeader.split(separator: ",").compactMap { Int($0) }
        let usages = usageHeader.split(separator: ",").compactMap { Int($0) }
        
        guard limits.count >= 2, usages.count >= 2 else { return }
        
        rateLimitInfo = RateLimitInfo(
            limitFifteenMinutes: limits[0],
            limitDaily: limits[1],
            usageFifteenMinutes: usages[0],
            usageDaily: usages[1]
        )
    }
}

