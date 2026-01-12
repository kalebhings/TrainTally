//
//  TrainTallyApp.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/19/25.
//

import SwiftUI
import SwiftData
import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin

@main
struct TrainTallyApp: App {
    
    init() {
        configureAmplify()
    }
    
    private func configureAmplify() {
        // Only configure Amplify if AWS is properly set up
        guard AWSConfiguration.isConfigured else {
            print("⚠️ AWS not configured. Cloud sync will be disabled.")
            print("Update AWSConfiguration.swift and amplifyconfiguration.json to enable cloud features.")
            return
        }
        
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.configure()
            print("✅ Amplify configured successfully")
        } catch {
            print("❌ Failed to configure Amplify: \(error)")
        }
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GameSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    cleanupIncompleteGames()
                    checkAuthStatus()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// Clean up incomplete games that were abandoned
    /// This runs once when the app launches
    private func cleanupIncompleteGames() {
        Task {
            let context = sharedModelContainer.mainContext
            let descriptor = FetchDescriptor<GameSession>(
                predicate: #Predicate { !$0.isCompleted }
            )
            
            do {
                let incompleteSessions = try context.fetch(descriptor)
                
                // Delete games that were started but never completed
                // Only delete if they're older than 1 hour (to avoid deleting active games)
                let oneHourAgo = Date().addingTimeInterval(-3600)
                
                for session in incompleteSessions {
                    if session.startedAt < oneHourAgo {
                        context.delete(session)
                    }
                }
                
                try context.save()
                
                if !incompleteSessions.isEmpty {
                    print("🧹 Cleaned up \(incompleteSessions.count) incomplete game(s)")
                }
            } catch {
                print("❌ Error cleaning up incomplete games: \(error)")
            }
        }
    }
    
    /// Check authentication status on app launch
    @MainActor
    private func checkAuthStatus() {
        guard AWSConfiguration.isConfigured else { return }
        
        Task {
            AuthenticationManager.shared.checkAuthStatus()
        }
    }
}

