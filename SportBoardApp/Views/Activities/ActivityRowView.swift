//
//  ActivityRowView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct ActivityRowView: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 16) {
            // Icono del deporte
            ZStack {
                Circle()
                    .fill(Color.sportColor(for: activity.sportType).opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: activity.sportType.sportIcon)
                    .font(.title2)
                    .foregroundStyle(Color.sportColor(for: activity.sportType))
            }
            
            // Info principal
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(activity.sportType.sportDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(activity.startDate.shortDateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Métricas
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedDistance)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(activity.formattedMovingTime)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ActivityRowCompactView: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.sportType.sportIcon)
                .font(.title3)
                .foregroundStyle(Color.sportColor(for: activity.sportType))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(activity.startDate.shortDateString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(activity.formattedDistance)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let activity = Activity(
        id: 1,
        name: "Morning Run",
        sportType: "Run",
        startDate: Date(),
        distance: 10234.5,
        movingTime: 3120,
        elapsedTime: 3300,
        totalElevationGain: 125,
        averageSpeed: 3.28,
        maxSpeed: 4.5,
        averageHeartrate: 152,
        hasHeartrate: true
    )
    
    return List {
        ActivityRowView(activity: activity)
        ActivityRowCompactView(activity: activity)
    }
}
