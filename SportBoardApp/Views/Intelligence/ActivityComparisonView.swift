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
    @State private var selectedFirstID: Int64?
    @State private var selectedSecondID: Int64?

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
        ScrollView {
            LazyVStack(spacing: SportBoardTheme.Spacing.md) {
                if activities.count < 2 {
                    ContentUnavailableView(
                        "No hay suficientes carreras",
                        systemImage: "figure.run",
                        description: Text("Sincroniza al menos dos actividades de carrera para poder compararlas.")
                    )
                    .padding(.top, 80)
                } else {
                    selectionSection

                    if let comparison {
                        comparisonHero(comparison)

                        if !comparison.warnings.isEmpty {
                            warningSection(comparison.warnings)
                        }

                        insightsSection(comparison.insights)
                        metricsSection(comparison.metrics)
                        segmentsSection(comparison)
                    }
                }
            }
            .padding(.horizontal, SportBoardTheme.Spacing.screen)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .scrollContentBackground(.hidden)
        .premiumScreenBackground()
        .navigationTitle("Comparar entrenos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            loadActivities()
        }
        .refreshable {
            loadActivities()
        }
    }

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            comparisonSectionHeader("Selección", icon: "arrow.left.arrow.right")

            Picker("Entreno A", selection: $selectedFirstID) {
                Text("Selecciona un entreno")
                    .tag(nil as Int64?)
                ForEach(activities, id: \.id) { activity in
                    Text(selectionLabel(for: activity))
                        .tag(Optional(activity.id))
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 10) {
                Picker("Entreno B", selection: $selectedSecondID) {
                    Text("Selecciona un entreno")
                        .tag(nil as Int64?)
                    ForEach(activities, id: \.id) { activity in
                        Text(selectionLabel(for: activity))
                            .tag(Optional(activity.id))
                    }
                }
                .pickerStyle(.menu)

                Button {
                    swap(&selectedFirstID, &selectedSecondID)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(SportBoardTheme.Palette.accent.opacity(0.24), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous)
                                .stroke(SportBoardTheme.Palette.accent.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Intercambiar entrenos")
            }

            HStack(spacing: 12) {
                if let selectedFirst {
                    ActivityComparisonSelectionCard(
                        title: "A",
                        activity: selectedFirst,
                        sessionType: RunClassifier.classify(
                            activity: selectedFirst,
                            splits: selectedFirst.sortedSplits,
                            laps: selectedFirst.sortedLaps
                        ).type,
                        accent: SportBoardTheme.Palette.accent
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
                        ).type,
                        accent: SportBoardTheme.Palette.aqua
                    )
                }
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 16, accent: SportBoardTheme.Palette.accent.opacity(0.45), isElevated: true)
    }

    private func warningSection(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            comparisonSectionHeader("Avisos", icon: "exclamationmark.triangle.fill")

            ForEach(warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(SportBoardTheme.Palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14, accent: SportBoardTheme.Palette.warning.opacity(0.55))
    }

    private func comparisonHero(_ comparison: ActivityComparison) -> some View {
        let paceMetric = comparison.metrics.first { $0.id == "averagePace" }
        let distanceMetric = comparison.metrics.first { $0.id == "distance" }
        let timeMetric = comparison.metrics.first { $0.id == "movingTime" }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(heroTitle(for: paceMetric?.trend ?? .neutral))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(paceMetric?.differenceValue ?? "--")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle((paceMetric?.trend ?? .neutral).color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("Ritmo medio B vs A")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SportBoardTheme.Palette.dimText)
                }

                Spacer(minLength: 0)

                Image(systemName: (paceMetric?.trend ?? .neutral).heroIcon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle((paceMetric?.trend ?? .neutral).color)
                    .frame(width: 54, height: 54)
                    .background((paceMetric?.trend ?? .neutral).color.opacity(0.18), in: Circle())
            }

            HStack(spacing: 10) {
                ActivityComparisonHeroStat(title: "Distancia", value: distanceMetric?.differenceValue ?? "--", color: distanceMetric?.trend.color ?? SportBoardTheme.Palette.dimText)
                ActivityComparisonHeroStat(title: "Tiempo", value: timeMetric?.differenceValue ?? "--", color: timeMetric?.trend.color ?? SportBoardTheme.Palette.dimText)
                ActivityComparisonHeroStat(title: "Parciales", value: "\(comparison.segments.count)", color: SportBoardTheme.Palette.aqua)
            }

            HStack(spacing: 10) {
                comparisonTypePill("A", comparison.firstSessionType.displayName, color: SportBoardTheme.Palette.accent)
                comparisonTypePill("B", comparison.secondSessionType.displayName, color: SportBoardTheme.Palette.aqua)
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.large, padding: 20, accent: (paceMetric?.trend.color ?? SportBoardTheme.Palette.accent).opacity(0.6), isElevated: true)
    }

    private func insightsSection(_ insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            comparisonSectionHeader("Lectura rápida", icon: "sparkles")

            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(SportBoardTheme.Palette.success)
                        .font(.subheadline)
                        .padding(.top, 1)

                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(SportBoardTheme.Palette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14, accent: SportBoardTheme.Palette.success.opacity(0.35))
    }

    private func metricsSection(_ metrics: [ActivityComparisonMetric]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            comparisonSectionHeader("Métricas", icon: "chart.bar.xaxis")

            ForEach(metrics) { metric in
                ActivityComparisonMetricRow(metric: metric)
            }
        }
    }

    private func segmentsSection(_ comparison: ActivityComparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            comparisonSectionHeader(comparison.segmentSource.title, icon: "point.topleft.down.curvedto.point.bottomright.up")

            if comparison.segments.isEmpty {
                Text("Estos entrenos no tienen parciales comparables.")
                    .font(.subheadline)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .padding(.vertical, 8)
            } else {
                ForEach(comparison.segments) { segment in
                    ActivityComparisonSegmentRow(segment: segment)
                }
            }
        }
    }

    private func comparisonSectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(SportBoardTheme.Palette.accent)

            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
    }

    private func comparisonTypePill(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.9), in: Circle())

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous))
    }

    private func heroTitle(for trend: ActivityComparisonTrend) -> String {
        switch trend {
        case .better:
            return "B salió mejor"
        case .worse:
            return "A fue más fuerte"
        case .neutral:
            return "Muy igualados"
        }
    }

    private func loadActivities() {
        var descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        activities = ActivityComparisonService.sortedComparableActivities(from: fetched)
        let selection = ActivityComparisonService.defaultSelectionIDs(
            in: activities,
            currentFirstID: selectedFirstID,
            currentSecondID: selectedSecondID
        )
        selectedFirstID = selection.firstID
        selectedSecondID = selection.secondID
    }

    private func activity(for id: Int64?) -> Activity? {
        guard let id else { return nil }
        return activities.first { $0.id == id }
    }

    private func selectionLabel(for activity: Activity) -> String {
        "\(Self.activityDateFormatter.string(from: activity.startDate)) · \(activity.name) · \(activity.formattedDistance)"
    }
}

private struct ActivityComparisonSelectionCard: View {
    let title: String
    let activity: Activity
    let sessionType: RunSessionType
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.9), in: Circle())

                Text(sessionType.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(activity.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(minHeight: 36, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 6) {
                compactStat(activity.formattedDistance, icon: "ruler")
                compactStat(activity.formattedMovingTime, icon: "clock")
                compactStat(activity.formattedPace, icon: "speedometer")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(SportBoardTheme.Palette.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
    }

    private func compactStat(_ value: String, icon: String) -> some View {
        Label(value, systemImage: icon)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }
}

private struct ActivityComparisonHeroStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.dimText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous))
    }
}

private struct ActivityComparisonMetricRow: View {
    let metric: ActivityComparisonMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: metric.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(metric.trend.color)
                    .frame(width: 30, height: 30)
                    .background(metric.trend.color.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = metric.detail {
                        Text(detail)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(metric.trend.color)
                    }
                }

                Spacer(minLength: 0)

                Text(metric.differenceValue)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(metric.trend.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            HStack(spacing: 8) {
                metricValuePill(label: "A", value: metric.firstValue, color: SportBoardTheme.Palette.accent)
                metricValuePill(label: "B", value: metric.secondValue, color: SportBoardTheme.Palette.aqua)
            }
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
                .stroke(SportBoardTheme.Palette.hairline, lineWidth: 1)
        )
    }

    private func metricValuePill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(color)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous))
    }
}

private struct ActivityComparisonSegmentRow: View {
    let segment: ActivityComparisonSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(segment.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(segment.paceDifference)
                    .font(.caption.weight(.black))
                    .foregroundStyle(segment.trend.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(segment.trend.color.opacity(0.16), in: Capsule())
            }

            HStack(spacing: 10) {
                column("A", time: segment.firstTime, pace: segment.firstPace, heartRate: segment.firstHeartRate, power: segment.firstPower, elevation: segment.firstElevation, color: SportBoardTheme.Palette.accent)
                column("B", time: segment.secondTime, pace: segment.secondPace, heartRate: segment.secondHeartRate, power: segment.secondPower, elevation: segment.secondElevation, color: SportBoardTheme.Palette.aqua)
            }

            Label(segment.timeDifference, systemImage: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.dimText)
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
                .stroke(segment.trend.color.opacity(0.32), lineWidth: 1)
        )
    }

    private func column(
        _ title: String,
        time: String,
        pace: String,
        heartRate: String,
        power: String,
        elevation: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(color)

            Text(pace)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(time)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text("FC \(heartRate) · \(power)")
                .font(.caption2)
                .foregroundStyle(SportBoardTheme.Palette.dimText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("+\(elevation)")
                .font(.caption2)
                .foregroundStyle(SportBoardTheme.Palette.dimText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.small, style: .continuous))
    }
}

private extension ActivityComparisonTrend {
    var color: Color {
        switch self {
        case .better:
            return SportBoardTheme.Palette.success
        case .worse:
            return SportBoardTheme.Palette.danger
        case .neutral:
            return SportBoardTheme.Palette.dimText
        }
    }

    var heroIcon: String {
        switch self {
        case .better:
            return "arrow.down.right.circle.fill"
        case .worse:
            return "arrow.up.right.circle.fill"
        case .neutral:
            return "equal.circle.fill"
        }
    }
}

private extension ActivityComparisonMetric {
    var icon: String {
        switch id {
        case "distance":
            return "ruler"
        case "movingTime", "elapsedTime":
            return "clock"
        case "averagePace", "pacePerHeartRate", "pacePerWatt":
            return "speedometer"
        case "maxSpeed":
            return "bolt.fill"
        case "elevation", "elevationPerKm":
            return "mountain.2.fill"
        case "averageHeartRate", "maxHeartRate":
            return "heart.fill"
        case "averagePower", "maxPower":
            return "bolt.heart.fill"
        case "kilojoules":
            return "flame.fill"
        default:
            return "chart.bar.fill"
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

    return NavigationStack {
        ActivityComparisonView()
    }
    .modelContainer(container)
}
