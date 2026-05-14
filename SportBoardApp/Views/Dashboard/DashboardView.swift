//
//  DashboardView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI
import SwiftData

enum DashboardHeroExpandedMetric: Hashable {
    case distance
    case sessions
    case duration
    case heartRate
    case power
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: DashboardViewModel
    @ObservedObject var syncViewModel: SyncViewModel
    
    @State private var activeSheet: DashboardSheet?
    @State private var isLegFatigueExpanded = false
    @State private var expandedHeroMetric: DashboardHeroExpandedMetric?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DashboardHeroView(
                        viewModel: viewModel,
                        legFatigueExpanded: $isLegFatigueExpanded,
                        expandedHeroMetric: $expandedHeroMetric
                    ) {
                        syncViewModel.startSync()
                        activeSheet = .syncProgress
                    }

                    VStack(spacing: 20) {
                    // Sync Progress (si está activo)
                    if syncViewModel.isActive || syncViewModel.isPaused {
                        SyncProgressCompactView(viewModel: syncViewModel)
                            .onTapGesture {
                                activeSheet = .syncProgress
                            }
                    }

                    DashboardNextActionSection(viewModel: viewModel)
                    
                    // Actividades recientes
                    if !viewModel.recentActivities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actividades Recientes")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            
                            ForEach(viewModel.recentActivities, id: \.id) { activity in
                                NavigationLink(value: activity) {
                                    RecentActivityRow(activity: activity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isLegFatigueExpanded = false
                        expandedHeroMetric = nil
                    }
                }
                .padding()
            }
            .premiumScreenBackground()
            .navigationTitle("SportBoard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        syncViewModel.startSync()
                        activeSheet = .syncProgress
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel("Sincronizar")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: "settings") {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Ajustes")
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
            .sheet(item: $activeSheet, onDismiss: {
                viewModel.loadStats()
            }) { sheet in
                switch sheet {
                case .syncProgress:
                    SyncProgressView(viewModel: syncViewModel)
                        .presentationBackground(SportBoardTheme.Palette.backgroundBottom)
                        .presentationDetents([.medium])
                }
            }
            .task {
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

private enum DashboardSheet: Hashable, Identifiable {
    case syncProgress

    var id: Self { self }
}

// MARK: - Dashboard Hero

struct DashboardHeroView: View {
    @Bindable var viewModel: DashboardViewModel
    @Binding var legFatigueExpanded: Bool
    @Binding var expandedHeroMetric: DashboardHeroExpandedMetric?
    let syncAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Así va tu semana")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(SportBoardTheme.Palette.accent)
                        .textCase(.uppercase)

                    Text("Resumen semanal")
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .foregroundStyle(.white)

                    Text("Distancia y sesiones acumuladas hasta ahora.")
                        .font(.subheadline)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    legFatigueExpanded = false
                    expandedHeroMetric = nil
                }

                Spacer()

                Button(action: syncAction) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(SportBoardTheme.accentGradient, in: Circle())
                }
                .shadow(color: SportBoardTheme.Palette.glow, radius: 18, y: 8)
            }

            VStack(spacing: 12) {
                expandableWeekMetricCell(
                    kind: .distance,
                    title: "Distancia semanal",
                    headline: viewModel.formattedThisWeekDistance,
                    icon: "figure.run",
                    subtitle: "\(viewModel.thisWeekActivities) carreras"
                )

                expandableWeekMetricCell(
                    kind: .sessions,
                    title: "Sesiones",
                    headline: "\(viewModel.thisWeekActivities)",
                    icon: "calendar",
                    subtitle: "Cuenta de salidas esta semana"
                )

                expandableWeekMetricCell(
                    kind: .duration,
                    title: "Tiempo en movimiento",
                    headline: viewModel.formattedThisWeekTime,
                    icon: "clock.fill",
                    subtitle: "Suma entre sesiones"
                )

                if let heartRate = viewModel.formattedThisWeekAverageHeartrate {
                    expandableWeekMetricCell(
                        kind: .heartRate,
                        title: "FC media",
                        headline: heartRate,
                        icon: "heart.fill",
                        subtitle: "Por sesiones con pulsómetro"
                    )
                }

                if let power = viewModel.formattedThisWeekAveragePower {
                    expandableWeekMetricCell(
                        kind: .power,
                        title: "Potencia media",
                        headline: power,
                        icon: "bolt.fill",
                        subtitle: "Por sesiones con medidor"
                    )
                }

                if let diagnosis = viewModel.fatigueDiagnosis, let pct = viewModel.formattedCurrentLegFatigue {
                    expandableLegFatigueCell(diagnosis: diagnosis, percentText: pct)
                }
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 22, accent: Color.stravaOrange, isElevated: true)
    }

    private func expandableWeekMetricCell(
        kind: DashboardHeroExpandedMetric,
        title: String,
        headline: String,
        icon: String,
        subtitle: String
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
        let isOpen = expandedHeroMetric == kind

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.smooth(duration: 0.28)) {
                    if isOpen {
                        expandedHeroMetric = nil
                    } else {
                        expandedHeroMetric = kind
                        legFatigueExpanded = false
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(SportBoardTheme.Palette.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SportBoardTheme.Palette.dimText)

                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(SportBoardTheme.Palette.dimText.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SportBoardTheme.Palette.dimText)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .animation(.smooth(duration: 0.22), value: isOpen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                weekRunsExpandedDetail(kind: kind)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(.white.opacity(isOpen ? 0.11 : 0.07), in: shape)
        .overlay(shape.stroke(Color.stravaOrange.opacity(isOpen ? 0.35 : 0), lineWidth: 1))
    }

    private func weekRunsExpandedDetail(kind: DashboardHeroExpandedMetric) -> some View {
        let runs = viewModel.thisWeekRunsSorted

        return VStack(alignment: .leading, spacing: 10) {
            if runs.isEmpty {
                Text("No hay carreras registradas esta semana (semana calendario: lunes a domingo, hora Europa/Madrid).")
                    .font(.footnote)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(detailLeadIn(for: kind))
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(runs.enumerated()), id: \.element.id) { pair in
                        weekRunRow(index: pair.offset + 1, kind: kind, activity: pair.element)

                        if pair.offset < runs.count - 1 {
                            Divider()
                                .overlay(SportBoardTheme.Palette.hairline.opacity(0.45))
                        }
                    }
                }
            }

            if !(runs.isEmpty && (kind == .heartRate || kind == .power)) {
                Divider()
                    .overlay(SportBoardTheme.Palette.hairline.opacity(0.6))
            }

            footnoteTotals(for: kind, runs: runs)
        }
    }

    private func detailLeadIn(for kind: DashboardHeroExpandedMetric) -> String {
        switch kind {
        case .distance:
            return "Km por cada salida (orden cronológico en la semana)."
        case .sessions:
            return "Mismo desglose: nombre de cada sesión."
        case .duration:
            return "Tiempo en movimiento de cada sesión."
        case .heartRate:
            return "Si la sesión no tiene FC aparece como «Sin datos»; la media superior solo cuenta sesiones con sensor."
        case .power:
            return "Potencia media por sesión donde exista medidor."
        }
    }

    @ViewBuilder
    private func footnoteTotals(for kind: DashboardHeroExpandedMetric, runs: [Activity]) -> some View {
        let count = runs.count
        switch kind {
        case .distance:
            let prefix = count == 1 ? "Esta salida coincide" : "Estas \(count) salidas suman"
            Text("\(prefix) el total \(viewModel.formattedThisWeekDistance).")
                .font(.caption)
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        case .sessions:
            Text("Total de salidas esta semana: \(count).")
                .font(.caption)
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        case .duration:
            Text("Suma indicada arriba: \(viewModel.formattedThisWeekTime).")
                .font(.caption)
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        case .heartRate:
            if count > 0, let avg = viewModel.formattedThisWeekAverageHeartrate {
                Text("Media semanal ponderada (\(avg)) usando solo sesiones con FC.")
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)
            }
        case .power:
            if count > 0, let avg = viewModel.formattedThisWeekAveragePower {
                Text("Media semanal ponderada (\(avg)) usando solo sesiones con vatios.")
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)
            }
        }
    }

    private func weekRunRow(index: Int, kind: DashboardHeroExpandedMetric, activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch kind {
            case .distance:
                Text("Sesión \(index) · \(activity.formattedDistance)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.92)
                    .lineLimit(2)
                Text(activity.name)
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .lineLimit(2)
                Text(activity.startDate.shortDateString)
                    .font(.caption2)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)

            case .sessions:
                Text("Sesión \(index) · \(activity.name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(activity.formattedDistance) · \(activity.formattedMovingTime)")
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                Text(activity.startDate.shortDateString)
                    .font(.caption2)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)

            case .duration:
                Text("Sesión \(index) · \(activity.formattedMovingTime)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(activity.formattedDistance) · \(activity.name)")
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .lineLimit(2)
                Text(activity.startDate.shortDateString)
                    .font(.caption2)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)

            case .heartRate:
                Text("Sesión \(index)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let hr = activity.averageHeartrate {
                    Text(hr.formattedHeartRate)
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                } else {
                    Text("Sin datos de FC")
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.dimText)
                }
                Text("\(activity.formattedDistance) · \(activity.startDate.shortDateString)")
                    .font(.caption2)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)

            case .power:
                Text("Sesión \(index)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let watts = activity.averageWatts {
                    Text(watts.formattedPower)
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                } else {
                    Text("Sin medidor")
                        .font(.caption)
                        .foregroundStyle(SportBoardTheme.Palette.dimText)
                }
                Text("\(activity.formattedDistance) · \(activity.startDate.shortDateString)")
                    .font(.caption2)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)
            }
        }
    }

    private func expandableLegFatigueCell(diagnosis: FatigueDiagnosis, percentText: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.smooth(duration: 0.28)) {
                    if !legFatigueExpanded {
                        expandedHeroMetric = nil
                    }
                    legFatigueExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(SportBoardTheme.Palette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(percentText)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        Text("Piernas")
                            .font(.caption)
                            .foregroundStyle(SportBoardTheme.Palette.dimText)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SportBoardTheme.Palette.dimText)
                        .rotationEffect(.degrees(legFatigueExpanded ? 180 : 0))
                        .animation(.smooth(duration: 0.22), value: legFatigueExpanded)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Muestra u oculta la explicación del porcentaje de fatiga de piernas.")

            if legFatigueExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Este valor resume fatiga muscular estimada desde tus últimas carreras: carga por tiempo e intensidad, ratio entre carga aguda y base habitual, proporción de sesiones duras, días seguidos, impacto de desnivel y ritmo, y tu reflexión post-entreno si la has registrado.")
                        .font(.footnote)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Estado: \(diagnosis.state.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Motivos")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SportBoardTheme.Palette.accent)

                    ForEach(diagnosis.causes, id: \.self) { cause in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(SportBoardTheme.Palette.dimText)
                                .accessibilityHidden(true)
                            Text(cause)
                                .font(.caption)
                                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        }
                    }

                    Divider()
                        .overlay(SportBoardTheme.Palette.hairline)

                    Text(diagnosis.recommendedAction)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(.white.opacity(legFatigueExpanded ? 0.11 : 0.07), in: shape)
        .overlay(shape.stroke(Color.stravaOrange.opacity(legFatigueExpanded ? 0.42 : 0), lineWidth: 1))
    }
}

// MARK: - Next Action

struct DashboardNextActionSection: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ahora")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if hasActionableContent {
                if let preparation = viewModel.racePreparation {
                    DashboardInsightCard(
                        title: "Próximo entreno",
                        message: nextWorkoutMessage(for: preparation),
                        icon: "figure.run.circle.fill",
                        color: decisionColor(for: preparation.decision)
                    )
                } else if let suggestion = viewModel.nextWorkoutSuggestion {
                    DashboardInsightCard(
                        title: "Próximo entreno",
                        message: suggestion.fullText,
                        icon: "figure.run.circle.fill",
                        color: SportBoardTheme.Palette.success
                    )
                }

                if let readiness = viewModel.trainingReadiness {
                    DashboardInsightCard(
                        title: "Estado de carga",
                        message: readinessMessage(for: readiness),
                        icon: "gauge.with.dots.needle.67percent",
                        color: readinessColor(for: readiness)
                    )
                }

                if let alert = viewModel.silentAlerts.first {
                    DashboardInsightCard(
                        title: alert.title,
                        message: alert.message,
                        icon: "exclamationmark.triangle.fill",
                        color: SportBoardTheme.Palette.warning
                    )
                }

                if viewModel.trainingReadiness == nil, let fatigue = viewModel.fatigueDiagnosis {
                    DashboardInsightCard(
                        title: "Estado de carga",
                        message: fatigue.recommendedAction,
                        icon: "gauge.with.dots.needle.67percent",
                        color: fatigueColor(for: fatigue)
                    )
                } else if let consistency = viewModel.consistencyBreakdown {
                    DashboardInsightCard(
                        title: "Consistencia",
                        message: consistency.reasons.first ?? "Consistencia actual: \(consistency.score)/100.",
                        icon: "calendar.badge.checkmark",
                        color: SportBoardTheme.Palette.aqua
                    )
                }
            } else {
                DashboardInsightCard(
                    title: "Sin señal suficiente",
                    message: "Sincroniza actividades de carrera para ver recomendaciones y avisos accionables.",
                    icon: "waveform.path.ecg",
                    color: SportBoardTheme.Palette.dimText
                )
            }
        }
    }

    private var hasActionableContent: Bool {
        viewModel.racePreparation != nil
            || viewModel.trainingReadiness != nil
            || viewModel.nextWorkoutSuggestion != nil
            || !viewModel.silentAlerts.isEmpty
            || viewModel.fatigueDiagnosis != nil
            || viewModel.consistencyBreakdown != nil
    }

    private func nextWorkoutMessage(for preparation: RacePreparation) -> String {
        let workout = preparation.todayWorkout ?? preparation.nextWorkout
        let prefix = workout.map { "\(dayText(for: $0.date)) · \($0.title)" } ?? preparation.decision.title
        return "\(prefix). \(preparation.decision.recommendation) \(preparation.decision.reason)"
    }

    private func readinessMessage(for readiness: TrainingReadiness) -> String {
        let explanation = readiness.explanation.prefix(2).joined(separator: " ")
        return "Readiness \(readiness.score)/100 · Riesgo \(readiness.riskLevel.title.lowercased()). \(explanation)"
    }

    private func dayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }

    private func decisionColor(for decision: PlanAdjustmentDecision) -> Color {
        switch decision.severity {
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

    private func readinessColor(for readiness: TrainingReadiness) -> Color {
        switch readiness.riskLevel {
        case .low:
            return SportBoardTheme.Palette.success
        case .moderate:
            return SportBoardTheme.Palette.warning
        case .high:
            return SportBoardTheme.Palette.danger
        }
    }

    private func fatigueColor(for diagnosis: FatigueDiagnosis) -> Color {
        switch diagnosis.state {
        case .fresh, .normal:
            return SportBoardTheme.Palette.success
        case .fatigued:
            return SportBoardTheme.Palette.warning
        case .highFatigue:
            return SportBoardTheme.Palette.danger
        }
    }
}

private struct DashboardInsightCard: View {
    let title: String
    let message: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14, accent: color.opacity(0.45))
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
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14, accent: Color.sportColor(for: activity.sportType).opacity(0.45))
    }
}

// MARK: - Sport Filter Sheet

struct SportFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let sportTypes: [(sport: String, count: Int)]
    let selectedSport: String?
    let selectSport: (String?) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectSport(nil)
                    dismiss()
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
                        selectSport(item.sport)
                        dismiss()
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
            .scrollContentBackground(.hidden)
            .premiumScreenBackground()
            .navigationTitle("Filtrar por Deporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Activity.self, ActivityLap.self, ActivitySplit.self,
        ActivityZoneDistribution.self, ActivityStreamSummary.self, StravaGear.self, ActivitySegmentEffort.self,
        ActivityTempoBlockSplit.self,
        SyncState.self,
        RunnerProfile.self, PostActivityReflection.self,
        configurations: config
    )
    
    return DashboardView(
        viewModel: DashboardViewModel(),
        syncViewModel: SyncViewModel()
    )
    .modelContainer(container)
}
