//
//  SportBoardTheme.swift
//  SportBoardApp
//

import SwiftUI

enum SportBoardTheme {
    enum Palette {
        static let accent = Color(red: 1.0, green: 0.32, blue: 0.0)
        static let backgroundTop = Color(red: 0.025, green: 0.031, blue: 0.055)
        static let backgroundMid = Color(red: 0.045, green: 0.051, blue: 0.086)
        static let backgroundBottom = Color(red: 0.016, green: 0.020, blue: 0.035)
        static let card = Color.white.opacity(0.075)
        static let cardElevated = Color.white.opacity(0.12)
        static let hairline = Color.white.opacity(0.12)
        static let hairlineStrong = Color.white.opacity(0.22)
        static let mutedText = Color.white.opacity(0.68)
        static let dimText = Color.white.opacity(0.48)
        static let glow = accent.opacity(0.34)
        static let success = Color(red: 0.19, green: 0.88, blue: 0.55)
        static let warning = Color(red: 1.0, green: 0.68, blue: 0.24)
        static let danger = Color(red: 1.0, green: 0.30, blue: 0.36)
        static let electricBlue = Color(red: 0.18, green: 0.56, blue: 1.0)
        static let violet = Color(red: 0.62, green: 0.38, blue: 1.0)
        static let aqua = Color(red: 0.22, green: 0.86, blue: 0.96)
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let card: CGFloat = 24
        static let large: CGFloat = 32
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 30
        static let screen: CGFloat = 20
        static let card: CGFloat = 18
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Palette.backgroundTop,
                Palette.backgroundMid,
                Palette.backgroundBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Palette.accent,
                Palette.warning
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func sportGradient(for sportType: String) -> LinearGradient {
        let color = Color.sportColor(for: sportType)
        return LinearGradient(
            colors: [color.opacity(0.95), color.opacity(0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PremiumBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    SportBoardTheme.backgroundGradient

                    Circle()
                        .fill(SportBoardTheme.Palette.accent.opacity(0.20))
                        .frame(width: 340, height: 340)
                        .blur(radius: 86)
                        .offset(x: -170, y: -280)

                    Circle()
                        .fill(SportBoardTheme.Palette.electricBlue.opacity(0.16))
                        .frame(width: 300, height: 300)
                        .blur(radius: 92)
                        .offset(x: 185, y: 230)
                }
                .ignoresSafeArea()
            }
    }
}

struct PremiumCardModifier: ViewModifier {
    var cornerRadius: CGFloat = SportBoardTheme.Radius.card
    var padding: CGFloat = SportBoardTheme.Spacing.card
    var accent: Color?
    var isElevated = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isElevated ? SportBoardTheme.Palette.cardElevated : SportBoardTheme.Palette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                accent?.opacity(0.55) ?? SportBoardTheme.Palette.hairline,
                                lineWidth: accent == nil ? 1 : 1.2
                            )
                    )
                    .background {
                        if let accent {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(accent.opacity(0.14))
                                .blur(radius: 28)
                                .offset(y: 8)
                        }
                    }
                    .shadow(color: .black.opacity(0.30), radius: 24, x: 0, y: 14)
            }
    }
}

struct PremiumPillModifier: ViewModifier {
    let isSelected: Bool
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? color.opacity(0.92) : Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? color.opacity(0.95) : SportBoardTheme.Palette.hairline, lineWidth: 1)
                    )
            }
            .foregroundStyle(isSelected ? .white : SportBoardTheme.Palette.mutedText)
    }
}

struct PremiumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(SportBoardTheme.accentGradient, in: RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SportBoardTheme.Radius.medium, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: SportBoardTheme.Palette.glow, radius: configuration.isPressed ? 12 : 24, y: configuration.isPressed ? 5 : 12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.smooth(duration: 0.18), value: configuration.isPressed)
    }
}

extension View {
    func premiumScreenBackground() -> some View {
        modifier(PremiumBackgroundModifier())
    }

    func premiumCard(
        cornerRadius: CGFloat = SportBoardTheme.Radius.card,
        padding: CGFloat = SportBoardTheme.Spacing.card,
        accent: Color? = nil,
        isElevated: Bool = false
    ) -> some View {
        modifier(
            PremiumCardModifier(
                cornerRadius: cornerRadius,
                padding: padding,
                accent: accent,
                isElevated: isElevated
            )
        )
    }

    func premiumPill(isSelected: Bool = false, color: Color = SportBoardTheme.Palette.accent) -> some View {
        modifier(PremiumPillModifier(isSelected: isSelected, color: color))
    }
}
