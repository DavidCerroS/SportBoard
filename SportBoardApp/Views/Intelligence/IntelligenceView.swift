//
//  IntelligenceView.swift
//  SportBoardApp
//
//  Pantalla dedicada a la inteligencia de entrenamiento: alertas, narrativa, consistencia, fatiga, próximo entreno, herramientas.
//

import SwiftUI
import SwiftData

struct IntelligenceView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: DashboardViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Alertas silenciosas
                    if !viewModel.silentAlerts.isEmpty {
                        sectionHeader("Avisos")
                        ForEach(viewModel.silentAlerts, id: \.id) { alert in
                            card {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(alert.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // Narrativa semanal
                    if !viewModel.weeklyNarrative.isEmpty {
                        sectionHeader("Esta semana")
                        card {
                            Text(viewModel.weeklyNarrative)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Consistencia real
                    if let c = viewModel.consistencyBreakdown {
                        sectionHeader("Consistencia")
                        card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("\(c.score)/100")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                ForEach(c.reasons, id: \.self) { reason in
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Fatiga explicable
                    if let f = viewModel.fatigueDiagnosis {
                        sectionHeader("Fatiga acumulada")
                        card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(f.level.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                ForEach(f.causes, id: \.self) { cause in
                                    Text("• \(cause)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(f.recommendedAction)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Sugerencia próximo entreno
                    if let s = viewModel.nextWorkoutSuggestion {
                        sectionHeader("Próximo entreno recomendado")
                        card(accent: true) {
                            Text(s.fullText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Pico sospechoso
                    if let p = viewModel.suspiciousPeak, p.detected {
                        sectionHeader("Nota")
                        card(accentOrange: true) {
                            Text(p.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Herramientas
                    sectionHeader("Herramientas")
                    VStack(spacing: 12) {
                        NavigationLink(value: "weekComparator") {
                            Label("Comparar semanas", systemImage: "calendar.badge.clock")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        NavigationLink(value: "simulator") {
                            Label("Simulador", systemImage: "slider.horizontal.3")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Si no hay nada que mostrar
                    if viewModel.silentAlerts.isEmpty
                        && viewModel.weeklyNarrative.isEmpty
                        && viewModel.consistencyBreakdown == nil
                        && viewModel.fatigueDiagnosis == nil
                        && viewModel.nextWorkoutSuggestion == nil
                        && (viewModel.suspiciousPeak?.detected != true) {
                        Text("Sincroniza actividades de carrera para ver insights.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Inteligencia")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.loadStats()
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadStats()
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "weekComparator" {
                    WeekComparatorView()
                } else if destination == "simulator" {
                    SimulatorView()
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func card<Content: View>(accent: Bool = false, accentOrange: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                accent ? Color.stravaOrange.opacity(0.1) :
                accentOrange ? Color.orange.opacity(0.1) :
                Color(.secondarySystemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Activity.self, ActivityLap.self, ActivitySplit.self, SyncState.self,
        RunnerProfile.self, PostActivityReflection.self,
        configurations: config
    )
    return IntelligenceView(viewModel: DashboardViewModel())
        .modelContainer(container)
}
