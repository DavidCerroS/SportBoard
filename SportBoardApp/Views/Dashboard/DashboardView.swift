//
//  DashboardView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: DashboardViewModel
    @ObservedObject var syncViewModel: SyncViewModel
    
    @State private var showSyncSheet = false
    @State private var showSportFilter = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Sync Progress (si está activo)
                    if syncViewModel.isActive || syncViewModel.isPaused {
                        SyncProgressCompactView(viewModel: syncViewModel)
                            .onTapGesture {
                                showSyncSheet = true
                            }
                    }
                    
                    // Filtro de deporte activo
                    if let filter = viewModel.selectedSportFilter {
                        HStack {
                            Image(systemName: filter.sportIcon)
                                .foregroundStyle(Color.sportColor(for: filter))
                            
                            Text("Filtrando por: \(filter.sportDisplayName)")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button {
                                viewModel.setSportFilter(nil)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Stats principales
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
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
                                icon: "heart.fill",
                                color: .red
                            )
                        }
                    }
                    
                    // Esta semana / Este mes
                    VStack(spacing: 12) {
                        LargeStatCard(
                            title: "Esta Semana",
                            value: viewModel.formattedThisWeekDistance,
                            subtitle: "\(viewModel.thisWeekActivities) actividades",
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
                    
                    // Deportes
                    if !viewModel.sportTypeCounts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Por Deporte")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button {
                                    showSportFilter = true
                                } label: {
                                    Text("Filtrar")
                                        .font(.subheadline)
                                }
                            }
                            
                            ForEach(viewModel.sortedSportTypes.prefix(5), id: \.sport) { item in
                                SportTypeCard(
                                    sportType: item.sport,
                                    count: item.count,
                                    isSelected: viewModel.selectedSportFilter == item.sport
                                ) {
                                    if viewModel.selectedSportFilter == item.sport {
                                        viewModel.setSportFilter(nil)
                                    } else {
                                        viewModel.setSportFilter(item.sport)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Actividades recientes
                    if !viewModel.recentActivities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actividades Recientes")
                                .font(.headline)
                            
                            ForEach(viewModel.recentActivities, id: \.id) { activity in
                                NavigationLink(value: activity) {
                                    RecentActivityRow(activity: activity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        syncViewModel.startSync()
                        showSyncSheet = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: "settings") {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: Activity.self) { activity in
                ActivityDetailView(activity: activity)
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "settings" {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showSyncSheet) {
                SyncProgressView(viewModel: syncViewModel) {
                    showSyncSheet = false
                    viewModel.loadStats()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSportFilter) {
                SportFilterSheet(
                    sportTypes: viewModel.sortedSportTypes,
                    selectedSport: viewModel.selectedSportFilter
                ) { sport in
                    viewModel.setSportFilter(sport)
                    showSportFilter = false
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                syncViewModel.configure(modelContext: modelContext)
                viewModel.loadStats()
            }
            .refreshable {
                viewModel.loadStats()
            }
        }
    }
}

// MARK: - Recent Activity Row

struct RecentActivityRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.sportType.sportIcon)
                .font(.title2)
                .foregroundStyle(Color.sportColor(for: activity.sportType))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(activity.startDate.shortDateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedDistance)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(activity.formattedMovingTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sport Filter Sheet

struct SportFilterSheet: View {
    let sportTypes: [(sport: String, count: Int)]
    let selectedSport: String?
    let onSelect: (String?) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Text("Todos los deportes")
                        Spacer()
                        if selectedSport == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.stravaOrange)
                        }
                    }
                }
                
                ForEach(sportTypes, id: \.sport) { item in
                    Button {
                        onSelect(item.sport)
                    } label: {
                        HStack {
                            Image(systemName: item.sport.sportIcon)
                                .foregroundStyle(Color.sportColor(for: item.sport))
                            
                            Text(item.sport.sportDisplayName)
                            
                            Spacer()
                            
                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                            
                            if selectedSport == item.sport {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.stravaOrange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtrar por Deporte")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var syncService = SyncService.shared
    @State private var showLogoutAlert = false
    @State private var showFullSyncAlert = false
    @State private var showResetAlert = false
    @State private var activityCount = 0
    
    var body: some View {
        List {
            Section {
                // Sincronización completa
                Button {
                    showFullSyncAlert = true
                } label: {
                    Label("Sincronización Completa", systemImage: "arrow.triangle.2.circlepath.circle")
                }
                
                // Reset y resincronizar
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Borrar y Resincronizar Todo", systemImage: "trash.circle")
                }
            } header: {
                Text("Sincronización")
            } footer: {
                Text("Usa 'Sincronización Completa' si la sincronización inicial no terminó. 'Borrar y Resincronizar' eliminará todas las actividades locales y las volverá a descargar.")
            }
            
            Section("Datos") {
                LabeledContent("Actividades sincronizadas", value: "\(activityCount)")
            }
            
            Section("Cuenta") {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            
            Section("Información") {
                LabeledContent("Versión", value: "1.0.0")
            }
        }
        .navigationTitle("Ajustes")
        .onAppear {
            loadActivityCount()
        }
        .alert("Sincronización Completa", isPresented: $showFullSyncAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Sincronizar") {
                startFullSync()
            }
        } message: {
            Text("Esto descargará todas las actividades históricas que falten. Puede tardar varios minutos y consumir llamadas de API.")
        }
        .alert("Borrar y Resincronizar", isPresented: $showResetAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar Todo", role: .destructive) {
                resetAndResync()
            }
        } message: {
            Text("Se eliminarán todas las actividades sincronizadas y se volverán a descargar desde Strava. ¿Continuar?")
        }
        .alert("Cerrar Sesión", isPresented: $showLogoutAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Cerrar Sesión", role: .destructive) {
                authService.logout()
            }
        } message: {
            Text("¿Estás seguro de que quieres cerrar sesión? Los datos sincronizados se mantendrán.")
        }
    }
    
    private func loadActivityCount() {
        let descriptor = FetchDescriptor<Activity>()
        activityCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    private func startFullSync() {
        syncService.configure(modelContext: modelContext)
        syncService.startSync(fullSync: true)
    }
    
    private func resetAndResync() {
        // Borrar todas las actividades
        do {
            try modelContext.delete(model: Activity.self)
            try modelContext.delete(model: ActivityLap.self)
            try modelContext.delete(model: ActivitySplit.self)
            try modelContext.delete(model: SyncState.self)
            try modelContext.save()
            
            activityCount = 0
            
            // Iniciar sync completa
            syncService.configure(modelContext: modelContext)
            syncService.startSync(fullSync: true)
        } catch {
            print("Error resetting data: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Activity.self, ActivityLap.self, ActivitySplit.self, SyncState.self, configurations: config)
    
    return DashboardView(
        viewModel: DashboardViewModel(),
        syncViewModel: SyncViewModel()
    )
    .modelContainer(container)
}
