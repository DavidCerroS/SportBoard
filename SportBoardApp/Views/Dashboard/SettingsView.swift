//
//  SettingsView.swift
//  SportBoardApp
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var syncService = SyncService.shared

    @State private var activeAlert: SettingsAlert?
    @State private var activityCount = 0

    var body: some View {
        List {
            Section {
                Button {
                    activeAlert = .fullSync
                } label: {
                    Label("Sincronización Completa", systemImage: "arrow.triangle.2.circlepath.circle")
                }

                Button(role: .destructive) {
                    activeAlert = .resetAndResync
                } label: {
                    Label("Borrar y Resincronizar Todo", systemImage: "trash.circle")
                }
            } header: {
                Text("Sincronización")
            } footer: {
                Text("Usa 'Sincronización Completa' si la sincronización inicial no terminó. 'Borrar y Resincronizar' eliminará todas las actividades locales y las volverá a descargar.")
            }

            Section("Datos") {
                LabeledContent("Actividades sincronizadas", value: "\(activityCount)")
            }

            Section("Cuenta") {
                Button(role: .destructive) {
                    activeAlert = .logout
                } label: {
                    Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section("Información") {
                LabeledContent("Versión", value: "1.0.0")
            }
        }
        .scrollContentBackground(.hidden)
        .premiumScreenBackground()
        .navigationTitle("Ajustes")
        .toolbarBackground(SportBoardTheme.Palette.backgroundTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            loadActivityCount()
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .fullSync:
                Alert(
                    title: Text("Sincronización Completa"),
                    message: Text("Esto descargará todas las actividades históricas que falten. Puede tardar varios minutos y consumir llamadas de API."),
                    primaryButton: .default(Text("Sincronizar"), action: startFullSync),
                    secondaryButton: .cancel(Text("Cancelar"))
                )
            case .resetAndResync:
                Alert(
                    title: Text("Borrar y Resincronizar"),
                    message: Text("Se eliminarán todas las actividades sincronizadas y se volverán a descargar desde Strava. ¿Continuar?"),
                    primaryButton: .destructive(Text("Borrar Todo"), action: resetAndResync),
                    secondaryButton: .cancel(Text("Cancelar"))
                )
            case .logout:
                Alert(
                    title: Text("Cerrar Sesión"),
                    message: Text("¿Estás seguro de que quieres cerrar sesión? Los datos sincronizados se mantendrán."),
                    primaryButton: .destructive(Text("Cerrar Sesión"), action: authService.logout),
                    secondaryButton: .cancel(Text("Cancelar"))
                )
            }
        }
    }

    private func loadActivityCount() {
        let descriptor = FetchDescriptor<Activity>()
        activityCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func startFullSync() {
        syncService.configure(modelContext: modelContext)
        syncService.startSync(fullSync: true)
    }

    private func resetAndResync() {
        do {
            try modelContext.delete(model: Activity.self)
            try modelContext.delete(model: ActivityLap.self)
            try modelContext.delete(model: ActivitySplit.self)
            try modelContext.delete(model: ActivityZoneDistribution.self)
            try modelContext.delete(model: ActivityStreamSummary.self)
            try modelContext.delete(model: StravaGear.self)
            try modelContext.delete(model: ActivitySegmentEffort.self)
            try modelContext.delete(model: ActivityTempoBlockSplit.self)
            try modelContext.delete(model: SyncState.self)
            try modelContext.delete(model: RunnerProfile.self)
            try modelContext.delete(model: PostActivityReflection.self)
            try modelContext.save()

            activityCount = 0

            syncService.configure(modelContext: modelContext)
            syncService.startSync(fullSync: true)
        } catch {
            print("Error resetting data: \(error)")
        }
    }
}

private enum SettingsAlert: Hashable, Identifiable {
    case fullSync
    case resetAndResync
    case logout

    var id: Self { self }
}
