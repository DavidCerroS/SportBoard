//
//  ElevationBreakdownCalculator.swift
//  SportBoardApp
//
//  Created by Codex on 31/3/26.
//

import Foundation

struct ElevationBreakdown: Equatable {
    let positive: Double
    let negative: Double
}

struct PowerBreakdown: Equatable {
    let average: Double
    let max: Double
}

enum ElevationBreakdownCalculator {
    static func calculateIndexBreakdowns(
        indexRanges: [(startIndex: Int, endIndex: Int)],
        altitudeStream: [Double]
    ) -> [ElevationBreakdown]? {
        guard altitudeStream.count >= 2 else { return nil }

        let lastIndex = altitudeStream.count - 1

        return indexRanges.map { range in
            let startIndex = max(0, min(range.startIndex, lastIndex))
            let endIndex = max(0, min(range.endIndex, lastIndex))

            guard endIndex > startIndex else {
                return ElevationBreakdown(positive: 0, negative: 0)
            }

            var positive = 0.0
            var negative = 0.0

            for index in startIndex..<endIndex {
                let delta = altitudeStream[index + 1] - altitudeStream[index]
                if delta > 0 {
                    positive += delta
                } else {
                    negative += -delta
                }
            }

            return ElevationBreakdown(positive: positive, negative: negative)
        }
    }

    static func calculateSequentialBreakdowns(
        segmentDistances: [Double],
        distanceStream: [Double],
        altitudeStream: [Double]
    ) -> [ElevationBreakdown]? {
        guard distanceStream.count == altitudeStream.count, distanceStream.count >= 2 else {
            return nil
        }

        let lastDistance = distanceStream.last ?? 0
        var startDistance = 0.0

        return segmentDistances.map { segmentDistance in
            let unclampedEndDistance = startDistance + max(segmentDistance, 0)
            let endDistance = min(unclampedEndDistance, lastDistance)
            let breakdown = calculateBreakdown(
                startDistance: startDistance,
                endDistance: endDistance,
                distanceStream: distanceStream,
                altitudeStream: altitudeStream
            )
            startDistance = unclampedEndDistance
            return breakdown
        }
    }

    private static func calculateBreakdown(
        startDistance: Double,
        endDistance: Double,
        distanceStream: [Double],
        altitudeStream: [Double]
    ) -> ElevationBreakdown {
        guard endDistance > startDistance else {
            return ElevationBreakdown(positive: 0, negative: 0)
        }

        var positive = 0.0
        var negative = 0.0

        for index in 1..<distanceStream.count {
            let distance0 = distanceStream[index - 1]
            let distance1 = distanceStream[index]
            let altitude0 = altitudeStream[index - 1]
            let altitude1 = altitudeStream[index]

            guard distance1 > distance0 else { continue }

            let overlapStart = max(startDistance, distance0)
            let overlapEnd = min(endDistance, distance1)

            guard overlapEnd > overlapStart else { continue }

            let startAltitude = interpolatedAltitude(
                targetDistance: overlapStart,
                distance0: distance0,
                distance1: distance1,
                altitude0: altitude0,
                altitude1: altitude1
            )
            let endAltitude = interpolatedAltitude(
                targetDistance: overlapEnd,
                distance0: distance0,
                distance1: distance1,
                altitude0: altitude0,
                altitude1: altitude1
            )

            let delta = endAltitude - startAltitude
            if delta > 0 {
                positive += delta
            } else {
                negative += -delta
            }
        }

        return ElevationBreakdown(positive: positive, negative: negative)
    }

    private static func interpolatedAltitude(
        targetDistance: Double,
        distance0: Double,
        distance1: Double,
        altitude0: Double,
        altitude1: Double
    ) -> Double {
        let ratio = (targetDistance - distance0) / (distance1 - distance0)
        return altitude0 + ((altitude1 - altitude0) * ratio)
    }
}

enum PowerBreakdownCalculator {
    static func calculateIndexBreakdowns(
        indexRanges: [(startIndex: Int, endIndex: Int)],
        timeStream: [Int]?,
        wattsStream: [Int]
    ) -> [PowerBreakdown]? {
        guard !wattsStream.isEmpty else { return nil }

        let lastIndex = wattsStream.count - 1
        return indexRanges.map { range in
            let startIndex = max(0, min(range.startIndex, lastIndex))
            let endIndex = max(0, min(range.endIndex, lastIndex))
            guard endIndex >= startIndex else {
                return PowerBreakdown(average: 0, max: 0)
            }

            return calculateBreakdown(
                indexes: Array(startIndex...endIndex),
                timeStream: timeStream,
                wattsStream: wattsStream
            )
        }
    }

    static func calculateSequentialBreakdowns(
        segmentDistances: [Double],
        distanceStream: [Double],
        timeStream: [Int]?,
        wattsStream: [Int]
    ) -> [PowerBreakdown]? {
        guard distanceStream.count == wattsStream.count, distanceStream.count >= 2 else {
            return nil
        }

        let lastDistance = distanceStream.last ?? 0
        var startDistance = 0.0

        return segmentDistances.map { segmentDistance in
            let unclampedEndDistance = startDistance + max(segmentDistance, 0)
            let endDistance = min(unclampedEndDistance, lastDistance)
            let breakdown = calculateBreakdown(
                startDistance: startDistance,
                endDistance: endDistance,
                distanceStream: distanceStream,
                timeStream: timeStream,
                wattsStream: wattsStream
            )
            startDistance = unclampedEndDistance
            return breakdown
        }
    }

    private static func calculateBreakdown(
        indexes: [Int],
        timeStream: [Int]?,
        wattsStream: [Int]
    ) -> PowerBreakdown {
        guard !indexes.isEmpty else {
            return PowerBreakdown(average: 0, max: 0)
        }

        let maxWatts = indexes.map { Double(wattsStream[$0]) }.max() ?? 0

        guard let timeStream, timeStream.count == wattsStream.count, indexes.count > 1 else {
            let average = indexes.reduce(0.0) { $0 + Double(wattsStream[$1]) } / Double(indexes.count)
            return PowerBreakdown(average: average, max: maxWatts)
        }

        var weightedWatts = 0.0
        var totalSeconds = 0.0

        for pairIndex in 1..<indexes.count {
            let previousIndex = indexes[pairIndex - 1]
            let currentIndex = indexes[pairIndex]
            let seconds = Double(max(timeStream[currentIndex] - timeStream[previousIndex], 0))
            guard seconds > 0 else { continue }

            let averageIntervalWatts = (Double(wattsStream[previousIndex]) + Double(wattsStream[currentIndex])) / 2
            weightedWatts += averageIntervalWatts * seconds
            totalSeconds += seconds
        }

        let average = totalSeconds > 0
            ? weightedWatts / totalSeconds
            : indexes.reduce(0.0) { $0 + Double(wattsStream[$1]) } / Double(indexes.count)

        return PowerBreakdown(average: average, max: maxWatts)
    }

    private static func calculateBreakdown(
        startDistance: Double,
        endDistance: Double,
        distanceStream: [Double],
        timeStream: [Int]?,
        wattsStream: [Int]
    ) -> PowerBreakdown {
        guard endDistance > startDistance else {
            return PowerBreakdown(average: 0, max: 0)
        }

        var weightedWatts = 0.0
        var totalSeconds = 0.0
        var sampledWatts: [Double] = []

        for index in 1..<distanceStream.count {
            let distance0 = distanceStream[index - 1]
            let distance1 = distanceStream[index]
            guard distance1 > distance0 else { continue }

            let overlapStart = max(startDistance, distance0)
            let overlapEnd = min(endDistance, distance1)
            guard overlapEnd > overlapStart else { continue }

            let overlapRatio = (overlapEnd - overlapStart) / (distance1 - distance0)
            let watts0 = Double(wattsStream[index - 1])
            let watts1 = Double(wattsStream[index])
            let averageIntervalWatts = (watts0 + watts1) / 2
            sampledWatts.append(watts0)
            sampledWatts.append(watts1)

            if let timeStream, timeStream.count == wattsStream.count {
                let seconds = Double(max(timeStream[index] - timeStream[index - 1], 0)) * overlapRatio
                weightedWatts += averageIntervalWatts * seconds
                totalSeconds += seconds
            } else {
                weightedWatts += averageIntervalWatts * overlapRatio
                totalSeconds += overlapRatio
            }
        }

        guard totalSeconds > 0 else {
            return PowerBreakdown(average: 0, max: sampledWatts.max() ?? 0)
        }

        return PowerBreakdown(
            average: weightedWatts / totalSeconds,
            max: sampledWatts.max() ?? 0
        )
    }
}
