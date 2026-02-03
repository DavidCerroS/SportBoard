//
//  SimulatorView.swift
//  SportBoardApp
//
//  Simulador "qué pasa si…": días/semana, ± volumen, nº sesiones duras.
//

import SwiftUI
import SwiftData

struct SimulatorView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var daysPerWeek: Int = 4
    @State private var volumeChangePercent: Double = 0
    @State private var hardSessionsPerWeek: Int = 1
    @State private var currentDays: Int = 0
    @State private var currentVolumeHours: Double = 0
    @State private var currentHard: Int = 0
    @State private var result: SimulatorResult?
    
    var body: some View {
        List {
            Section("Situación actual (esta semana)") {
                LabeledContent("Días entrenando", value: "\(currentDays)")
                LabeledContent("Volumen", value: String(format: "%.1f h", currentVolumeHours))
                LabeledContent("Sesiones duras", value: "\(currentHard)")
            }
            Section("Simular") {
                Stepper("Días/semana: \(daysPerWeek)", value: $daysPerWeek, in: 1...7)
                VStack(alignment: .leading) {
                    Text("Cambio de volumen: \(Int(volumeChangePercent))%")
                    Slider(value: $volumeChangePercent, in: -30...30, step: 5)
                }
                Stepper("Sesiones duras/semana: \(hardSessionsPerWeek)", value: $hardSessionsPerWeek, in: 0...5)
                Button("Calcular impacto") {
                    runSimulation()
                }
            }
            if let r = result {
                Section("Resultado") {
                    LabeledContent("Consistencia", value: r.consistencyImpact)
                    LabeledContent("Riesgo", value: r.riskLevel)
                    LabeledContent("Tendencia esperada", value: r.trendExpectation)
                    ForEach(r.reasons, id: \.self) { reason in
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Simulador")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentMetrics()
        }
    }
    
    private func loadCurrentMetrics() {
        let metrics = try? SimulatorService.currentMetrics(modelContext: modelContext)
        currentDays = metrics?.daysPerWeek ?? 0
        currentVolumeHours = metrics?.volumeHoursPerWeek ?? 0
        currentHard = metrics?.hardSessionsPerWeek ?? 0
        daysPerWeek = currentDays > 0 ? currentDays : 4
        hardSessionsPerWeek = currentHard
    }
    
    private func runSimulation() {
        result = SimulatorService.simulate(
            currentDaysPerWeek: currentDays,
            currentVolumeHoursPerWeek: currentVolumeHours,
            currentHardSessionsPerWeek: currentHard,
            input: SimulatorInput(
                daysPerWeek: daysPerWeek,
                volumeChangePercent: volumeChangePercent,
                hardSessionsPerWeek: hardSessionsPerWeek
            )
        )
    }
}
