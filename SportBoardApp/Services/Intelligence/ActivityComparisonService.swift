//
//  ActivityComparisonService.swift
//  SportBoardApp
//
//  Compara dos entrenos de carrera por volumen, rendimiento, esfuerzo y parciales.
//

import Foundation

enum ActivityComparisonTrend: Equatable {
    case better
    case worse
    case neutral
}

enum ActivityComparisonSegmentSource: String, Equatable {
    case laps
    case splits
    case none

    var title: String {
        switch self {
        case .laps: return "Parciales"
        case .splits: return "Kilómetros"
        case .none: return "Sin parciales"
        }
    }
}

struct ActivityComparisonMetric: Identifiable {
    let id: String
    let title: String
    let firstValue: String
    let secondValue: String
    let differenceValue: String
    let detail: String?
    let trend: ActivityComparisonTrend
    let rawDifference: Double?
}

struct ActivityComparisonSegment: Identifiable {
    let id: Int
    let title: String
    let firstTime: String
    let secondTime: String
    let timeDifference: String
    let firstPace: String
    let secondPace: String
    let paceDifference: String
    let firstHeartRate: String
    let secondHeartRate: String
    let firstPower: String
    let secondPower: String
    let firstElevation: String
    let secondElevation: String
    let trend: ActivityComparisonTrend
    let rawPaceDifference: Double?
}

struct ActivityComparison {
    let firstSessionType: RunSessionType
    let secondSessionType: RunSessionType
    let warnings: [String]
    let insights: [String]
    let metrics: [ActivityComparisonMetric]
    let segmentSource: ActivityComparisonSegmentSource
    let segments: [ActivityComparisonSegment]
}

struct ActivityComparisonService {
    private static let runSportTypes = ["run", "virtualrun", "trailrun"]

    static func isRun(_ activity: Activity) -> Bool {
        runSportTypes.contains(activity.sportType.lowercased())
    }

    static func sortedComparableActivities(from activities: [Activity]) -> [Activity] {
        activities
            .filter(isRun)
            .sorted { $0.startDate > $1.startDate }
    }

    static func compare(_ first: Activity, _ second: Activity) -> ActivityComparison {
        let firstType = RunClassifier.classify(
            activity: first,
            splits: first.sortedSplits,
            laps: first.sortedLaps
        ).type
        let secondType = RunClassifier.classify(
            activity: second,
            splits: second.sortedSplits,
            laps: second.sortedLaps
        ).type

        let metrics = buildMetrics(first: first, second: second)
        let segmentResult = buildSegments(first: first, second: second)
        let warnings = buildWarnings(first: first, second: second, firstType: firstType, secondType: secondType)
        let insights = buildInsights(first: first, second: second, metrics: metrics, segmentCount: segmentResult.segments.count)

        return ActivityComparison(
            firstSessionType: firstType,
            secondSessionType: secondType,
            warnings: warnings,
            insights: insights,
            metrics: metrics,
            segmentSource: segmentResult.source,
            segments: segmentResult.segments
        )
    }

    static func paceSecondsPerKm(for activity: Activity) -> Double? {
        guard activity.averageSpeed > 0 else { return nil }
        return 1000 / activity.averageSpeed
    }

    private static func buildMetrics(first: Activity, second: Activity) -> [ActivityComparisonMetric] {
        var metrics: [ActivityComparisonMetric] = [
            numericMetric(
                id: "distance",
                title: "Distancia",
                first: first.distance,
                second: second.distance,
                formatter: formatDistance,
                differenceFormatter: formatDistanceDifference,
                lowerIsBetter: false
            ),
            numericMetric(
                id: "movingTime",
                title: "Tiempo en movimiento",
                first: Double(first.movingTime),
                second: Double(second.movingTime),
                formatter: { formatDuration(Int($0.rounded())) },
                differenceFormatter: { formatDurationDifference(Int($0.rounded())) },
                lowerIsBetter: true
            ),
            numericMetric(
                id: "elapsedTime",
                title: "Tiempo total",
                first: Double(first.elapsedTime),
                second: Double(second.elapsedTime),
                formatter: { formatDuration(Int($0.rounded())) },
                differenceFormatter: { formatDurationDifference(Int($0.rounded())) },
                lowerIsBetter: true
            ),
            optionalMetric(
                id: "averagePace",
                title: "Ritmo medio",
                first: paceSecondsPerKm(for: first),
                second: paceSecondsPerKm(for: second),
                formatter: formatPace,
                differenceFormatter: formatPaceDifference,
                lowerIsBetter: true
            ),
            numericMetric(
                id: "maxSpeed",
                title: "Velocidad máxima",
                first: first.maxSpeed,
                second: second.maxSpeed,
                formatter: formatSpeed,
                differenceFormatter: formatSpeedDifference,
                lowerIsBetter: false
            ),
            numericMetric(
                id: "elevation",
                title: "Desnivel positivo",
                first: first.totalElevationGain,
                second: second.totalElevationGain,
                formatter: formatElevation,
                differenceFormatter: formatElevationDifference,
                lowerIsBetter: false,
                trend: .neutral
            ),
            numericMetric(
                id: "elevationPerKm",
                title: "Desnivel por km",
                first: metersPerKm(elevation: first.totalElevationGain, distance: first.distance),
                second: metersPerKm(elevation: second.totalElevationGain, distance: second.distance),
                formatter: { String(format: "%.1f m/km", $0) },
                differenceFormatter: { signed(String(format: "%.1f m/km", abs($0)), value: $0) },
                lowerIsBetter: false,
                trend: .neutral
            )
        ]

        metrics.append(optionalMetric(
            id: "averageHeartRate",
            title: "FC media",
            first: first.averageHeartrate,
            second: second.averageHeartrate,
            formatter: { String(format: "%.0f bpm", $0) },
            differenceFormatter: { signed(String(format: "%.0f bpm", abs($0)), value: $0) },
            lowerIsBetter: true,
            trend: .neutral
        ))
        metrics.append(optionalMetric(
            id: "maxHeartRate",
            title: "FC máxima",
            first: first.maxHeartrate,
            second: second.maxHeartrate,
            formatter: { String(format: "%.0f bpm", $0) },
            differenceFormatter: { signed(String(format: "%.0f bpm", abs($0)), value: $0) },
            lowerIsBetter: true,
            trend: .neutral
        ))
        metrics.append(optionalMetric(
            id: "averagePower",
            title: "Potencia media",
            first: first.averageWatts,
            second: second.averageWatts,
            formatter: { String(format: "%.0f W", $0) },
            differenceFormatter: { signed(String(format: "%.0f W", abs($0)), value: $0) },
            lowerIsBetter: false,
            trend: .neutral
        ))
        metrics.append(optionalMetric(
            id: "maxPower",
            title: "Potencia máxima",
            first: first.maxWatts,
            second: second.maxWatts,
            formatter: { String(format: "%.0f W", $0) },
            differenceFormatter: { signed(String(format: "%.0f W", abs($0)), value: $0) },
            lowerIsBetter: false,
            trend: .neutral
        ))
        metrics.append(optionalMetric(
            id: "kilojoules",
            title: "Kilojulios",
            first: first.kilojoules,
            second: second.kilojoules,
            formatter: { String(format: "%.0f kJ", $0) },
            differenceFormatter: { signed(String(format: "%.0f kJ", abs($0)), value: $0) },
            lowerIsBetter: false,
            trend: .neutral
        ))
        metrics.append(optionalMetric(
            id: "pacePerHeartRate",
            title: "Eficiencia ritmo/FC",
            first: efficiencyPacePerHeartRate(first),
            second: efficiencyPacePerHeartRate(second),
            formatter: { String(format: "%.2f s/km/bpm", $0) },
            differenceFormatter: { signed(String(format: "%.2f", abs($0)), value: $0) },
            lowerIsBetter: true
        ))
        metrics.append(optionalMetric(
            id: "pacePerWatt",
            title: "Eficiencia ritmo/potencia",
            first: efficiencyPacePerWatt(first),
            second: efficiencyPacePerWatt(second),
            formatter: { String(format: "%.2f s/km/W", $0) },
            differenceFormatter: { signed(String(format: "%.2f", abs($0)), value: $0) },
            lowerIsBetter: true
        ))

        return metrics
    }

    private static func buildWarnings(
        first: Activity,
        second: Activity,
        firstType: RunSessionType,
        secondType: RunSessionType
    ) -> [String] {
        var warnings: [String] = []

        if first.id == second.id {
            warnings.append("Elige dos entrenos distintos para comparar.")
        }
        if firstType != .unknown && secondType != .unknown && firstType != secondType {
            warnings.append("Los entrenos parecen de tipo distinto: \(firstType.displayName) vs \(secondType.displayName).")
        }
        if relativeDifference(first.distance, second.distance) >= 0.25 {
            warnings.append("La distancia difiere más de un 25%; compara ritmos y esfuerzo con cautela.")
        }
        if relativeDifference(Double(first.movingTime), Double(second.movingTime)) >= 0.25 {
            warnings.append("La duración difiere más de un 25%; puede no ser una comparación equivalente.")
        }

        return warnings
    }

    private static func buildInsights(
        first: Activity,
        second: Activity,
        metrics: [ActivityComparisonMetric],
        segmentCount: Int
    ) -> [String] {
        var insights: [String] = []

        if let paceDiff = metrics.first(where: { $0.id == "averagePace" })?.rawDifference, abs(paceDiff) >= 5 {
            let direction = paceDiff < 0 ? "más rápido" : "más lento"
            insights.append("El entreno B fue \(formatPaceDeltaMagnitude(paceDiff)) \(direction) por km que el entreno A.")
        }

        let distanceDiff = second.distance - first.distance
        if abs(distanceDiff) >= 500 {
            let direction = distanceDiff > 0 ? "más distancia" : "menos distancia"
            insights.append("El entreno B tuvo \(formatDistance(abs(distanceDiff))) \(direction).")
        }

        if let firstHR = first.averageHeartrate, let secondHR = second.averageHeartrate, abs(secondHR - firstHR) >= 3 {
            let direction = secondHR > firstHR ? "más alta" : "más baja"
            insights.append(String(format: "La FC media de B fue %.0f bpm %@.", abs(secondHR - firstHR), direction))
        }

        if segmentCount > 0 {
            insights.append("Hay \(segmentCount) parciales alineados para revisar dónde se ganó o perdió tiempo.")
        }

        if insights.isEmpty {
            insights.append("Los dos entrenos son muy parecidos en las métricas principales.")
        }

        return insights
    }

    private static func buildSegments(
        first: Activity,
        second: Activity
    ) -> (source: ActivityComparisonSegmentSource, segments: [ActivityComparisonSegment]) {
        if let firstLaps = first.sortedLaps, let secondLaps = second.sortedLaps {
            return (.laps, zip(firstLaps, secondLaps).enumerated().map { index, pair in
                segment(
                    id: index,
                    title: pair.0.name ?? "Parcial \(index + 1)",
                    firstTime: pair.0.movingTime,
                    secondTime: pair.1.movingTime,
                    firstDistance: pair.0.distance,
                    secondDistance: pair.1.distance,
                    firstSpeed: pair.0.averageSpeed,
                    secondSpeed: pair.1.averageSpeed,
                    firstHeartRate: pair.0.averageHeartrate,
                    secondHeartRate: pair.1.averageHeartrate,
                    firstPower: pair.0.averageWatts,
                    secondPower: pair.1.averageWatts,
                    firstElevation: pair.0.effectivePositiveElevationGain,
                    secondElevation: pair.1.effectivePositiveElevationGain
                )
            })
        }

        if let firstSplits = first.sortedSplits, let secondSplits = second.sortedSplits {
            return (.splits, zip(firstSplits, secondSplits).enumerated().map { index, pair in
                segment(
                    id: index,
                    title: "Km \(index + 1)",
                    firstTime: pair.0.elapsedTime,
                    secondTime: pair.1.elapsedTime,
                    firstDistance: pair.0.distance,
                    secondDistance: pair.1.distance,
                    firstSpeed: pair.0.averageSpeed,
                    secondSpeed: pair.1.averageSpeed,
                    firstHeartRate: pair.0.averageHeartrate,
                    secondHeartRate: pair.1.averageHeartrate,
                    firstPower: pair.0.averageWatts,
                    secondPower: pair.1.averageWatts,
                    firstElevation: pair.0.effectivePositiveElevationGain,
                    secondElevation: pair.1.effectivePositiveElevationGain
                )
            })
        }

        return (.none, [])
    }

    private static func segment(
        id: Int,
        title: String,
        firstTime: Int,
        secondTime: Int,
        firstDistance: Double,
        secondDistance: Double,
        firstSpeed: Double,
        secondSpeed: Double,
        firstHeartRate: Double?,
        secondHeartRate: Double?,
        firstPower: Double?,
        secondPower: Double?,
        firstElevation: Double,
        secondElevation: Double
    ) -> ActivityComparisonSegment {
        let firstPace = paceSeconds(time: firstTime, distance: firstDistance) ?? paceSeconds(speed: firstSpeed)
        let secondPace = paceSeconds(time: secondTime, distance: secondDistance) ?? paceSeconds(speed: secondSpeed)
        let paceDiff = optionalDifference(firstPace, secondPace)

        return ActivityComparisonSegment(
            id: id,
            title: title,
            firstTime: formatDuration(firstTime),
            secondTime: formatDuration(secondTime),
            timeDifference: formatDurationDifference(secondTime - firstTime),
            firstPace: firstPace.map(formatPace) ?? "--",
            secondPace: secondPace.map(formatPace) ?? "--",
            paceDifference: paceDiff.map(formatPaceDifference) ?? "--",
            firstHeartRate: firstHeartRate.map { String(format: "%.0f", $0) } ?? "--",
            secondHeartRate: secondHeartRate.map { String(format: "%.0f", $0) } ?? "--",
            firstPower: firstPower.map { String(format: "%.0f W", $0) } ?? "--",
            secondPower: secondPower.map { String(format: "%.0f W", $0) } ?? "--",
            firstElevation: formatElevation(firstElevation),
            secondElevation: formatElevation(secondElevation),
            trend: trend(for: paceDiff ?? 0, lowerIsBetter: true),
            rawPaceDifference: paceDiff
        )
    }

    private static func numericMetric(
        id: String,
        title: String,
        first: Double,
        second: Double,
        formatter: (Double) -> String,
        differenceFormatter: (Double) -> String,
        lowerIsBetter: Bool,
        trend forcedTrend: ActivityComparisonTrend? = nil
    ) -> ActivityComparisonMetric {
        let difference = second - first
        let detail = percentageDetail(first: first, second: second)
        return ActivityComparisonMetric(
            id: id,
            title: title,
            firstValue: formatter(first),
            secondValue: formatter(second),
            differenceValue: differenceFormatter(difference),
            detail: detail,
            trend: forcedTrend ?? trend(for: difference, lowerIsBetter: lowerIsBetter),
            rawDifference: difference
        )
    }

    private static func optionalMetric(
        id: String,
        title: String,
        first: Double?,
        second: Double?,
        formatter: (Double) -> String,
        differenceFormatter: (Double) -> String,
        lowerIsBetter: Bool,
        trend forcedTrend: ActivityComparisonTrend? = nil
    ) -> ActivityComparisonMetric {
        guard let first, let second else {
            return ActivityComparisonMetric(
                id: id,
                title: title,
                firstValue: first.map(formatter) ?? "--",
                secondValue: second.map(formatter) ?? "--",
                differenceValue: "--",
                detail: nil,
                trend: .neutral,
                rawDifference: nil
            )
        }

        return numericMetric(
            id: id,
            title: title,
            first: first,
            second: second,
            formatter: formatter,
            differenceFormatter: differenceFormatter,
            lowerIsBetter: lowerIsBetter,
            trend: forcedTrend
        )
    }

    private static func efficiencyPacePerHeartRate(_ activity: Activity) -> Double? {
        guard let pace = paceSecondsPerKm(for: activity), let heartRate = activity.averageHeartrate, heartRate > 0 else {
            return nil
        }
        return pace / heartRate
    }

    private static func efficiencyPacePerWatt(_ activity: Activity) -> Double? {
        guard let pace = paceSecondsPerKm(for: activity), let watts = activity.averageWatts, watts > 0 else {
            return nil
        }
        return pace / watts
    }

    private static func metersPerKm(elevation: Double, distance: Double) -> Double {
        let km = distance / 1000
        guard km > 0 else { return 0 }
        return elevation / km
    }

    private static func paceSeconds(speed: Double) -> Double? {
        guard speed > 0 else { return nil }
        return 1000 / speed
    }

    private static func paceSeconds(time: Int, distance: Double) -> Double? {
        let km = distance / 1000
        guard km > 0 else { return nil }
        return Double(time) / km
    }

    private static func optionalDifference(_ first: Double?, _ second: Double?) -> Double? {
        guard let first, let second else { return nil }
        return second - first
    }

    private static func trend(for difference: Double, lowerIsBetter: Bool) -> ActivityComparisonTrend {
        guard abs(difference) > 0.0001 else { return .neutral }
        if lowerIsBetter {
            return difference < 0 ? .better : .worse
        }
        return difference > 0 ? .better : .worse
    }

    private static func relativeDifference(_ first: Double, _ second: Double) -> Double {
        guard first > 0 else { return second > 0 ? 1 : 0 }
        return abs(second - first) / first
    }

    private static func percentageDetail(first: Double, second: Double) -> String? {
        guard first != 0 else { return nil }
        let percent = ((second - first) / first) * 100
        guard abs(percent) >= 0.5 else { return nil }
        return signed(String(format: "%.1f%%", abs(percent)), value: percent)
    }

    private static func signed(_ value: String, value rawValue: Double) -> String {
        if rawValue > 0 {
            return "+\(value)"
        }
        if rawValue < 0 {
            return "-\(value)"
        }
        return value
    }

    private static func formatDistance(_ meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }

    private static func formatDistanceDifference(_ meters: Double) -> String {
        signed(formatDistance(abs(meters)), value: meters)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        TimeInterval(seconds).formattedDuration
    }

    private static func formatDurationDifference(_ seconds: Int) -> String {
        signed(formatDuration(abs(seconds)), value: Double(seconds))
    }

    private static func formatPace(_ seconds: Double) -> String {
        let rounded = Int(seconds.rounded())
        return "\(rounded / 60):\(String(format: "%02d", rounded % 60)) /km"
    }

    private static func formatPaceDifference(_ seconds: Double) -> String {
        signed("\(formatPaceDeltaMagnitude(seconds)) /km", value: seconds)
    }

    private static func formatPaceDeltaMagnitude(_ seconds: Double) -> String {
        let rounded = Int(abs(seconds).rounded())
        if rounded >= 60 {
            return "\(rounded / 60):\(String(format: "%02d", rounded % 60))"
        }
        return "\(rounded)s"
    }

    private static func formatSpeed(_ metersPerSecond: Double) -> String {
        String(format: "%.1f km/h", metersPerSecond * 3.6)
    }

    private static func formatSpeedDifference(_ metersPerSecond: Double) -> String {
        signed(String(format: "%.1f km/h", abs(metersPerSecond * 3.6)), value: metersPerSecond)
    }

    private static func formatElevation(_ meters: Double) -> String {
        String(format: "%.0f m", meters)
    }

    private static func formatElevationDifference(_ meters: Double) -> String {
        signed(formatElevation(abs(meters)), value: meters)
    }
}
