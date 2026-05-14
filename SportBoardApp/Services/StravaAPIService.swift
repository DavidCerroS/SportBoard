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
    let workoutType: Int?
    let calories: Double?
    let gearId: String?
    let trainer: Bool?
    let manual: Bool?
    let isPrivate: Bool?
    let flagged: Bool?
    let elevHigh: Double?
    let elevLow: Double?
    let startLatlng: [Double]?
    let endLatlng: [Double]?
    let map: StravaMap?
    let achievementCount: Int?
    let kudosCount: Int?
    let commentCount: Int?
    let athleteCount: Int?
    let photoCount: Int?
    let weightedAverageWatts: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, distance, kilojoules, calories, trainer, manual, flagged, map
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
        case workoutType = "workout_type"
        case gearId = "gear_id"
        case isPrivate = "private"
        case elevHigh = "elev_high"
        case elevLow = "elev_low"
        case startLatlng = "start_latlng"
        case endLatlng = "end_latlng"
        case achievementCount = "achievement_count"
        case kudosCount = "kudos_count"
        case commentCount = "comment_count"
        case athleteCount = "athlete_count"
        case photoCount = "photo_count"
        case weightedAverageWatts = "weighted_average_watts"
    }
}

struct StravaMap: Codable, Sendable {
    let id: String?
    let polyline: String?
    let summaryPolyline: String?

    enum CodingKeys: String, CodingKey {
        case id, polyline
        case summaryPolyline = "summary_polyline"
    }
}

struct StravaActivityDetail: Codable, Sendable {
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
    let workoutType: Int?
    let calories: Double?
    let gearId: String?
    let trainer: Bool?
    let manual: Bool?
    let isPrivate: Bool?
    let flagged: Bool?
    let elevHigh: Double?
    let elevLow: Double?
    let startLatlng: [Double]?
    let endLatlng: [Double]?
    let map: StravaMap?
    let achievementCount: Int?
    let kudosCount: Int?
    let commentCount: Int?
    let athleteCount: Int?
    let photoCount: Int?
    let weightedAverageWatts: Double?
    let laps: [StravaLap]?
    let splitsMetric: [StravaSplit]?
    let segmentEfforts: [StravaSegmentEffort]?

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        sportType = try c.decode(String.self, forKey: .sportType)
        startDate = try c.decode(String.self, forKey: .startDate)
        startDateLocal = try c.decode(String.self, forKey: .startDateLocal)
        distance = try c.decode(Double.self, forKey: .distance)
        movingTime = try c.decode(Int.self, forKey: .movingTime)
        elapsedTime = try c.decode(Int.self, forKey: .elapsedTime)
        totalElevationGain = try c.decode(Double.self, forKey: .totalElevationGain)
        averageSpeed = try c.decode(Double.self, forKey: .averageSpeed)
        maxSpeed = try c.decode(Double.self, forKey: .maxSpeed)
        averageHeartrate = try c.decodeIfPresent(Double.self, forKey: .averageHeartrate)
        maxHeartrate = try c.decodeIfPresent(Double.self, forKey: .maxHeartrate)
        averageWatts = try c.decodeIfPresent(Double.self, forKey: .averageWatts)
        maxWatts = try c.decodeIfPresent(Double.self, forKey: .maxWatts)
        kilojoules = try c.decodeIfPresent(Double.self, forKey: .kilojoules)
        hasHeartrate = try c.decodeIfPresent(Bool.self, forKey: .hasHeartrate)
        deviceWatts = try c.decodeIfPresent(Bool.self, forKey: .deviceWatts)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        deviceName = try c.decodeIfPresent(String.self, forKey: .deviceName)
        workoutType = try c.decodeIfPresent(Int.self, forKey: .workoutType)
        calories = try c.decodeIfPresent(Double.self, forKey: .calories)
        gearId = try c.decodeIfPresent(String.self, forKey: .gearId)
        trainer = try c.decodeIfPresent(Bool.self, forKey: .trainer)
        manual = try c.decodeIfPresent(Bool.self, forKey: .manual)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate)
        flagged = try c.decodeIfPresent(Bool.self, forKey: .flagged)
        elevHigh = try c.decodeIfPresent(Double.self, forKey: .elevHigh)
        elevLow = try c.decodeIfPresent(Double.self, forKey: .elevLow)
        startLatlng = try c.decodeIfPresent([Double].self, forKey: .startLatlng)
        endLatlng = try c.decodeIfPresent([Double].self, forKey: .endLatlng)
        map = try c.decodeIfPresent(StravaMap.self, forKey: .map)
        achievementCount = try c.decodeIfPresent(Int.self, forKey: .achievementCount)
        kudosCount = try c.decodeIfPresent(Int.self, forKey: .kudosCount)
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount)
        athleteCount = try c.decodeIfPresent(Int.self, forKey: .athleteCount)
        photoCount = try c.decodeIfPresent(Int.self, forKey: .photoCount)
        weightedAverageWatts = try c.decodeIfPresent(Double.self, forKey: .weightedAverageWatts)
        laps = try c.decodeIfPresent([StravaLap].self, forKey: .laps)
        splitsMetric = try c.decodeIfPresent([StravaSplit].self, forKey: .splitsMetric)
        segmentEfforts = try c.decodeIfPresent([StravaSegmentEffort].self, forKey: .segmentEfforts)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, distance, kilojoules, description, calories, trainer, manual, flagged, map
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
        case workoutType = "workout_type"
        case gearId = "gear_id"
        case isPrivate = "private"
        case elevHigh = "elev_high"
        case elevLow = "elev_low"
        case startLatlng = "start_latlng"
        case endLatlng = "end_latlng"
        case achievementCount = "achievement_count"
        case kudosCount = "kudos_count"
        case commentCount = "comment_count"
        case athleteCount = "athlete_count"
        case photoCount = "photo_count"
        case weightedAverageWatts = "weighted_average_watts"
        case laps
        case splitsMetric = "splits_metric"
        case segmentEfforts = "segment_efforts"
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
    let averageCadence: Double?
    let paceZone: Int?
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
        case averageCadence = "average_cadence"
        case paceZone = "pace_zone"
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

struct StravaStreamSeries<T: Codable>: Codable {
    let data: [T]
}

struct StravaActivityStreamsResponse: Codable {
    let time: StravaStreamSeries<Int>?
    let distance: StravaStreamSeries<Double>?
    let altitude: StravaStreamSeries<Double>?
    let watts: StravaStreamSeries<Int>?
    let heartrate: StravaStreamSeries<Int>?
    let cadence: StravaStreamSeries<Int>?
    let velocitySmooth: StravaStreamSeries<Double>?
    let moving: StravaStreamSeries<Bool>?
    let gradeSmooth: StravaStreamSeries<Double>?
    let temp: StravaStreamSeries<Int>?

    enum CodingKeys: String, CodingKey {
        case time, distance, altitude, watts, heartrate, cadence, moving, temp
        case velocitySmooth = "velocity_smooth"
        case gradeSmooth = "grade_smooth"
    }
}

struct StravaActivityZone: Codable {
    let type: String
    let sensorBased: Bool
    let score: Int?
    let distributionBuckets: [StravaZoneBucket]

    enum CodingKeys: String, CodingKey {
        case type, score
        case sensorBased = "sensor_based"
        case distributionBuckets = "distribution_buckets"
    }
}

struct StravaZoneBucket: Codable {
    let min: Int
    let max: Int
    let time: Int
}

struct StravaDetailedGear: Codable {
    let id: String
    let name: String
    let brandName: String?
    let modelName: String?
    let distance: Double?
    let retired: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, distance, retired
        case brandName = "brand_name"
        case modelName = "model_name"
    }
}

struct StravaSummarySegment: Codable, Sendable {
    let id: Int64
    let name: String?
}

struct StravaSegmentEffort: Codable, Sendable {
    let id: Int64
    let name: String
    let segment: StravaSummarySegment?
    let distance: Double
    let elapsedTime: Int
    let movingTime: Int
    let startIndex: Int?
    let endIndex: Int?
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let averageWatts: Double?
    let prRank: Int?
    let komRank: Int?
    let isKom: Bool?
    let hidden: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, segment, distance, hidden
        case elapsedTime = "elapsed_time"
        case movingTime = "moving_time"
        case startIndex = "start_index"
        case endIndex = "end_index"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case averageWatts = "average_watts"
        case prRank = "pr_rank"
        case komRank = "kom_rank"
        case isKom = "is_kom"
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

// MARK: - Strava API (namespace no aislado)

enum StravaAPI {
    static let baseURL = "https://www.strava.com/api/v3"
}
// MARK: - Strava API Service

actor StravaAPIService {
    static let shared = StravaAPIService()
    
    private let baseURL = StravaAPI.baseURL
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
    func getActivityDetail(id: Int64, includeAllEfforts: Bool = false) async throws -> StravaActivityDetail {
        let queryItems = includeAllEfforts ? [URLQueryItem(name: "include_all_efforts", value: "true")] : []
        return try await request(endpoint: "/activities/\(id)", queryItems: queryItems)
    }
    
    /// Obtiene los laps de una actividad
    func getActivityLaps(id: Int64) async throws -> [StravaLap] {
        return try await request(endpoint: "/activities/\(id)/laps")
    }

    /// Obtiene streams para calcular métricas por parcial.
    func getActivityMetricStreams(id: Int64, includeWatts: Bool) async throws -> StravaActivityStreamsResponse {
        let baseKeys = "time,distance,altitude,heartrate,cadence,velocity_smooth,moving,grade_smooth,temp"
        let keys = includeWatts ? "\(baseKeys),watts" : baseKeys
        let queryItems = [
            URLQueryItem(name: "keys", value: keys),
            URLQueryItem(name: "key_by_type", value: "true")
        ]
        return try await request(endpoint: "/activities/\(id)/streams", queryItems: queryItems)
    }

    func getActivityZones(id: Int64) async throws -> [StravaActivityZone] {
        return try await request(endpoint: "/activities/\(id)/zones")
    }

    func getGear(id: String) async throws -> StravaDetailedGear {
        return try await request(endpoint: "/gear/\(id)")
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
        
        // Imprimir respuesta raw para depurar lo que devuelve Strava
        if endpoint.contains("/activities/") && !endpoint.contains("/laps") {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("\n========== STRAVA RAW JSON RESPONSE ==========")
                print("URL: \(url.absoluteString)")
                print("Endpoint: \(endpoint)")
                print("Status: \(httpResponse.statusCode)")
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
