//
//  GameSession.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/19/25.
//

import Foundation
import SwiftData

// MARK: - Game Session (SwiftData Model)

/// Represents a single game session with players, tracking game state and persistence
/// Scoring is only calculated when the game is completed for better performance
@Model
final class GameSession {
    // MARK: - Persisted Properties
    
    var id: UUID
    var gameVersionId: String
    var playersData: Data  // Encoded [Player] array
    var startedAt: Date
    var completedAt: Date?
    var isCompleted: Bool
    
    // Leaderboard sync status
    var isSubmittedToCloud: Bool
    var cloudSyncDate: Date?
    
    // MARK: - Transient Properties (not saved to database)
    
    @Transient private var storage = GameSessionStorage()
    
    // MARK: - Initialization
    
    init(gameVersionId: String, players: [Player]) {
        self.id = UUID()
        self.gameVersionId = gameVersionId
        self.startedAt = Date()
        self.completedAt = nil
        self.isCompleted = false
        self.isSubmittedToCloud = false
        self.cloudSyncDate = nil
        
        // Encode players (with proper error handling)
        do {
            self.playersData = try storage.savePlayers(players)
        } catch {
            // This should never happen with valid Player objects
            assertionFailure("CRITICAL: Failed to encode initial players - \(error)")
            // Set to empty array encoded as fallback
            self.playersData = (try? JSONEncoder().encode([Player]())) ?? Data()
        }
    }
    
    // MARK: - Player Access
    
    /// Get all players in this session
    var players: [Player] {
        get {
            storage.getPlayers(from: playersData)
        }
        set {
            do {
                playersData = try storage.savePlayers(newValue)
            } catch {
                print("ERROR: Failed to save players - \(error)")
            }
        }
    }
    
    /// Update a single player (more efficient than replacing entire array)
    func updatePlayer(_ updatedPlayer: Player) {
        do {
            playersData = try storage.updatePlayer(updatedPlayer, in: playersData)
        } catch {
            print("ERROR: Failed to update player - \(error)")
        }
    }
    
    /// Invalidate the player cache (call if data changes externally)
    func invalidatePlayerCache() {
        storage.invalidateCache()
    }
    
    // MARK: - Game Info
    
    /// Get the game version configuration
    var gameVersion: GameVersion? {
        GameConfigLoader.shared.getVersion(byId: gameVersionId)
    }
    
    /// Number of players in this session
    var playerCount: Int {
        players.count
    }
    
    /// Duration of the game (nil if not completed)
    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }
    
    // MARK: - Game Actions
    
    /// Mark the game as completed
    func completeGame() {
        isCompleted = true
        completedAt = Date()
    }
    
    /// Reopen a completed game (for editing)
    func reopenGame() {
        isCompleted = false
        completedAt = nil
    }
    
    // MARK: - Final Scoring (Only for completed games)
    
    /// Get final scores for all players (only call when game is complete)
    /// Returns nil if game version is invalid
    func getFinalScores() -> [PlayerFinalScore]? {
        guard let version = gameVersion else {
            print("WARNING: Cannot calculate scores without valid game version")
            return nil
        }
        
        let calculator = ScoreCalculator(gameVersion: version, players: players)
        return calculator.calculateFinalScores()
    }
    
    /// Get sorted final scores (highest to lowest)
    func getSortedScores() -> [PlayerFinalScore]? {
        guard let version = gameVersion else { return nil }
        
        let calculator = ScoreCalculator(gameVersion: version, players: players)
        return calculator.getSortedScores()
    }
    
    /// Get the winner's final score
    func getWinner() -> PlayerFinalScore? {
        guard let version = gameVersion else { return nil }
        
        let calculator = ScoreCalculator(gameVersion: version, players: players)
        return calculator.getWinner()
    }
    
    /// Get the player with the lowest score
    func getLoser() -> PlayerFinalScore? {
        guard let version = gameVersion else { return nil }
        
        let calculator = ScoreCalculator(gameVersion: version, players: players)
        return calculator.getLoser()
    }
    
    // MARK: - Cloud Sync
    
    /// Mark this session as submitted to the cloud
    func markAsSubmitted() {
        isSubmittedToCloud = true
        cloudSyncDate = Date()
    }
    
    /// Reset cloud sync status (for re-submission)
    func resetCloudSync() {
        isSubmittedToCloud = false
        cloudSyncDate = nil
    }
}
