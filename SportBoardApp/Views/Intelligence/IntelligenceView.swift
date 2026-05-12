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
                    intelligenceHero

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
                        NavigationLink(value: "activityComparator") {
                            toolRow("Comparar entrenos", icon: "arrow.left.arrow.right.circle")
                        }
                        NavigationLink(value: "weekComparator") {
                            toolRow("Comparar semanas", icon: "calendar.badge.clock")
                        }
                        NavigationLink(value: "simulator") {
                            toolRow("Simulador", icon: "slider.horizontal.3")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .premiumCard(accent: SportBoardTheme.Palette.violet.opacity(0.5))
                    
                    // Si no hay nada que mostrar
                    if viewModel.silentAlerts.isEmpty
                        && viewModel.weeklyNarrative.isEmpty
                        && viewModel.consistencyBreakdown == nil
                        && viewModel.fatigueDiagnosis == nil
                        && viewModel.nextWorkoutSuggestion == nil
                        && (viewModel.suspiciousPeak?.detected != true) {
                        Text("Sincroniza actividades de carrera para ver insights.")
                            .font(.subheadline)
                            .foregroundStyle(SportBoardTheme.Palette.mutedText)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                            .premiumCard()
                    }
                }
                .padding()
            }
            .premiumScreenBackground()
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                viewModel.loadStats()
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadStats()
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "activityComparator" {
                    ActivityComparisonView()
                } else if destination == "weekComparator" {
                    WeekComparatorView()
                } else if destination == "simulator" {
                    SimulatorView()
                }
            }
        }
    }

    private var intelligenceHero: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(SportBoardTheme.Palette.violet)
                .frame(width: 58, height: 58)
                .background(SportBoardTheme.Palette.violet.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text("Inteligencia de entrenamiento")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)

                Text("Alertas, fatiga y recomendaciones explicadas sin ruido.")
                    .font(.subheadline)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
            }

            Spacer()
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, accent: SportBoardTheme.Palette.violet, isElevated: true)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(SportBoardTheme.Palette.accent)
                .frame(width: 28)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func card<Content: View>(accent: Bool = false, accentOrange: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard(
                cornerRadius: SportBoardTheme.Radius.medium,
                accent: accent ? Color.stravaOrange : (accentOrange ? SportBoardTheme.Palette.warning : nil)
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
    return IntelligenceView(viewModel: DashboardViewModel())
        .modelContainer(container)
}
