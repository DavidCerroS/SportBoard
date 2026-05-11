//
//  LapsTableView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct LapsTableView: View {
    let laps: [ActivityLap]
    let sportType: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parciales de Trabajo")
                .font(.headline)
            
            // Header
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 30, alignment: .leading)
                Text("Distancia")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Tiempo")
                    .frame(width: 60, alignment: .trailing)
                Text(sportType.usesPace ? "Ritmo" : "Vel.")
                    .frame(width: 55, alignment: .trailing)
                Text("FC")
                    .frame(width: 40, alignment: .trailing)
                Text("W")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            
            Divider()
            
            // Rows
            ForEach(laps, id: \.lapIndex) { lap in
                LapRowView(lap: lap, sportType: sportType)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LapRowView: View {
    let lap: ActivityLap
    let sportType: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("\(lap.lapIndex + 1)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 30, alignment: .leading)
                
                Text(lap.formattedDistance)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(lap.formattedTime)
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
                
                Text(sportType.usesPace ? lap.formattedPace : lap.formattedSpeed)
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 55, alignment: .trailing)
                
                Text(lap.formattedHeartrate)
                    .font(.caption)
                    .foregroundStyle(lap.averageHeartrate != nil ? .red : .secondary)
                    .frame(width: 40, alignment: .trailing)
                
                Text(lap.formattedAveragePower)
                    .font(.caption)
                    .foregroundStyle(lap.averageWatts != nil ? .purple : .secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            Text("Desnivel: \(Int(lap.totalElevationGain.rounded()))m | +\(Int(lap.effectivePositiveElevationGain.rounded()))m | -\(Int(lap.effectiveNegativeElevationLoss.rounded()))m · Potencia max: \(lap.formattedMaxPower)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(lap.lapIndex % 2 == 0 ? Color.clear : Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    let laps = [
        ActivityLap(lapIndex: 0, name: "Lap 1", distance: 1000, movingTime: 298, averageSpeed: 3.35, averageHeartrate: 145, averageWatts: 245, maxWatts: 390),
        ActivityLap(lapIndex: 1, name: "Lap 2", distance: 1000, movingTime: 285, averageSpeed: 3.50, averageHeartrate: 158, averageWatts: 260, maxWatts: 420),
        ActivityLap(lapIndex: 2, name: "Lap 3", distance: 1000, movingTime: 310, averageSpeed: 3.22, averageHeartrate: 162),
    ]
    
    LapsTableView(laps: laps, sportType: "Run")
        .padding()
}
