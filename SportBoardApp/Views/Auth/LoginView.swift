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
        VStack(spacing: 40) {
            Spacer()
            
            // Logo y título
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.stravaOrange)
                
                Text("SportBoard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Tu dashboard de entrenamiento")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Botón de conectar
            VStack(spacing: 16) {
                Button {
                    connectWithStrava()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.title3)
                        
                        Text("Conectar con Strava")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.stravaOrange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(authService.isLoading)
                
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                
                Text("Necesitas una cuenta de Strava para usar esta app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
                .frame(height: 60)
        }
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

#Preview {
    LoginView()
}
