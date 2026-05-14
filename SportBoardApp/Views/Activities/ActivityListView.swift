//
//  ActivityListView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI
import SwiftData

struct ActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ActivitiesViewModel
    
    @State private var activeSheet: ActivityListSheet?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra de búsqueda y filtros rápidos
                VStack(spacing: 12) {
                    // Búsqueda
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(SportBoardTheme.Palette.dimText)
                        
                        TextField("Buscar actividades...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                        
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 12)
                    .padding(.horizontal)
                    
                    // Filtros rápidos
                    QuickFilterChips(viewModel: viewModel)
                }
                .padding(.vertical, 8)
                .background(SportBoardTheme.Palette.backgroundTop.opacity(0.92))
                
                // Lista de actividades
                if viewModel.filteredActivities.isEmpty {
                    ContentUnavailableView {
                        Label("Sin actividades", systemImage: "figure.run")
                    } description: {
                        if viewModel.hasActiveFilters {
                            Text("No hay actividades que coincidan con los filtros")
                        } else {
                            Text("Sincroniza con Strava para ver tus actividades")
                        }
                    } actions: {
                        if viewModel.hasActiveFilters {
                            Button("Limpiar filtros") {
                                viewModel.clearFilters()
                            }
                        }
                    }
                    .foregroundStyle(.white)
                } else {
                    List {
                        ForEach(groupedActivities, id: \.key) { month, activities in
                            Section {
                                ForEach(activities, id: \.id) { activity in
                                    NavigationLink(value: activity) {
                                        ActivityRowView(activity: activity)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text(month)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Actividades")
            .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .premiumScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .filters
                    } label: {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filtros")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ActivitiesViewModel.SortOrder.allCases, id: \.self) { order in
                            Button {
                                viewModel.sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if viewModel.sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Ordenar")
                }
            }
            .navigationDestination(for: Activity.self) { activity in
                ActivityDetailView(activity: activity)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .filters:
                    ActivityFilterView(viewModel: viewModel)
                        .presentationBackground(SportBoardTheme.Palette.backgroundBottom)
                }
            }
            .task {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadActivities()
            }
            .refreshable {
                viewModel.loadActivities()
            }
        }
    }
    
    // Agrupar actividades por mes
    private var groupedActivities: [(key: String, value: [Activity])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        
        let grouped = Dictionary(grouping: viewModel.filteredActivities) { activity in
            formatter.string(from: activity.startDate)
        }
        
        // Ordenar por fecha (más reciente primero)
        return grouped.sorted { pair1, pair2 in
            guard let date1 = viewModel.filteredActivities.first(where: { formatter.string(from: $0.startDate) == pair1.key })?.startDate,
                  let date2 = viewModel.filteredActivities.first(where: { formatter.string(from: $0.startDate) == pair2.key })?.startDate else {
                return false
            }
            return date1 > date2
        }
    }
}

private enum ActivityListSheet: Hashable, Identifiable {
    case filters

    var id: Self { self }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Activity.self, ActivityLap.self, ActivitySplit.self,
        ActivityZoneDistribution.self, ActivityStreamSummary.self, StravaGear.self, ActivitySegmentEffort.self,
        ActivityTempoBlockSplit.self,
        configurations: config
    )
    
    return ActivityListView(viewModel: ActivitiesViewModel())
        .modelContainer(container)
}
