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
