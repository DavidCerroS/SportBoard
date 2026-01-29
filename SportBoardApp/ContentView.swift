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

// MARK: - Main Tab View

struct MainTabView: View {
    @Bindable var dashboardViewModel: DashboardViewModel
    @Bindable var activitiesViewModel: ActivitiesViewModel
    @ObservedObject var syncViewModel: SyncViewModel
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.xaxis", value: 0) {
                DashboardView(
                    viewModel: dashboardViewModel,
                    syncViewModel: syncViewModel
                )
            }
            
            Tab("Actividades", systemImage: "figure.run", value: 1) {
                ActivityListView(viewModel: activitiesViewModel)
            }
        }
        .tint(Color.stravaOrange)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Activity.self, ActivityLap.self, ActivitySplit.self, SyncState.self, Athlete.self,
        configurations: config
    )
    
    return ContentView()
        .modelContainer(container)
}
