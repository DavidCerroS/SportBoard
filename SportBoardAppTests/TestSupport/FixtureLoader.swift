//
//  FixtureLoader.swift
//  SportBoardAppTests
//
//  Created by Codex on 10/3/25.
//

import Foundation
@testable import SportBoardApp

struct ActivityFixture: Decodable {
    let activity: ActivityPayload
    let splits: [SplitPayload]?
    let laps: [LapPayload]?
}

struct ActivityPayload: Decodable {
    let id: Int64
    let name: String
    let sportType: String
    let startDate: String
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let totalElevationGain: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let hasHeartrate: Bool
    let hasSplitsMetric: Bool
    let hasLaps: Bool
}

struct SplitPayload: Decodable {
    let splitIndex: Int
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let averageSpeed: Double
    let averageHeartrate: Double?
    let elevationDifference: Double
    let paceZone: Int?
}

struct LapPayload: Decodable {
    let lapIndex: Int
    let name: String?
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let startIndex: Int
    let endIndex: Int
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartrate: Double?
    let totalElevationGain: Double
}

enum FixtureLoader {
    static func load(named name: String) throws -> ActivityFixture {
        let url = try fixtureURL(named: name)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ActivityFixture.self, from: data)
    }
    
    static func makeActivity(from fixture: ActivityFixture) -> Activity {
        let startDate = parseDate(fixture.activity.startDate)
        let payload = fixture.activity
        let activity = Activity(
            id: payload.id,
            name: payload.name,
            sportType: payload.sportType,
            startDate: startDate,
            distance: payload.distance,
            movingTime: payload.movingTime,
            elapsedTime: payload.elapsedTime,
            totalElevationGain: payload.totalElevationGain,
            averageSpeed: payload.averageSpeed,
            maxSpeed: payload.maxSpeed,
            averageHeartrate: payload.averageHeartrate,
            maxHeartrate: payload.maxHeartrate,
            hasHeartrate: payload.hasHeartrate,
            hasLaps: payload.hasLaps,
            hasSplitsMetric: payload.hasSplitsMetric
        )
        
        if let splits = fixture.splits {
            let models = splits.map {
                ActivitySplit(
                    splitIndex: $0.splitIndex,
                    distance: $0.distance,
                    movingTime: $0.movingTime,
                    elapsedTime: $0.elapsedTime,
                    averageSpeed: $0.averageSpeed,
                    averageHeartrate: $0.averageHeartrate,
                    elevationDifference: $0.elevationDifference,
                    paceZone: $0.paceZone,
                    activity: activity
                )
            }
            activity.splitsMetric = models
        }
        
        if let laps = fixture.laps {
            let models = laps.map {
                ActivityLap(
                    lapIndex: $0.lapIndex,
                    name: $0.name,
                    distance: $0.distance,
                    movingTime: $0.movingTime,
                    elapsedTime: $0.elapsedTime,
                    startIndex: $0.startIndex,
                    endIndex: $0.endIndex,
                    averageSpeed: $0.averageSpeed,
                    maxSpeed: $0.maxSpeed,
                    averageHeartrate: $0.averageHeartrate,
                    totalElevationGain: $0.totalElevationGain,
                    activity: activity
                )
            }
            activity.laps = models
        }
        
        return activity
    }
    
    static func makeMadridCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        calendar.locale = Locale(identifier: "es_ES")
        calendar.firstWeekday = 2
        return calendar
    }
    
    static func dateInMadrid(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int = 0
    ) -> Date {
        let calendar = makeMadridCalendar()
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }
    
    private static func fixtureURL(named name: String) throws -> URL {
        let baseURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return baseURL.appendingPathComponent("Fixtures/\(name).json")
    }
    
    private static func parseDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}
