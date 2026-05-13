//
//  IntelligenceView.swift
//  SportBoardApp
//

import SwiftUI
import SwiftData

struct IntelligenceView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: DashboardViewModel

    @State private var isDiagnosisExpanded = false
    @State private var showImportPlan = false

    private var readiness: TrainingReadiness? {
        viewModel.trainingReadiness
    }

    private var racePreparation: RacePreparation? {
        viewModel.racePreparation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let racePreparation, let readiness {
                        RaceGoalHero(preparation: racePreparation, readiness: readiness)
                        RacePlanDecisionCard(preparation: racePreparation)
                        RaceWeekPlanSection(preparation: racePreparation)
                        CoachSignalBoard(readiness: readiness)
                        CoachDiagnosisPanel(
                            readiness: readiness,
                            profile: viewModel.profile,
                            consistency: viewModel.consistencyBreakdown,
                            fatigue: viewModel.fatigueDiagnosis,
                            efficiencyTrend: viewModel.efficiencyTrend,
                            isExpanded: $isDiagnosisExpanded
                        )
                    } else if let readiness {
                        CoachReadinessHero(readiness: readiness)
                        CoachNextMoveCard(readiness: readiness)
                        CoachSignalBoard(readiness: readiness)
                    } else {
                        CoachEmptyState()
                    }

                    CoachLabSection()
                }
                .padding()
            }
            .premiumScreenBackground()
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImportPlan = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Importar plan mensual")
                }
            }
            .sheet(isPresented: $showImportPlan) {
                ImportMonthlyPlanView {
                    viewModel.loadStats()
                }
                .presentationBackground(SportBoardTheme.Palette.backgroundBottom)
            }
            .refreshable {
                viewModel.loadStats()
            }
            .task {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadStats()
            }
            .navigationDestination(for: CoachTool.self) { tool in
                switch tool {
                case .activityComparator:
                    ActivityComparisonView()
                case .weekComparator:
                    WeekComparatorView()
                case .simulator:
                    SimulatorView()
                }
            }
        }
    }
}

private struct ImportMonthlyPlanView: View {
    @Environment(\.dismiss) private var dismiss

    let onImport: () -> Void

    @State private var planText = RacePreparationService.standardPlanTemplate
    @State private var errorMessage: String?
    @State private var didImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Formato JSON mensual")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Pega un plan con month, objective, weeks y workouts. Los tipos validos son recovery, intervals, tempo, longRun, race y rest. Prioridades: low, medium, high, key.")
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $planText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
                            .stroke(SportBoardTheme.Palette.hairline, lineWidth: 1)
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if didImport {
                    Text("Plan importado correctamente.")
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .premiumScreenBackground()
            .navigationTitle("Importar plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") {
                        importPlan()
                    }
                }
            }
        }
    }

    private func importPlan() {
        do {
            try RacePreparationService.importMonthlyPlan(from: planText)
            errorMessage = nil
            didImport = true
            onImport()
        } catch {
            didImport = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo importar el plan."
        }
    }
}

private enum CoachTool: Hashable {
    case activityComparator
    case weekComparator
    case simulator
}

private struct CoachExplainedBadge: View {
    let title: String
    let value: String
    let color: Color
    let explanation: String

    @State private var showExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.smooth(duration: 0.22)) {
                    showExplanation.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SportBoardTheme.Palette.dimText)
                            .textCase(.uppercase)

                        Image(systemName: showExplanation ? "info.circle.fill" : "info.circle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(color)
                            .accessibilityHidden(true)
                    }

                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title): \(value). Toca para ver explicacion.")

            if showExplanation {
                HStack(spacing: 5) {
                    Rectangle()
                        .fill(color.opacity(0.55))
                        .frame(width: 2)
                        .clipShape(Capsule())
                        .accessibilityHidden(true)

                    Text(explanation)
                        .font(.caption2)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(showExplanation ? 0.18 : 0.13), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
                .stroke(color.opacity(showExplanation ? 0.55 : 0.35), lineWidth: 1)
        )
    }
}

private struct CoachInlineInfoButton: View {
    let isExpanded: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: isExpanded ? "info.circle.fill" : "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(isExpanded ? 0.18 : 0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Ocultar explicacion" : "Mostrar explicacion")
    }
}

private struct CoachInlineExplanation: View {
    let message: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption)
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous)
                .stroke(color.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct RaceGoalHero: View {
    let preparation: RacePreparation
    let readiness: TrainingReadiness

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(phaseColor.opacity(0.22), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: phaseProgress)
                        .stroke(
                            phaseColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(preparation.daysToRace)")
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .foregroundStyle(.white)
                        Text("dias")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SportBoardTheme.Palette.dimText)
                    }
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Objetivo")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(phaseColor)

                    Text("\(preparation.goal.name) · \(preparation.goal.distanceName)")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(raceDateText) · Fase \(preparation.phase.title.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                }

                Spacer(minLength: 0)
            }

            Text("Foco: \(preparation.phase.focus)")
                .font(.subheadline)
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                CoachExplainedBadge(
                    title: "Readiness",
                    value: "\(readiness.score)/100",
                    color: readinessColor,
                    explanation: readinessExplanation
                )
                CoachExplainedBadge(
                    title: "Semana",
                    value: "\(preparation.weekStatus.completed)/\(preparation.weekStatus.planned)",
                    color: SportBoardTheme.Palette.aqua,
                    explanation: preparation.weekStatus.message
                )
                CoachExplainedBadge(
                    title: "Riesgo",
                    value: readiness.riskLevel.title,
                    color: readinessColor,
                    explanation: riskExplanation
                )
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 22, accent: phaseColor, isElevated: true)
    }

    private var phaseColor: Color {
        switch preparation.phase {
        case .base:
            return SportBoardTheme.Palette.aqua
        case .build:
            return SportBoardTheme.Palette.electricBlue
        case .specific:
            return SportBoardTheme.Palette.violet
        case .taper, .raceWeek:
            return SportBoardTheme.Palette.warning
        case .completed:
            return SportBoardTheme.Palette.success
        }
    }

    private var readinessColor: Color {
        switch readiness.riskLevel {
        case .low:
            return SportBoardTheme.Palette.success
        case .moderate:
            return SportBoardTheme.Palette.warning
        case .high:
            return SportBoardTheme.Palette.danger
        }
    }

    private var phaseProgress: CGFloat {
        let totalDays = 180.0
        let elapsed = max(0, totalDays - Double(preparation.daysToRace))
        return CGFloat(min(1, max(0.04, elapsed / totalDays)))
    }

    private var raceDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: preparation.goal.raceDate)
    }

    private var readinessExplanation: String {
        readiness.explanation.joined(separator: " ")
    }

    private var riskExplanation: String {
        switch readiness.riskLevel {
        case .low:
            return "Riesgo bajo porque no hay alertas fuertes y la fatiga actual permite ejecutar el plan con normalidad."
        case .moderate:
            return "Riesgo moderado: el plan sigue en pie, pero alguna señal recomienda controlar volumen, intensidad o recuperacion."
        case .high:
            return "Riesgo alto: la prioridad es recortar o descansar para no comprometer la preparacion de la media maraton."
        }
    }
}

private struct RacePlanDecisionCard: View {
    let preparation: RacePreparation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Decision del plan")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(color)

                    Text(preparation.decision.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(preparation.decision.recommendation)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(preparation.decision.reason)
                .font(.subheadline)
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            if let workout = preparation.todayWorkout ?? preparation.nextWorkout {
                HStack(spacing: 10) {
                    decisionMetric(dayText(for: workout.date), "Dia")
                    decisionMetric(workout.priority.title, "Prioridad")
                    decisionMetric("\(workout.minDuration)-\(workout.maxDuration)'", "Volumen")
                }
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 20, accent: color, isElevated: true)
    }

    private var color: Color {
        switch preparation.decision.severity {
        case .green:
            return SportBoardTheme.Palette.success
        case .blue:
            return SportBoardTheme.Palette.aqua
        case .yellow:
            return SportBoardTheme.Palette.warning
        case .red:
            return SportBoardTheme.Palette.danger
        }
    }

    private var iconName: String {
        switch preparation.decision.severity {
        case .green:
            return "checkmark.seal.fill"
        case .blue:
            return "arrow.triangle.branch"
        case .yellow:
            return "exclamationmark.triangle.fill"
        case .red:
            return "hand.raised.fill"
        }
    }

    private func decisionMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
    }

    private func dayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }
}

private struct RaceWeekPlanSection: View {
    let preparation: RacePreparation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Semana actual")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(preparation.weekStatus.message)
                        .font(.subheadline)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }

                ProgressView(value: preparation.weekStatus.progress)
                    .tint(SportBoardTheme.Palette.accent)
            }
            .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14, accent: SportBoardTheme.Palette.accent.opacity(0.4))

            ForEach(preparation.weekPlan) { workout in
                RaceWorkoutRow(
                    workout: workout,
                    isCompleted: preparation.completedWorkoutIDs.contains(workout.id),
                    isNext: workout.id == preparation.nextWorkout?.id
                )
            }
        }
    }
}

private struct RaceWorkoutRow: View {
    let workout: PlannedWorkout
    let isCompleted: Bool
    let isNext: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : workout.type.icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(rowColor)
                .frame(width: 38, height: 38)
                .background(rowColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("\(weekdayText) · \(workout.title)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if isNext {
                        Text("Siguiente")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(SportBoardTheme.Palette.accent.opacity(0.85), in: Capsule())
                    }
                }

                Text(workout.prescription)
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)

                Text(workout.intent)
                    .font(.caption2)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14, accent: rowColor.opacity(isNext ? 0.75 : 0.35))
    }

    private var rowColor: Color {
        if isCompleted { return SportBoardTheme.Palette.success }
        if isNext { return SportBoardTheme.Palette.accent }
        switch workout.priority {
        case .low:
            return SportBoardTheme.Palette.aqua
        case .medium:
            return SportBoardTheme.Palette.electricBlue
        case .high:
            return SportBoardTheme.Palette.warning
        case .key:
            return SportBoardTheme.Palette.violet
        }
    }

    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEE"
        return formatter.string(from: workout.date).capitalized
    }
}

private struct CoachReadinessHero: View {
    let readiness: TrainingReadiness

    @State private var showReadinessExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(heroColor.opacity(0.24), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(readiness.score) / 100)
                        .stroke(
                            heroColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("\(readiness.score)")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Estado actual")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(heroColor)

                        CoachInlineInfoButton(isExpanded: showReadinessExplanation, color: heroColor) {
                            withAnimation(.smooth(duration: 0.22)) {
                                showReadinessExplanation.toggle()
                            }
                        }
                    }

                    Text(readiness.state.title)
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(readiness.state.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    if showReadinessExplanation {
                        CoachInlineExplanation(message: readiness.explanation.joined(separator: " "), color: heroColor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                CoachExplainedBadge(
                    title: "Riesgo",
                    value: readiness.riskLevel.title,
                    color: riskColor,
                    explanation: riskExplanation
                )
                CoachExplainedBadge(
                    title: "Decisión",
                    value: decisionLabel,
                    color: heroColor,
                    explanation: readiness.explanation.joined(separator: " ")
                )
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 22, accent: heroColor, isElevated: true)
    }

    private var heroColor: Color {
        switch readiness.state {
        case .ready:
            return SportBoardTheme.Palette.success
        case .keepEasy:
            return SportBoardTheme.Palette.aqua
        case .caution:
            return SportBoardTheme.Palette.warning
        case .recover:
            return SportBoardTheme.Palette.danger
        case .insufficientData:
            return SportBoardTheme.Palette.dimText
        }
    }

    private var riskColor: Color {
        switch readiness.riskLevel {
        case .low:
            return SportBoardTheme.Palette.success
        case .moderate:
            return SportBoardTheme.Palette.warning
        case .high:
            return SportBoardTheme.Palette.danger
        }
    }

    private var decisionLabel: String {
        readiness.recommendation?.type ?? "Calibrar"
    }

    private var riskExplanation: String {
        switch readiness.riskLevel {
        case .low:
            return "Riesgo bajo porque las señales de fatiga, consistencia y alertas permiten entrenar con normalidad."
        case .moderate:
            return "Riesgo moderado: puedes entrenar, pero la app recomienda controlar la carga por las señales actuales."
        case .high:
            return "Riesgo alto: las señales recomiendan recuperar primero antes de meter otra sesion exigente."
        }
    }
}

private struct CoachNextMoveCard: View {
    let readiness: TrainingReadiness

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SportBoardTheme.Palette.accent)
                    .frame(width: 42, height: 42)
                    .background(SportBoardTheme.Palette.accent.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Próximo movimiento")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(SportBoardTheme.Palette.accent)

                    Text(readiness.recommendation?.type ?? "Sin recomendación todavía")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)
            }

            if let suggestion = readiness.recommendation {
                HStack(spacing: 10) {
                    moveMetric("\(suggestion.durationMin)-\(suggestion.durationMax)'", "Duración")
                    moveMetric(suggestion.intensity.capitalized, "Intensidad")
                }

                Text(suggestion.reason)
                    .font(.subheadline)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .fixedSize(horizontal: false, vertical: true)

                FlowChips(labels: chips(for: suggestion))
            } else {
                Text("Sincroniza más carreras comparables para que el coach pueda decidir con contexto.")
                    .font(.subheadline)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 20, accent: SportBoardTheme.Palette.accent, isElevated: true)
    }

    private func moveMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(title)
                .font(.caption)
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
    }

    private func chips(for suggestion: NextWorkoutSuggestion) -> [String] {
        var labels = ["Terreno llano", "Sin forzar"]
        if suggestion.intensity.lowercased().contains("fácil") {
            labels.append("Z2")
        }
        if suggestion.type.lowercased().contains("recuper") {
            labels.append("Recuperación")
        } else {
            labels.append("Base")
        }
        return labels
    }
}

private struct CoachSignalBoard: View {
    let readiness: TrainingReadiness

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Señales")

            if readiness.signals.isEmpty {
                CoachSignalRow(
                    signal: TrainingSignal(
                        id: "empty",
                        title: "Sin señales relevantes",
                        message: "No hay alertas ni cambios fuertes en las métricas actuales.",
                        severity: .positive,
                        category: .opportunity
                    )
                )
            } else {
                ForEach(readiness.signals) { signal in
                    CoachSignalRow(signal: signal)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CoachSignalRow: View {
    let signal: TrainingSignal

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(signal.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    Text(signal.message)
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                CoachInlineInfoButton(isExpanded: isExpanded, color: color) {
                    withAnimation(.smooth(duration: 0.22)) {
                        isExpanded.toggle()
                    }
                }
            }

            if isExpanded {
                CoachInlineExplanation(message: signalExplanation, color: color)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14, accent: color.opacity(isExpanded ? 0.7 : 0.45))
    }

    private var iconName: String {
        switch signal.category {
        case .load:
            return "chart.line.uptrend.xyaxis"
        case .recovery:
            return "figure.cooldown"
        case .consistency:
            return "calendar.badge.checkmark"
        case .efficiency:
            return "speedometer"
        case .data:
            return "waveform.path.ecg"
        case .opportunity:
            return "sparkles"
        }
    }

    private var color: Color {
        switch signal.severity {
        case .positive:
            return SportBoardTheme.Palette.success
        case .neutral:
            return SportBoardTheme.Palette.aqua
        case .warning:
            return SportBoardTheme.Palette.warning
        case .critical:
            return SportBoardTheme.Palette.danger
        }
    }

    private var signalExplanation: String {
        "\(signal.message) \(severityExplanation) \(categoryExplanation)"
    }

    private var severityExplanation: String {
        switch signal.severity {
        case .positive:
            return "La lectura es positiva y suma confianza al plan."
        case .neutral:
            return "Es una señal informativa: no cambia el plan por si sola."
        case .warning:
            return "Es una señal de aviso: no obliga a parar, pero pide controlar la carga."
        case .critical:
            return "Es una señal fuerte: conviene recortar antes de acumular mas fatiga."
        }
    }

    private var categoryExplanation: String {
        switch signal.category {
        case .load:
            return "Sale de la carga reciente y las alertas generadas por tus entrenamientos."
        case .recovery:
            return "Sale del diagnostico de fatiga: carga aguda, intensidad reciente, impacto mecanico y sensaciones si existen."
        case .consistency:
            return "Sale de tu continuidad semanal y de cuantas semanas vienes sosteniendo rutina."
        case .efficiency:
            return "Sale de comparar rendimiento en carreras parecidas: ritmo, pulso y tendencia."
        case .data:
            return "Sale de la calidad y cantidad de datos disponibles para calibrarte."
        case .opportunity:
            return "Sale de una oportunidad o cambio relevante detectado en el historial."
        }
    }
}

private struct CoachDiagnosisPanel: View {
    let readiness: TrainingReadiness
    let profile: RunnerProfile?
    let consistency: ConsistencyBreakdown?
    let fatigue: FatigueDiagnosis?
    let efficiencyTrend: EfficiencyTrendResult?
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.smooth(duration: 0.24)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Diagnóstico")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SportBoardTheme.Palette.dimText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                diagnosisMetric("Fatiga", fatigue?.formattedScorePercent ?? "--", color: fatigueColor)
                diagnosisMetric("Consistencia", consistency.map { "\($0.score)" } ?? "--", color: SportBoardTheme.Palette.aqua)
                diagnosisMetric("Perfil", profileConfidence, color: SportBoardTheme.Palette.violet)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(readiness.explanation, id: \.self) { line in
                        explanationLine(line)
                    }

                    if let trend = efficiencyTrend {
                        Divider()
                            .overlay(SportBoardTheme.Palette.hairline)

                        explanationLine(trend.reasons.joined(separator: ". "))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 18, accent: SportBoardTheme.Palette.violet.opacity(0.45))
    }

    private var fatigueColor: Color {
        guard let fatigue else { return SportBoardTheme.Palette.dimText }
        switch fatigue.level {
        case .low:
            return SportBoardTheme.Palette.success
        case .medium:
            return SportBoardTheme.Palette.warning
        case .high:
            return SportBoardTheme.Palette.danger
        }
    }

    private var profileConfidence: String {
        guard let profile else { return "--" }
        return "\(Int((profile.confidence * 100).rounded()))%"
    }

    private func diagnosisMetric(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    private func explanationLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundStyle(SportBoardTheme.Palette.dimText)
                .accessibilityHidden(true)

            Text(text)
                .font(.caption)
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CoachLabSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Laboratorio")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                NavigationLink(value: CoachTool.activityComparator) {
                    labRow(
                        "Comparar entrenos",
                        subtitle: "Comprueba si una sesión fue realmente mejor que otra similar.",
                        icon: "arrow.left.arrow.right.circle"
                    )
                }

                NavigationLink(value: CoachTool.weekComparator) {
                    labRow(
                        "Comparar semanas",
                        subtitle: "Separa mejora real de simplemente más volumen.",
                        icon: "calendar.badge.clock"
                    )
                }

                NavigationLink(value: CoachTool.simulator) {
                    labRow(
                        "Simulador",
                        subtitle: "Prueba cambios de días, volumen e intensidad antes de hacerlos.",
                        icon: "slider.horizontal.3"
                    )
                }
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, accent: SportBoardTheme.Palette.violet.opacity(0.5))
    }

    private func labRow(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.accent)
                .frame(width: 38, height: 38)
                .background(SportBoardTheme.Palette.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct CoachEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(SportBoardTheme.Palette.violet)

            Text("Coach pendiente de datos")
                .font(.title2.weight(.black))
                .foregroundStyle(.white)

            Text("Sincroniza varias carreras para calibrar ritmo cómodo, consistencia, fatiga y tendencia.")
                .font(.subheadline)
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, accent: SportBoardTheme.Palette.violet, isElevated: true)
    }
}

private struct FlowChips: View {
    let labels: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SportBoardTheme.Palette.accent.opacity(0.18), in: Capsule())
            }
        }
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
