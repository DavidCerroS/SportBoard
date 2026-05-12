//
//  ActivityComparisonView.swift
//  SportBoardApp
//
//  Pantalla para comparar dos entrenos de carrera similares.
//

import SwiftUI
import SwiftData

struct ActivityComparisonView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activities: [Activity] = []
    @State private var allActivities: [Activity] = []
    @State private var selectedFirstID: Int64?
    @State private var selectedSecondID: Int64?
    @State private var distanceFilter: DistanceFilter = .all

    init(initialFirstActivityID: Int64? = nil) {
        self._selectedFirstID = State(initialValue: initialFirstActivityID)
    }

    private static let activityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        return formatter
    }()

    private var selectedFirst: Activity? {
        activity(for: selectedFirstID)
    }

    private var selectedSecond: Activity? {
        activity(for: selectedSecondID)
    }

    private var comparison: ActivityComparison? {
        guard let selectedFirst, let selectedSecond else { return nil }
        return ActivityComparisonService.compare(selectedFirst, selectedSecond)
    }

    var body: some View {
        List {
            if activities.count < 2 {
                Section {
                    ContentUnavailableView(
                        "No hay suficientes carreras",
                        systemImage: "figure.run",
                        description: Text("Sincroniza al menos dos actividades de carrera para poder compararlas.")
                    )
                }
            } else {
                filterSection
                selectionSection

                if let comparison {
                    if !comparison.warnings.isEmpty {
                        warningSection(comparison.warnings)
                    }

                    summarySection(comparison)
                    metricsSection(comparison.metrics)
                    segmentsSection(comparison)
                }
            }
        }
        .navigationTitle("Comparar entrenos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadActivities)
        .refreshable {
            loadActivities()
        }
    }

    private var filterSection: some View {
        Section("Filtro rápido") {
            Picker("Distancia", selection: $distanceFilter) {
                ForEach(DistanceFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: distanceFilter) { _, newValue in
                applyFilters(using: newValue)
            }
        }
    }

    private var selectionSection: some View {
        Section("Selección") {
            Picker("Entreno A", selection: $selectedFirstID) {
                Text("Selecciona un entreno")
                    .tag(nil as Int64?)
                ForEach(activities, id: \.id) { activity in
                    Text(selectionLabel(for: activity))
                        .tag(Optional(activity.id))
                }
            }
            .pickerStyle(.menu)

            Picker("Entreno B", selection: $selectedSecondID) {
                Text("Selecciona un entreno")
                    .tag(nil as Int64?)
                ForEach(activities, id: \.id) { activity in
                    Text(selectionLabel(for: activity))
                        .tag(Optional(activity.id))
                }
            }
            .pickerStyle(.menu)

            if let selectedFirst {
                ActivityComparisonSelectionCard(
                    title: "A",
                    activity: selectedFirst,
                    sessionType: RunClassifier.classify(
                        activity: selectedFirst,
                        splits: selectedFirst.sortedSplits,
                        laps: selectedFirst.sortedLaps
                    ).type
                )
            }

            if let selectedSecond {
                ActivityComparisonSelectionCard(
                    title: "B",
                    activity: selectedSecond,
                    sessionType: RunClassifier.classify(
                        activity: selectedSecond,
                        splits: selectedSecond.sortedSplits,
                        laps: selectedSecond.sortedLaps
                    ).type
                )
            }
        }
    }

    private func warningSection(_ warnings: [String]) -> some View {
        Section("Avisos") {
            ForEach(warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func summarySection(_ comparison: ActivityComparison) -> some View {
        Section("Resumen") {
            LabeledContent("Tipo A", value: comparison.firstSessionType.displayName)
            LabeledContent("Tipo B", value: comparison.secondSessionType.displayName)

            ForEach(comparison.insights, id: \.self) { insight in
                Text(insight)
                    .font(.subheadline)
            }
        }
    }

    private func metricsSection(_ metrics: [ActivityComparisonMetric]) -> some View {
        Section("Métricas") {
            HStack {
                Text("Dato")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("A")
                    .frame(width: 76, alignment: .trailing)
                Text("B")
                    .frame(width: 76, alignment: .trailing)
                Text("Dif.")
                    .frame(width: 82, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(metrics) { metric in
                ActivityComparisonMetricRow(metric: metric)
            }
        }
    }

    private func segmentsSection(_ comparison: ActivityComparison) -> some View {
        Section(comparison.segmentSource.title) {
            if comparison.segments.isEmpty {
                Text("Estos entrenos no tienen parciales comparables.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(comparison.segments) { segment in
                    ActivityComparisonSegmentRow(segment: segment)
                }
            }
        }
    }

    private func loadActivities() {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        allActivities = ActivityComparisonService.sortedComparableActivities(from: fetched)
        applyFilters(using: distanceFilter)
    }

    private func applyFilters(using filter: DistanceFilter) {
        activities = allActivities.filter { filter.matches($0) }

        if selectedFirstID == nil || activity(for: selectedFirstID) == nil {
            selectedFirstID = activities.first?.id
        }
        if selectedSecondID == nil || activity(for: selectedSecondID) == nil || selectedSecondID == selectedFirstID {
            selectedSecondID = activities.first { $0.id != selectedFirstID }?.id
        }

        let matchingIDs = activities.map(\.id)
        print("[SportBoard][Comparison] filtro=\(filter.title) totalRuns=\(allActivities.count) matches=\(activities.count) selectedA=\(selectedFirstID.map(String.init) ?? "nil") selectedB=\(selectedSecondID.map(String.init) ?? "nil") ids=\(matchingIDs)")
    }

    private func activity(for id: Int64?) -> Activity? {
        guard let id else { return nil }
        return activities.first { $0.id == id }
    }

    private func selectionLabel(for activity: Activity) -> String {
        "\(Self.activityDateFormatter.string(from: activity.startDate)) · \(activity.name) · \(activity.formattedDistance)"
    }
}

private enum DistanceFilter: CaseIterable, Identifiable {
    case all
    case fiveK
    case tenK
    case halfMarathon
    case longRun

    var id: String { title }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .fiveK: return "5K"
        case .tenK: return "10K"
        case .halfMarathon: return "21K"
        case .longRun: return "Larga"
        }
    }

    func matches(_ activity: Activity) -> Bool {
        let km = activity.distance / 1_000
        switch self {
        case .all:
            return true
        case .fiveK:
            return (4.5...5.5).contains(km)
        case .tenK:
            return (9.0...11.0).contains(km)
        case .halfMarathon:
            return (20.0...22.5).contains(km)
        case .longRun:
            return km >= 14.0
        }
    }
}

private struct ActivityComparisonSelectionCard: View {
    let title: String
    let activity: Activity
    let sessionType: RunSessionType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Entreno \(title)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sessionType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.stravaOrange.opacity(0.15))
                    .clipShape(Capsule())
            }

            Text(activity.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            HStack(spacing: 12) {
                Label(activity.formattedDistance, systemImage: "ruler")
                Label(activity.formattedMovingTime, systemImage: "clock")
                Label(activity.formattedPace, systemImage: "speedometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ActivityComparisonMetricRow: View {
    let metric: ActivityComparisonMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(metric.firstValue)
                    .font(.caption)
                    .frame(width: 76, alignment: .trailing)
                Text(metric.secondValue)
                    .font(.caption)
                    .frame(width: 76, alignment: .trailing)
                Text(metric.differenceValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(metric.trend.color)
                    .frame(width: 82, alignment: .trailing)
            }

            if let detail = metric.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ActivityComparisonSegmentRow: View {
    let segment: ActivityComparisonSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(segment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(segment.paceDifference)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(segment.trend.color)
            }

            HStack(spacing: 12) {
                column("A", time: segment.firstTime, pace: segment.firstPace, heartRate: segment.firstHeartRate, power: segment.firstPower, elevation: segment.firstElevation)
                column("B", time: segment.secondTime, pace: segment.secondPace, heartRate: segment.secondHeartRate, power: segment.secondPower, elevation: segment.secondElevation)
            }

            Text("Tiempo: \(segment.timeDifference)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func column(
        _ title: String,
        time: String,
        pace: String,
        heartRate: String,
        power: String,
        elevation: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("\(time) · \(pace)")
                .font(.caption)
            Text("FC \(heartRate) · \(power) · +\(elevation)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension ActivityComparisonTrend {
    var color: Color {
        switch self {
        case .better:
            return .green
        case .worse:
            return .red
        case .neutral:
            return .secondary
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

    return NavigationStack {
        ActivityComparisonView()
    }
    .modelContainer(container)
}
