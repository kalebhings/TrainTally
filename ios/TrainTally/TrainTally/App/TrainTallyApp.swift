//
//  TrainTallyApp.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/19/25.
//

import SwiftUI
import SwiftData

@main
struct TrainTallyApp: App {
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
                    print("Cleaned up \(incompleteSessions.count) incomplete game(s)")
                }
            } catch {
                print("Error cleaning up incomplete games: \(error)")
            }
        }
    }
}
