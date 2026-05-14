//
//  TempoBlockSplitsTableView.swift
//  SportBoardApp
//

import SwiftUI

struct TempoBlockSplitsTableView: View {
    let splits: [ActivityTempoBlockSplit]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detalle tempo")
                .font(.headline)

            HStack(spacing: 0) {
                Text("Km")
                    .frame(width: 44, alignment: .leading)
                Text("Tiempo")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Ritmo")
                    .frame(width: 56, alignment: .trailing)
                Text("FC")
                    .frame(width: 42, alignment: .trailing)
                Text("W")
                    .frame(width: 46, alignment: .trailing)
                Text("Desn.")
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)

            Divider()

            ForEach(splits, id: \.splitIndex) { split in
                TempoBlockSplitRowView(split: split)
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium)
    }
}

private struct TempoBlockSplitRowView: View {
    let split: ActivityTempoBlockSplit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("T\(split.splitIndex)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 44, alignment: .leading)

                Text(split.formattedTime)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(split.formattedPace)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .frame(width: 56, alignment: .trailing)

                Text(split.formattedHeartrate)
                    .font(.caption)
                    .foregroundStyle(split.averageHeartrate != nil ? .red : .secondary)
                    .frame(width: 42, alignment: .trailing)

                Text(split.formattedAveragePower)
                    .font(.caption)
                    .foregroundStyle(split.averageWatts != nil ? .purple : .secondary)
                    .frame(width: 46, alignment: .trailing)

                Text(split.formattedElevation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            Text("\(formatDistance(split.startDistance))-\(formatDistance(split.endDistance)) del bloque · +\(Int(split.positiveElevationGain.rounded()))m | -\(Int(split.negativeElevationLoss.rounded()))m · Potencia max: \(split.formattedMaxPower)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(split.splitIndex % 2 == 0 ? Color.white.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDistance(_ meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }
}

#Preview {
    TempoBlockSplitsTableView(splits: [
        ActivityTempoBlockSplit(
            blockLapIndex: 1,
            splitIndex: 1,
            name: "Tempo 1",
            distance: 1000,
            elapsedTime: 252,
            movingTime: 252,
            averageSpeed: 1000 / 252,
            elevationDifference: 2,
            positiveElevationGain: 4,
            negativeElevationLoss: 2,
            averageHeartrate: 166,
            maxHeartrate: 174,
            averageWatts: 284,
            maxWatts: 340,
            averageCadence: 178,
            averageGrade: 0.2,
            startDistance: 0,
            endDistance: 1000
        )
    ])
    .padding()
    .premiumScreenBackground()
}
