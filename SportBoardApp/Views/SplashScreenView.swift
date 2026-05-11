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
        subtitle: "Tu motor de entrenamiento",
        highlights: ["RITMO", "CARGA", "PROGRESO"],
        minimumDisplayDuration: 1.9
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

            VStack(spacing: 34) {
                Spacer()

                emblem

                VStack(spacing: 12) {
                    Text(content.title.uppercased())
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white)
                        .shadow(color: .stravaOrange.opacity(0.45), radius: 18, y: 6)

                    Text(content.subtitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                highlightStrip

                Spacer()

                loadingBar
                    .padding(.bottom, 54)
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
                    Color(red: 0.05, green: 0.06, blue: 0.09),
                    Color(red: 0.10, green: 0.08, blue: 0.06),
                    Color.stravaOrange.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.stravaOrange.opacity(0.36))
                .frame(width: 320, height: 320)
                .blur(radius: 72)
                .offset(x: isAnimated ? -120 : -84, y: isAnimated ? -250 : -210)

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 64)
                .offset(x: isAnimated ? 130 : 92, y: isAnimated ? 215 : 260)

            RacingLines()
                .stroke(.white.opacity(0.09), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .scaleEffect(isAnimated ? 1.04 : 0.98)
        }
    }

    private var emblem: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .white.opacity(0.04),
                                .white.opacity(0.7),
                                .stravaOrange,
                                .white.opacity(0.04)
                            ],
                            center: .center
                        ),
                        lineWidth: CGFloat(10 - index * 2)
                    )
                    .frame(
                        width: CGFloat(170 + index * 34),
                        height: CGFloat(170 + index * 34)
                    )
                    .rotationEffect(.degrees(isAnimated ? Double(24 + index * 9) : Double(-18 - index * 6)))
                    .opacity(0.82 - Double(index) * 0.18)
            }

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 148, height: 148)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 24, y: 18)

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 86, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.stravaOrange)
                .scaleEffect(isAnimated ? 1.04 : 0.96)
        }
        .frame(width: 250, height: 250)
    }

    private var highlightStrip: some View {
        HStack(spacing: 10) {
            ForEach(content.highlights, id: \.self) { highlight in
                Text(highlight)
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 13)
                    .background(.white.opacity(0.13), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
            }
        }
    }

    private var loadingBar: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.white.opacity(0.16))
                .frame(width: 176, height: 5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: isAnimated ? 176 : 56, height: 5)
                        .shadow(color: .white.opacity(0.75), radius: 8)
                }
                .clipShape(Capsule())

            Text("Preparando tu próxima sesión")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
    }
}

private struct RacingLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = rect.height / 8

        for index in 0...8 {
            let y = CGFloat(index) * spacing
            path.move(to: CGPoint(x: -rect.width * 0.1, y: y))
            path.addQuadCurve(
                to: CGPoint(x: rect.width * 1.1, y: y + 82),
                control: CGPoint(x: rect.midX, y: y - 74)
            )
        }

        return path
    }
}

#Preview {
    SplashScreenView(content: .sportBoard)
}
