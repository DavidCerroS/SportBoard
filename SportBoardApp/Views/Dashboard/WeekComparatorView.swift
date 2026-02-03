//
//  WeekComparatorView.swift
//  SportBoardApp
//
//  Comparador de semanas: elegir Semana A y Semana B manualmente (solo semanas con al menos 1 Run).
//

import SwiftUI
import SwiftData

struct WeekComparatorView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var availableWeeks: [WeekSummary] = []
    @State private var selectedWeekA: WeekSummary?
    @State private var selectedWeekB: WeekSummary?
    @State private var comparisonInsights: [String] = []
    @State private var profile: RunnerProfile?
    
    private static let weekLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d/M/yyyy"
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = TimeZone(identifier: "Europe/Madrid")
        return f
    }()
    
    var body: some View {
        List {
            if availableWeeks.isEmpty {
                Section {
                    Text("No hay semanas con actividad de carrera.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Semana A") {
                    Picker("Semana A", selection: Binding(
                        get: { selectedWeekA?.id ?? Date.distantPast },
                        set: { newId in selectedWeekA = availableWeeks.first { $0.id == newId } }
                    )) {
                        ForEach(availableWeeks) { summary in
                            Text(weekLabel(summary))
                                .tag(summary.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedWeekA?.id) { _, _ in recomputeComparison() }
                    if let a = selectedWeekA {
                        LabeledContent("Distancia", value: a.formattedDistance)
                        LabeledContent("Tiempo", value: a.formattedTime)
                        LabeledContent("Sesiones", value: "\(a.sessionCount)")
                    }
                }
                Section("Semana B") {
                    Picker("Semana B", selection: Binding(
                        get: { selectedWeekB?.id ?? Date.distantPast },
                        set: { newId in selectedWeekB = availableWeeks.first { $0.id == newId } }
                    )) {
                        ForEach(availableWeeks) { summary in
                            Text(weekLabel(summary))
                                .tag(summary.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedWeekB?.id) { _, _ in recomputeComparison() }
                    if let b = selectedWeekB {
                        LabeledContent("Distancia", value: b.formattedDistance)
                        LabeledContent("Tiempo", value: b.formattedTime)
                        LabeledContent("Sesiones", value: "\(b.sessionCount)")
                    }
                }
                if !comparisonInsights.isEmpty {
                    Section("Comparación") {
                        ForEach(comparisonInsights, id: \.self) { insight in
                            Text(insight)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Comparar semanas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
    }
    
    private func weekLabel(_ summary: WeekSummary) -> String {
        "\(Self.weekLabelFormatter.string(from: summary.weekStart)) (\(summary.sessionCount) sesiones)"
    }
    
    private func loadData() {
        profile = try? RunnerProfileService.fetchProfile(modelContext: modelContext)
        var past = (try? WeekComparatorService.fetchPastWeekSummaries(modelContext: modelContext, profile: profile)) ?? []
        let activities = (try? modelContext.fetch(FetchDescriptor<Activity>())) ?? []
        let current = WeekComparatorService.weekSummary(for: Date(), activities: activities, profile: profile)
        if current.sessionCount >= 1 {
            past.insert(current, at: 0)
        }
        availableWeeks = past
        selectedWeekA = availableWeeks.first
        selectedWeekB = availableWeeks.dropFirst().first
        recomputeComparison()
    }
    
    private func recomputeComparison() {
        guard let a = selectedWeekA, let b = selectedWeekB else {
            comparisonInsights = []
            return
        }
        if a.id == b.id {
            comparisonInsights = ["Elige dos semanas distintas para comparar."]
            return
        }
        comparisonInsights = WeekComparatorService.compare(current: a, reference: b)
    }
}
