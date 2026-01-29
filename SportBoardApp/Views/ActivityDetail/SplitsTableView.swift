//
//  SplitsTableView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct SplitsTableView: View {
    let splits: [ActivitySplit]
    let sportType: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kilómetros")
                .font(.headline)
            
            // Header
            HStack(spacing: 0) {
                Text("Km")
                    .frame(width: 40, alignment: .leading)
                Text("Tiempo")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(sportType.usesPace ? "Ritmo" : "Vel.")
                    .frame(width: 55, alignment: .trailing)
                Text("FC")
                    .frame(width: 45, alignment: .trailing)
                Text("Desn.")
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            
            Divider()
            
            // Rows
            ForEach(splits, id: \.splitIndex) { split in
                SplitRowView(split: split, sportType: sportType, fastestPace: fastestPace, slowestPace: slowestPace)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var fastestPace: Double {
        splits.map { $0.averageSpeed }.max() ?? 0
    }
    
    private var slowestPace: Double {
        splits.map { $0.averageSpeed }.min() ?? 0
    }
}

struct SplitRowView: View {
    let split: ActivitySplit
    let sportType: String
    let fastestPace: Double
    let slowestPace: Double
    
    var body: some View {
        HStack(spacing: 0) {
            Text(split.formattedKm)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .leading)
            
            Text(split.formattedTime)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(sportType.usesPace ? split.formattedPace : split.formattedSpeed)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(paceColor)
                .frame(width: 55, alignment: .trailing)
            
            Text(split.formattedHeartrate)
                .font(.caption)
                .foregroundStyle(split.averageHeartrate != nil ? .red : .secondary)
                .frame(width: 45, alignment: .trailing)
            
            Text(split.formattedElevation)
                .font(.caption)
                .foregroundStyle(elevationColor)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(split.splitIndex % 2 == 0 ? Color.clear : Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var paceColor: Color {
        guard fastestPace > slowestPace else { return .primary }
        
        let range = fastestPace - slowestPace
        let position = (split.averageSpeed - slowestPace) / range
        
        if position > 0.66 {
            return .green
        } else if position > 0.33 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var elevationColor: Color {
        if split.elevationDifference > 10 {
            return .red
        } else if split.elevationDifference < -10 {
            return .green
        } else {
            return .secondary
        }
    }
}

#Preview {
    let splits = [
        ActivitySplit(splitIndex: 0, distance: 1000, movingTime: 298, averageSpeed: 3.35, averageHeartrate: 145, elevationDifference: 12),
        ActivitySplit(splitIndex: 1, distance: 1000, movingTime: 285, averageSpeed: 3.50, averageHeartrate: 158, elevationDifference: -5),
        ActivitySplit(splitIndex: 2, distance: 1000, movingTime: 310, averageSpeed: 3.22, averageHeartrate: 162, elevationDifference: 8),
        ActivitySplit(splitIndex: 3, distance: 1000, movingTime: 275, averageSpeed: 3.63, averageHeartrate: 168, elevationDifference: -15),
    ]
    
    return SplitsTableView(splits: splits, sportType: "Run")
        .padding()
}
