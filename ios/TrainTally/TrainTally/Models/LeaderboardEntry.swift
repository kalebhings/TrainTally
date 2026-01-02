//
//  LeaderboardEntry.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//

import Foundation

/// Represents a game session entry for cloud leaderboards
/// This is a lightweight, serializable snapshot of a completed game
struct LeaderboardEntry: Codable, Identifiable {
    let id: UUID
    let gameSessionId: UUID
    let gameVersionId: String
    let playerCount: Int
    let winnerName: String
    let winnerScore: Int
    let lowestScore: Int
    let allScores: [PlayerScore]  // All player scores with names
    let timestamp: Date
    let userId: String?
    let groupId: String?
    
    init(from session: GameSession, userId: String? = nil, groupId: String? = nil) {
        guard let version = session.gameVersion else {
            fatalError("Cannot create leaderboard entry without valid game version")
        }
        
        // Calculate final scores
        let calculator = ScoreCalculator(gameVersion: version, players: session.players)
        let finalScores = calculator.getSortedScores()
        
        self.id = UUID()
        self.gameSessionId = session.id
        self.gameVersionId = session.gameVersionId
        self.playerCount = session.playerCount
        
        // Winner info
        self.winnerName = finalScores.first?.player.name ?? "Unknown"
        self.winnerScore = finalScores.first?.totalScore ?? 0
        self.lowestScore = finalScores.last?.totalScore ?? 0
        
        // All player scores
        self.allScores = finalScores.map { score in
            PlayerScore(
                playerName: score.player.name,
                score: score.totalScore,
                breakdown: score.breakdown
            )
        }
        
        self.timestamp = session.completedAt ?? Date()
        self.userId = userId
        self.groupId = groupId
    }
}

// MARK: - Player Score for Leaderboard

struct PlayerScore: Codable {
    let playerName: String
    let score: Int
    let breakdown: [String: Int]  // Detailed score breakdown
}
