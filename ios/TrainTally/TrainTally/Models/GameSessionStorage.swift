//
//  GameSessionStorage.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//

import Foundation

/// Handles encoding/decoding and caching of player data for GameSession
/// Separates storage logic from game logic
class GameSessionStorage {
    private var cachedPlayers: [Player]?
    private var isDirty: Bool = false
    
    // MARK: - Player Data Management
    
    /// Decode players from Data
    func getPlayers(from data: Data) -> [Player] {
        // Return cached version if available and not dirty
        if let cached = cachedPlayers, !isDirty {
            return cached
        }
        
        // Decode from data
        do {
            let decoded = try JSONDecoder().decode([Player].self, from: data)
            cachedPlayers = decoded
            isDirty = false
            return decoded
        } catch {
            print("ERROR: Failed to decode players - \(error)")
            return []
        }
    }
    
    /// Encode players to Data
    func savePlayers(_ players: [Player]) throws -> Data {
        do {
            let encoded = try JSONEncoder().encode(players)
            cachedPlayers = players
            isDirty = false
            return encoded
        } catch {
            print("CRITICAL ERROR: Failed to encode players - \(error)")
            throw error
        }
    }
    
    /// Update a single player (more efficient than replacing entire array)
    func updatePlayer(_ updatedPlayer: Player, in data: Data) throws -> Data {
        var players = getPlayers(from: data)
        
        guard let index = players.firstIndex(where: { $0.id == updatedPlayer.id }) else {
            throw GameSessionStorageError.playerNotFound
        }
        
        players[index] = updatedPlayer
        return try savePlayers(players)
    }
    
    /// Invalidate the cache (call when data changes externally)
    func invalidateCache() {
        isDirty = true
    }
    
    /// Clear the cache entirely
    func clearCache() {
        cachedPlayers = nil
        isDirty = false
    }
}

// MARK: - Errors

enum GameSessionStorageError: Error, LocalizedError {
    case playerNotFound
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .playerNotFound:
            return "Player not found in session"
        case .encodingFailed:
            return "Failed to encode player data"
        case .decodingFailed:
            return "Failed to decode player data"
        }
    }
}
