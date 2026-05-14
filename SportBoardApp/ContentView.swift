//
//  ContentView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var activitiesViewModel = ActivitiesViewModel()
    @StateObject private var syncViewModel = SyncViewModel()
    
    var body: some View {
        SplashGateView {
            Group {
                if authService.isAuthenticated {
                    MainTabView(
                        dashboardViewModel: dashboardViewModel,
                        activitiesViewModel: activitiesViewModel,
                        syncViewModel: syncViewModel
                    )
                } else {
                    LoginView()
                }
            }
            .animation(.easeInOut, value: authService.isAuthenticated)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Bindable var dashboardViewModel: DashboardViewModel
    @Bindable var activitiesViewModel: ActivitiesViewModel
    @ObservedObject var syncViewModel: SyncViewModel
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Inicio", systemImage: "sparkles.rectangle.stack", value: 0) {
                DashboardView(
                    viewModel: dashboardViewModel,
                    syncViewModel: syncViewModel
                )
            }
            
            Tab("Insights", systemImage: "brain.head.profile", value: 1) {
                IntelligenceView(viewModel: dashboardViewModel)
            }
            
            Tab("Estadísticas", systemImage: "chart.bar.xaxis", value: 2) {
                StatisticsView(viewModel: dashboardViewModel)
            }

            Tab("Actividades", systemImage: "figure.run", value: 3) {
                ActivityListView(viewModel: activitiesViewModel)
            }

            Tab("Comparar", systemImage: "rectangle.split.2x1", value: 4) {
                NavigationStack {
                    ActivityComparisonView()
                }
            }
        }
        .tint(Color.stravaOrange)
        .toolbarBackground(SportBoardTheme.Palette.backgroundBottom, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
        .premiumScreenBackground()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Activity.self, ActivityLap.self, ActivitySplit.self,
        ActivityZoneDistribution.self, ActivityStreamSummary.self, StravaGear.self, ActivitySegmentEffort.self,
        ActivityTempoBlockSplit.self,
        SyncState.self, Athlete.self,
        configurations: config
    )
    
    return ContentView()
        .modelContainer(container)
}
