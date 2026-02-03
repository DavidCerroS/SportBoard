//
//  SportBoardAppApp.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI
import SwiftData

@main
struct SportBoardAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Activity.self,
            ActivityLap.self,
            ActivitySplit.self,
            SyncState.self,
            Athlete.self,
            RunnerProfile.self,
            PostActivityReflection.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Manejar callback de OAuth si es necesario
                    handleOAuthCallback(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleOAuthCallback(_ url: URL) {
        // El callback de OAuth es manejado por ASWebAuthenticationSession
        // pero podemos agregar lógica adicional aquí si es necesario
        print("Received URL: \(url)")
    }
}
