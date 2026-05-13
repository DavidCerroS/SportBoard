//
//  SplashScreenView.swift
//  SportBoardApp
//

import SwiftUI

struct SplashScreenContent: Equatable {
    let title: String
    let subtitle: String
    let highlights: [String]
    let minimumDisplayDuration: TimeInterval

    static let sportBoard = SplashScreenContent(
        title: "SportBoard",
        subtitle: "Coach adaptativo para correr mejor",
        highlights: ["READINESS", "PLAN", "RITMO"],
        minimumDisplayDuration: 2.1
    )

    var minimumDisplayNanoseconds: UInt64 {
        UInt64(minimumDisplayDuration * 1_000_000_000)
    }

    var accessibilityLabel: String {
        "\(title). \(subtitle). \(highlights.joined(separator: ", "))."
    }
}

struct SplashGateView<Content: View>: View {
    private let splashContent: SplashScreenContent
    private let content: Content

    @State private var isShowingSplash = true

    init(
        splashContent: SplashScreenContent = .sportBoard,
        @ViewBuilder content: () -> Content
    ) {
        self.splashContent = splashContent
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .opacity(isShowingSplash ? 0 : 1)
                .scaleEffect(isShowingSplash ? 0.98 : 1)

            if isShowingSplash {
                SplashScreenView(content: splashContent)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: splashContent.minimumDisplayNanoseconds)

            withAnimation(.smooth(duration: 0.55)) {
                isShowingSplash = false
            }
        }
    }
}

struct SplashScreenView: View {
    let content: SplashScreenContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimated = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 24) {
                topSignalBar
                    .padding(.top, 58)

                Spacer(minLength: 18)

                heroLockup

                metricDeck

                highlightStrip

                Spacer(minLength: 16)

                loadingBar
                    .padding(.bottom, 46)
            }
            .padding(.horizontal, 28)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                isAnimated = true
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.012, green: 0.015, blue: 0.026),
                    Color(red: 0.034, green: 0.040, blue: 0.070),
                    Color(red: 0.015, green: 0.018, blue: 0.031)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            TrackField()
                .stroke(.white.opacity(0.075), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                .offset(y: isAnimated ? 14 : -8)

            TrackField()
                .stroke(SportBoardTheme.Palette.accent.opacity(0.26), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .scaleEffect(isAnimated ? 1.06 : 0.98)
                .offset(y: 22)

            DiagonalTelemetryGrid()
                .stroke(.white.opacity(0.055), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            SportBoardTheme.Palette.accent.opacity(0.32),
                            .clear,
                            SportBoardTheme.Palette.electricBlue.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(isAnimated ? 0.86 : 0.58)
        }
    }

    private var topSignalBar: some View {
        HStack(spacing: 10) {
            signalPill("LIVE", color: SportBoardTheme.Palette.success)
            Spacer()
            signalPill("COACH READY", color: SportBoardTheme.Palette.accent)
        }
    }

    private func signalPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.8), radius: 8)

            Text(text)
                .font(.caption2.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.86))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var heroLockup: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .frame(width: 146, height: 146)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.38), SportBoardTheme.Palette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                    .shadow(color: SportBoardTheme.Palette.accent.opacity(0.34), radius: 32, y: 16)
                    .rotationEffect(.degrees(isAnimated ? 4 : -3))

                Image(systemName: "figure.run")
                    .font(.system(size: 68, weight: .black))
                    .foregroundStyle(.white)
                    .offset(x: isAnimated ? 6 : -2, y: 0)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(SportBoardTheme.Palette.warning)
                    .offset(x: 44, y: -42)
                    .scaleEffect(isAnimated ? 1.12 : 0.9)
            }
            .frame(height: 160)

            VStack(spacing: 9) {
                Text(content.title.uppercased())
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .tracking(2.8)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .shadow(color: SportBoardTheme.Palette.accent.opacity(0.54), radius: 20, y: 8)

                Text(content.subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metricDeck: some View {
        HStack(spacing: 10) {
            splashMetric("92", "READY", SportBoardTheme.Palette.success)
            splashMetric("4:15", "PACE", SportBoardTheme.Palette.accent)
            splashMetric("1h35", "GOAL", SportBoardTheme.Palette.aqua)
        }
    }

    private func splashMetric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.caption2.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.34), lineWidth: 1)
        )
    }

    private var highlightStrip: some View {
        HStack(spacing: 10) {
            ForEach(content.highlights, id: \.self) { highlight in
                Text(highlight)
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .premiumPill(color: SportBoardTheme.Palette.accent)
            }
        }
    }

    private var loadingBar: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.white.opacity(0.16))
                .frame(width: 192, height: 5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: isAnimated ? 192 : 54, height: 5)
                        .shadow(color: .white.opacity(0.75), radius: 8)
                }
                .clipShape(Capsule())

            Text("Calculando tu próximo movimiento")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
    }
}

private struct TrackField: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerY = rect.midY + rect.height * 0.12
        let baseWidth = rect.width * 1.28

        for index in 0..<8 {
            let inset = CGFloat(index) * 26
            let rect = CGRect(
                x: rect.midX - baseWidth / 2 + inset,
                y: centerY - 150 + inset * 0.36,
                width: baseWidth - inset * 2,
                height: 300 - inset * 0.72
            )
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 150, height: 150))
        }

        return path
    }
}

private struct DiagonalTelemetryGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 42
        var x = -rect.height

        while x < rect.width + rect.height {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.height))
            x += spacing
        }

        return path
    }
}

#Preview {
    SplashScreenView(content: .sportBoard)
}
