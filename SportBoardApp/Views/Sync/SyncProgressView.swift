//
//  SyncProgressView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct SyncProgressView: View {
    @ObservedObject var viewModel: SyncViewModel
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Sincronización")
                    .font(.headline)
                Spacer()
                if viewModel.progress.phase == .completed {
                    Button("Cerrar") {
                        onDismiss?()
                    }
                }
            }
            
            // Estado actual
            VStack(spacing: 16) {
                // Icono y fase
                ZStack {
                    Circle()
                        .fill(phaseColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    if viewModel.isActive {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: phaseIcon)
                            .font(.system(size: 32))
                            .foregroundStyle(phaseColor)
                    }
                }
                
                Text(viewModel.progress.phase.displayText)
                    .font(.title3)
                    .fontWeight(.medium)
                
                // Barra de progreso
                if viewModel.progress.totalActivities > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.progress.progressPercentage)
                            .progressViewStyle(.linear)
                            .tint(Color.stravaOrange)
                        
                        Text(viewModel.progress.progressText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Información adicional
            if viewModel.isActive || viewModel.isPaused {
                VStack(spacing: 12) {
                    // Rate Limit Warning
                    if viewModel.progress.isRateLimited {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .foregroundStyle(.orange)
                                Text("Límite de API alcanzado")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                            }
                            .font(.subheadline)
                            
                            // Temporizador grande
                            Text(viewModel.progress.rateLimitRemainingText)
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                            
                            Text("Continuará automáticamente")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Año actual
                    if !viewModel.progress.yearText.isEmpty && !viewModel.progress.isRateLimited {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                            Text(viewModel.progress.yearText)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    
                    // Última actividad
                    if let name = viewModel.progress.lastActivityName, !viewModel.progress.isRateLimited {
                        HStack {
                            Image(systemName: "figure.run")
                                .foregroundStyle(.secondary)
                            Text(name)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    
                    // Errores
                    if viewModel.progress.failedCount > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("\(viewModel.progress.failedCount) actividades con error")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Error message
            if let error = viewModel.progress.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Botones de acción
            HStack(spacing: 16) {
                if viewModel.isActive {
                    Button {
                        viewModel.cancelSync()
                    } label: {
                        Label("Cancelar", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                if viewModel.isPaused {
                    Button {
                        viewModel.resumeSync()
                    } label: {
                        Label("Reanudar", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.stravaOrange)
                }
                
                if viewModel.hasError {
                    Button {
                        viewModel.startSync()
                    } label: {
                        Label("Reintentar", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.stravaOrange)
                }
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .padding()
    }
    
    private var phaseColor: Color {
        switch viewModel.progress.phase {
        case .idle, .completed:
            return .green
        case .fetchingActivities, .fetchingDetails, .fetchingLaps:
            return Color.stravaOrange
        case .paused:
            return .yellow
        case .error:
            return .red
        }
    }
    
    private var phaseIcon: String {
        switch viewModel.progress.phase {
        case .idle:
            return "checkmark.circle"
        case .fetchingActivities, .fetchingDetails, .fetchingLaps:
            return "arrow.down.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Compact Version for Dashboard

struct SyncProgressCompactView: View {
    @ObservedObject var viewModel: SyncViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            if viewModel.progress.isRateLimited {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
            } else if viewModel.isActive {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            } else if viewModel.isPaused {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if viewModel.progress.isRateLimited {
                    Text("Límite API - Esperando")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    
                    Text("Continúa en \(viewModel.progress.rateLimitRemainingText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(viewModel.progress.phase.displayText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if viewModel.progress.totalActivities > 0 {
                        Text(viewModel.progress.progressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if viewModel.progress.isRateLimited {
                Text(viewModel.progress.rateLimitRemainingText)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.orange)
            } else if viewModel.isActive {
                Button {
                    viewModel.cancelSync()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(viewModel.progress.isRateLimited ? Color.orange.opacity(0.1) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Full") {
    let vm = SyncViewModel()
    vm.progress.phase = .fetchingActivities
    vm.progress.totalActivities = 660
    vm.progress.syncedActivities = 120
    vm.progress.currentYear = 2021
    vm.progress.lastActivityName = "Morning Run"
    
    return SyncProgressView(viewModel: vm)
}

#Preview("Compact") {
    let vm = SyncViewModel()
    vm.progress.phase = .fetchingActivities
    vm.progress.totalActivities = 660
    vm.progress.syncedActivities = 120
    
    return SyncProgressCompactView(viewModel: vm)
        .padding()
}
