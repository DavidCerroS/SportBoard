//
//  StatCard.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color = Color.stravaOrange
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.16), in: Circle())
                
                Spacer()
            }
            
            Text(value)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard(accent: color.opacity(0.65))
    }
}

struct LargeStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color = Color.stravaOrange
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.16), in: Circle())
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
                .foregroundStyle(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, accent: color.opacity(0.55), isElevated: true)
    }
}

struct SportTypeCard: View {
    let sportType: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: sportType.sportIcon)
                    .font(.title3)
                    .foregroundStyle(Color.sportColor(for: sportType))
                    .frame(width: 38, height: 38)
                    .background(Color.sportColor(for: sportType).opacity(0.16), in: Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(sportType.sportDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    
                    Text("\(count) actividades")
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.stravaOrange)
                }
            }
            .premiumCard(
                cornerRadius: SportBoardTheme.Radius.medium,
                padding: 14,
                accent: isSelected ? Color.stravaOrange : Color.sportColor(for: sportType).opacity(0.4)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            StatCard(title: "Distancia Total", value: "1,234 km", icon: "figure.run")
            StatCard(title: "Tiempo Total", value: "123h 45m", icon: "clock")
        }
        
        LargeStatCard(
            title: "Esta Semana",
            value: "42.5 km",
            subtitle: "5 actividades",
            icon: "calendar"
        )
        
        SportTypeCard(sportType: "Run", count: 150, isSelected: true, onTap: {})
        SportTypeCard(sportType: "Ride", count: 80, isSelected: false, onTap: {})
    }
    .padding()
}
