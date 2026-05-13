//
//  StatisticsView.swift
//  SportBoardApp
//

import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: DashboardViewModel

    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    totalsSection
                    periodSection
                    sportDistributionSection
                }
                .padding()
            }
            .premiumScreenBackground()
            .navigationTitle("Estadísticas")
            .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadStats()
            }
            .refreshable {
                viewModel.loadStats()
            }
        }
    }

    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Acumulado")

            LazyVGrid(columns: gridColumns, spacing: 16) {
                StatCard(
                    title: "Actividades",
                    value: "\(viewModel.totalActivities)",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    title: "Distancia Total",
                    value: viewModel.formattedTotalDistance,
                    icon: "figure.run",
                    color: Color.stravaOrange
                )

                StatCard(
                    title: "Tiempo Total",
                    value: viewModel.formattedTotalTime,
                    icon: "clock.fill",
                    color: .blue
                )

                StatCard(
                    title: "Desnivel",
                    value: viewModel.formattedTotalElevation,
                    icon: "mountain.2.fill",
                    color: .green
                )

                if let hr = viewModel.averageHeartrate {
                    StatCard(
                        title: "FC Media",
                        value: hr.formattedHeartRate,
                        subtitle: "Actividades con sensor",
                        icon: "heart.fill",
                        color: .red
                    )
                }
            }
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Periodos")

            VStack(spacing: 12) {
                LargeStatCard(
                    title: "Esta Semana",
                    value: viewModel.formattedThisWeekDistance,
                    subtitle: "\(viewModel.thisWeekActivities) carreras · \(viewModel.formattedThisWeekTime)",
                    icon: "calendar",
                    color: Color.stravaOrange
                )

                LargeStatCard(
                    title: "Este Mes",
                    value: viewModel.formattedThisMonthDistance,
                    subtitle: "\(viewModel.thisMonthActivities) actividades",
                    icon: "calendar.badge.clock",
                    color: .blue
                )
            }
        }
    }

    @ViewBuilder
    private var sportDistributionSection: some View {
        if !viewModel.sportTypeCounts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Por Deporte")

                ForEach(viewModel.sortedSportTypes, id: \.sport) { item in
                    SportTypeStatRow(sportType: item.sport, count: item.count)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
    }
}

private struct SportTypeStatRow: View {
    let sportType: String
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: sportType.sportIcon)
                .font(.title3)
                .foregroundStyle(Color.sportColor(for: sportType))
                .frame(width: 38, height: 38)
                .background(Color.sportColor(for: sportType).opacity(0.16), in: Circle())

            Text(sportType.sportDisplayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            Text("\(count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .premiumCard(
            cornerRadius: SportBoardTheme.Radius.medium,
            padding: 14,
            accent: Color.sportColor(for: sportType).opacity(0.4)
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Activity.self, ActivityLap.self, ActivitySplit.self, SyncState.self,
        RunnerProfile.self, PostActivityReflection.self,
        configurations: config
    )

    return StatisticsView(viewModel: DashboardViewModel())
        .modelContainer(container)
}
