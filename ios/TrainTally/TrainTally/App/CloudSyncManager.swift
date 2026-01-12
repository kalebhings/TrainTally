//
//  CloudSyncManager.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/12/26.
//

import Foundation
import SwiftData
import Observation

/// Manages synchronization between local SwiftData and AWS cloud backend
@MainActor
@Observable
class CloudSyncManager {
    static let shared = CloudSyncManager()
    
    var isCloudSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCloudSyncEnabled, forKey: "cloudSyncEnabled")
            
            // If disabled, we keep local data but stop syncing
            if !isCloudSyncEnabled {
                lastSyncDate = nil
            }
        }
    }
    
    var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                UserDefaults.standard.set(date, forKey: "lastSyncDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastSyncDate")
            }
        }
    }
    
    var syncStatus: SyncStatus = .idle
    var syncError: String?
    
    private let authManager = AuthenticationManager.shared
    private let apiService = AWSAPIService.shared
    
    private init() {
        self.isCloudSyncEnabled = UserDefaults.standard.bool(forKey: "cloudSyncEnabled")
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }
    
    // MARK: - Cloud Sync Control
    
    /// Enable cloud sync (requires authentication)
    func enableCloudSync() async throws {
        guard authManager.isAuthenticated else {
            throw SyncError.notAuthenticated
        }
        
        isCloudSyncEnabled = true
        
        // Optionally sync existing local data to cloud
        // await syncLocalDataToCloud()
    }
    
    /// Disable cloud sync (keeps local data)
    func disableCloudSync() {
        isCloudSyncEnabled = false
    }
    
    // MARK: - Game Submission
    
    /// Submit a completed game session
    /// - Always saves locally to SwiftData
    /// - Syncs to cloud if enabled and authenticated
    func submitGame(_ gameSession: GameSession, context: ModelContext) async throws {
        // Always save locally first
        gameSession.completeGame()
        try context.save()
        
        // Sync to cloud if enabled
        if isCloudSyncEnabled && authManager.isAuthenticated {
            try await syncGameToCloud(gameSession)
        }
    }
    
    /// Sync a specific game to the cloud
    func syncGameToCloud(_ gameSession: GameSession) async throws {
        guard isCloudSyncEnabled else {
            throw SyncError.syncDisabled
        }
        
        guard authManager.isAuthenticated else {
            throw SyncError.notAuthenticated
        }
        
        syncStatus = .syncing
        
        do {
            let token = try await authManager.getAuthToken()
            try await apiService.submitGame(gameSession, token: token)
            
            // Mark as submitted
            gameSession.markAsSubmitted()
            
            lastSyncDate = Date()
            syncStatus = .success
            syncError = nil
        } catch {
            syncStatus = .failed
            syncError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Bulk Sync
    
    /// Sync all unsubmitted games to cloud
    func syncAllUnsubmittedGames(context: ModelContext) async throws {
        guard isCloudSyncEnabled && authManager.isAuthenticated else {
            throw SyncError.notAuthenticated
        }
        
        syncStatus = .syncing
        
        // Fetch all completed but not submitted games
        let descriptor = FetchDescriptor<GameSession>(
            predicate: #Predicate { session in
                session.isCompleted && !session.isSubmittedToCloud
            }
        )
        
        let unsubmittedGames = try context.fetch(descriptor)
        
        guard !unsubmittedGames.isEmpty else {
            syncStatus = .idle
            return
        }
        
        var successCount = 0
        var failureCount = 0
        
        for game in unsubmittedGames {
            do {
                try await syncGameToCloud(game)
                successCount += 1
            } catch {
                failureCount += 1
                print("Failed to sync game \(game.id): \(error)")
            }
        }
        
        try context.save()
        
        if failureCount == 0 {
            syncStatus = .success
            lastSyncDate = Date()
        } else {
            syncStatus = .failed
            syncError = "Synced \(successCount) games, \(failureCount) failed"
        }
    }
    
    // MARK: - Data Source Selection
    
    /// Determine which data source to use for leaderboards
    var dataSource: DataSource {
        if isCloudSyncEnabled && authManager.isAuthenticated {
            return .cloud
        } else {
            return .local
        }
    }
}

// MARK: - Supporting Types

enum SyncStatus {
    case idle
    case syncing
    case success
    case failed
}

enum DataSource {
    case local
    case cloud
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case syncDisabled
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to sync with cloud"
        case .syncDisabled:
            return "Cloud sync is disabled"
        case .networkError:
            return "Network error occurred"
        }
    }
}
