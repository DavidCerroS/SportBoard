//
//  StravaEnrichmentModels.swift
//  SportBoardApp
//
//  Datos enriquecidos de Strava cargados bajo demanda.
//

import Foundation
import SwiftData

@Model
final class ActivityZoneDistribution {
    var zoneType: String
    var sensorBased: Bool
    var score: Int?
    var distributionJSON: String

    var activity: Activity?

    init(
        zoneType: String,
        sensorBased: Bool,
        score: Int? = nil,
        distributionJSON: String,
        activity: Activity? = nil
    ) {
        self.zoneType = zoneType
        self.sensorBased = sensorBased
        self.score = score
        self.distributionJSON = distributionJSON
        self.activity = activity
    }
}

@Model
final class ActivityStreamSummary {
    var averageCadence: Double?
    var maxCadence: Double?
    var averageGrade: Double?
    var maxGrade: Double?
    var minGrade: Double?
    var movingRatio: Double?
    var stoppedTimeSeconds: Int?
    var averageMovingPaceSecondsPerKm: Int?
    var cardiacDriftPercent: Double?
    var averageTemperature: Double?

    var activity: Activity?

    init(
        averageCadence: Double? = nil,
        maxCadence: Double? = nil,
        averageGrade: Double? = nil,
        maxGrade: Double? = nil,
        minGrade: Double? = nil,
        movingRatio: Double? = nil,
        stoppedTimeSeconds: Int? = nil,
        averageMovingPaceSecondsPerKm: Int? = nil,
        cardiacDriftPercent: Double? = nil,
        averageTemperature: Double? = nil,
        activity: Activity? = nil
    ) {
        self.averageCadence = averageCadence
        self.maxCadence = maxCadence
        self.averageGrade = averageGrade
        self.maxGrade = maxGrade
        self.minGrade = minGrade
        self.movingRatio = movingRatio
        self.stoppedTimeSeconds = stoppedTimeSeconds
        self.averageMovingPaceSecondsPerKm = averageMovingPaceSecondsPerKm
        self.cardiacDriftPercent = cardiacDriftPercent
        self.averageTemperature = averageTemperature
        self.activity = activity
    }
}

@Model
final class StravaGear {
    @Attribute(.unique) var id: String
    var name: String
    var brandName: String?
    var modelName: String?
    var distanceMeters: Double?
    var retired: Bool
    var syncedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Activity.gear)
    var activities: [Activity]?

    init(
        id: String,
        name: String,
        brandName: String? = nil,
        modelName: String? = nil,
        distanceMeters: Double? = nil,
        retired: Bool = false,
        syncedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brandName = brandName
        self.modelName = modelName
        self.distanceMeters = distanceMeters
        self.retired = retired
        self.syncedAt = syncedAt
    }
}

@Model
final class ActivitySegmentEffort {
    @Attribute(.unique) var id: Int64
    var name: String
    var segmentId: Int64?
    var distance: Double
    var elapsedTime: Int
    var movingTime: Int
    var startIndex: Int?
    var endIndex: Int?
    var averageHeartrate: Double?
    var maxHeartrate: Double?
    var averageWatts: Double?
    var prRank: Int?
    var komRank: Int?
    var isKom: Bool
    var hidden: Bool

    var activity: Activity?

    init(
        id: Int64,
        name: String,
        segmentId: Int64? = nil,
        distance: Double,
        elapsedTime: Int,
        movingTime: Int,
        startIndex: Int? = nil,
        endIndex: Int? = nil,
        averageHeartrate: Double? = nil,
        maxHeartrate: Double? = nil,
        averageWatts: Double? = nil,
        prRank: Int? = nil,
        komRank: Int? = nil,
        isKom: Bool = false,
        hidden: Bool = false,
        activity: Activity? = nil
    ) {
        self.id = id
        self.name = name
        self.segmentId = segmentId
        self.distance = distance
        self.elapsedTime = elapsedTime
        self.movingTime = movingTime
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.averageHeartrate = averageHeartrate
        self.maxHeartrate = maxHeartrate
        self.averageWatts = averageWatts
        self.prRank = prRank
        self.komRank = komRank
        self.isKom = isKom
        self.hidden = hidden
        self.activity = activity
    }
}

@Model
final class ActivityTempoBlockSplit {
    var blockLapIndex: Int
    var splitIndex: Int
    var name: String
    var distance: Double
    var elapsedTime: Int
    var movingTime: Int
    var averageSpeed: Double
    var elevationDifference: Double
    var positiveElevationGain: Double
    var negativeElevationLoss: Double
    var averageHeartrate: Double?
    var maxHeartrate: Double?
    var averageWatts: Double?
    var maxWatts: Double?
    var averageCadence: Double?
    var averageGrade: Double?
    var startDistance: Double
    var endDistance: Double

    var activity: Activity?

    init(
        blockLapIndex: Int,
        splitIndex: Int,
        name: String,
        distance: Double,
        elapsedTime: Int,
        movingTime: Int,
        averageSpeed: Double,
        elevationDifference: Double,
        positiveElevationGain: Double,
        negativeElevationLoss: Double,
        averageHeartrate: Double? = nil,
        maxHeartrate: Double? = nil,
        averageWatts: Double? = nil,
        maxWatts: Double? = nil,
        averageCadence: Double? = nil,
        averageGrade: Double? = nil,
        startDistance: Double,
        endDistance: Double,
        activity: Activity? = nil
    ) {
        self.blockLapIndex = blockLapIndex
        self.splitIndex = splitIndex
        self.name = name
        self.distance = distance
        self.elapsedTime = elapsedTime
        self.movingTime = movingTime
        self.averageSpeed = averageSpeed
        self.elevationDifference = elevationDifference
        self.positiveElevationGain = positiveElevationGain
        self.negativeElevationLoss = negativeElevationLoss
        self.averageHeartrate = averageHeartrate
        self.maxHeartrate = maxHeartrate
        self.averageWatts = averageWatts
        self.maxWatts = maxWatts
        self.averageCadence = averageCadence
        self.averageGrade = averageGrade
        self.startDistance = startDistance
        self.endDistance = endDistance
        self.activity = activity
    }
}

extension ActivityTempoBlockSplit {
    var formattedKm: String {
        splitIndex == 0 ? "Tempo" : "T\(splitIndex)"
    }

    var formattedTime: String {
        TimeInterval(elapsedTime).formattedDuration
    }

    var formattedPace: String {
        averageSpeed.paceMinPerKm
    }

    var formattedHeartrate: String {
        guard let averageHeartrate else { return "--" }
        return "\(Int(averageHeartrate.rounded()))"
    }

    var formattedAveragePower: String {
        guard let averageWatts else { return "--" }
        return "\(Int(averageWatts.rounded()))W"
    }

    var formattedMaxPower: String {
        guard let maxWatts else { return "--" }
        return "\(Int(maxWatts.rounded()))W"
    }

    var formattedElevation: String {
        let sign = elevationDifference >= 0 ? "+" : ""
        return "\(sign)\(Int(elevationDifference.rounded()))m"
    }
}
