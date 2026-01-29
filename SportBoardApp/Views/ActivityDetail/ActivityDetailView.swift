//
//  ActivityDetailView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI
import SwiftData

struct ActivityDetailView: View {
    let activity: Activity
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ActivityDetailViewModel
    
    init(activity: Activity) {
        self.activity = activity
        self._viewModel = State(initialValue: ActivityDetailViewModel(activity: activity))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header con info principal
                headerSection
                
                // Stats principales
                statsGrid
                
                // Sección de parciales (carga bajo demanda)
                if viewModel.isLoadingDetails {
                    loadingDetailsSection
                } else if let error = viewModel.detailsLoadError {
                    errorSection(error)
                } else {
                    // Laps (parciales de trabajo) si existen
                    if viewModel.showLapsSection {
                        LapsTableView(laps: viewModel.laps, sportType: activity.sportType)
                    }
                    
                    // Splits (por km) si existen y no hay laps
                    if viewModel.showSplitsSection {
                        SplitsTableView(splits: viewModel.splits, sportType: activity.sportType)
                    }
                    
                    // Si tiene ambos, mostrar splits como sección secundaria
                    if viewModel.hasLaps && viewModel.hasSplits {
                        DisclosureGroup {
                            SplitsTableView(splits: viewModel.splits, sportType: activity.sportType)
                        } label: {
                            Label("Ver kilómetros", systemImage: "ruler")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Si aún no se han cargado los detalles, mostrar mensaje
                    if !activity.detailsFetched && !viewModel.hasLaps && !viewModel.hasSplits {
                        noDetailsSection
                    }
                }
                
                // Descripción si existe
                if let description = activity.activityDescription, !description.isEmpty {
                    descriptionSection(description)
                }
                
                // Info adicional
                additionalInfoSection
            }
            .padding()
        }
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ExportMenuView(viewModel: viewModel)
            }
        }
        .task {
            // Cargar detalles bajo demanda cuando se abre la vista
            await viewModel.loadDetailsIfNeeded(context: modelContext)
        }
        .alert("JSON Copiado", isPresented: $viewModel.showCopiedAlert) {
            Button("OK") {}
        } message: {
            Text("Los datos de la actividad se han copiado al portapapeles en formato JSON")
        }
        .alert("Error", isPresented: $viewModel.showExportError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingDetailsSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Cargando parciales...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Reintentar") {
                Task {
                    await viewModel.loadDetailsIfNeeded(context: modelContext)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var noDetailsSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Esta actividad no tiene parciales disponibles")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icono y tipo
            ZStack {
                Circle()
                    .fill(Color.sportColor(for: activity.sportType).opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: activity.sportType.sportIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(Color.sportColor(for: activity.sportType))
            }
            
            Text(activity.sportType.sportDisplayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(activity.startDate.fullDateTimeString)
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            if let device = activity.deviceName {
                Text(device)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // Distancia
            StatItemView(
                title: "Distancia",
                value: activity.formattedDistance,
                icon: "ruler",
                color: Color.stravaOrange
            )
            
            // Tiempo
            StatItemView(
                title: "Tiempo",
                value: activity.formattedMovingTime,
                icon: "clock",
                color: .blue
            )
            
            // Ritmo/Velocidad
            StatItemView(
                title: activity.speedOrPaceLabel,
                value: activity.formattedSpeedOrPace,
                subtitle: activity.speedOrPaceUnit,
                icon: "speedometer",
                color: .green
            )
            
            // Desnivel
            StatItemView(
                title: "Desnivel",
                value: activity.formattedElevation,
                icon: "mountain.2",
                color: .brown
            )
            
            // FC Media
            if let hr = activity.averageHeartrate {
                StatItemView(
                    title: "FC Media",
                    value: hr.formattedHeartRate,
                    subtitle: activity.maxHeartrate != nil ? "Max: \(Int(activity.maxHeartrate!)) bpm" : nil,
                    icon: "heart",
                    color: .red
                )
            }
            
            // Potencia
            if let watts = activity.averageWatts {
                StatItemView(
                    title: "Potencia",
                    value: watts.formattedPower,
                    subtitle: activity.maxWatts != nil ? "Max: \(Int(activity.maxWatts!)) W" : nil,
                    icon: "bolt",
                    color: .purple
                )
            }
        }
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descripción")
                .font(.headline)
            
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información Adicional")
                .font(.headline)
            
            LabeledContent("Tiempo transcurrido", value: TimeInterval(activity.elapsedTime).formattedDuration)
            
            if let kj = activity.kilojoules {
                LabeledContent("Calorías", value: "\(Int(kj)) kJ")
            }
            
            LabeledContent("ID de Strava", value: "\(activity.id)")
            
            LabeledContent("Sincronizado", value: activity.syncedAt.shortDateString)
            
            Divider()
                .padding(.vertical, 8)
            
            // Botones de Debug y Resync
            VStack(spacing: 12) {
                // Botón Resincronizar
                Button {
                    Task {
                        await viewModel.forceResync(context: modelContext)
                    }
                } label: {
                    HStack {
                        if viewModel.isResyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(viewModel.isResyncing ? "Resincronizando..." : "Resincronizar con Strava")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isResyncing)
                
                // Botón Debug (imprime en consola)
                Button {
                    viewModel.printDebugData()
                } label: {
                    HStack {
                        Image(systemName: "ladybug")
                        Text("Ver datos en consola")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                
                // Mensaje de éxito
                if viewModel.resyncSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Resincronización completada")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Item View

struct StatItemView: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let activity = Activity(
        id: 12345678,
        name: "Morning Run - Parque del Retiro",
        sportType: "Run",
        startDate: Date(),
        distance: 10234.5,
        movingTime: 3120,
        elapsedTime: 3300,
        totalElevationGain: 125,
        averageSpeed: 3.28,
        maxSpeed: 4.5,
        averageHeartrate: 152,
        maxHeartrate: 178,
        hasHeartrate: true,
        deviceName: "Garmin Forerunner 265",
        activityDescription: "Gran carrera matutina por el parque. Buen ritmo constante.",
        hasLaps: true,
        hasSplitsMetric: true
    )
    
    return NavigationStack {
        ActivityDetailView(activity: activity)
    }
}
