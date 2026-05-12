//
//  LoginView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var showError = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 34) {
                Spacer(minLength: 40)

                hero

                VStack(spacing: 12) {
                    FeaturePill(icon: "chart.line.uptrend.xyaxis", title: "Analiza carga, ritmo y progreso")
                    FeaturePill(icon: "brain.head.profile", title: "Insights claros para entrenar mejor")
                    FeaturePill(icon: "arrow.triangle.2.circlepath", title: "Sincronización directa con Strava")
                }

                Spacer(minLength: 20)

                Button {
                    connectWithStrava()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.title3)
                        
                        Text("Conectar con Strava")
                    }
                }
                .buttonStyle(PremiumPrimaryButtonStyle())
                .disabled(authService.isLoading)
                
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                
                Text("Necesitas una cuenta de Strava para usar esta app")
                    .font(.caption)
                    .foregroundStyle(SportBoardTheme.Palette.dimText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SportBoardTheme.Spacing.screen)
            .padding(.bottom, 44)
        }
        .premiumScreenBackground()
        .alert("Error de Autenticación", isPresented: $showError) {
            Button("OK") {
                authService.error = nil
            }
        } message: {
            Text(authService.error?.localizedDescription ?? "Error desconocido")
        }
        .onChange(of: authService.error) { _, newError in
            showError = newError != nil
        }
    }

    private var hero: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(SportBoardTheme.Palette.glow)
                    .frame(width: 168, height: 168)
                    .blur(radius: 24)

                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 142, height: 142)
                    .overlay {
                        RoundedRectangle(cornerRadius: 42, style: .continuous)
                            .stroke(SportBoardTheme.Palette.hairlineStrong, lineWidth: 1)
                    }

                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 82, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, SportBoardTheme.Palette.accent)
            }

            VStack(spacing: 10) {
                Text("SportBoard")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .tracking(0.8)

                Text("Tu centro de mando para entrenar con intención.")
                    .font(.headline)
                    .foregroundStyle(SportBoardTheme.Palette.mutedText)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
        }
    }
    
    private func connectWithStrava() {
        Task {
            do {
                try await authService.startOAuthFlow()
            } catch {
                // El error se maneja a través del @Published error
                print("Auth error: \(error)")
            }
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SportBoardTheme.Palette.accent)
                .frame(width: 24)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SportBoardTheme.Palette.mutedText)

            Spacer()
        }
        .premiumCard(cornerRadius: SportBoardTheme.Radius.medium, padding: 14)
    }
}

#Preview {
    LoginView()
}
