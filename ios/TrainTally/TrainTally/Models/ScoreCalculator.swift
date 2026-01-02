//
//  ScoreCalculator.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//

import Foundation

/// Handles all score calculation logic for a game session
/// Only calculates final scores when the game is complete
struct ScoreCalculator {
    let gameVersion: GameVersion
    let players: [Player]
    
    // MARK: - Final Score Calculation
    
    /// Calculate final scores for all players (only call when game is complete)
    func calculateFinalScores() -> [PlayerFinalScore] {
        // Calculate meeple points once for all players
        let meepleResults = calculateAllMeeplePointsWithDetails()
        
        // Calculate each player's final score
        return players.map { player in
            let routePoints = player.calculateRoutePoints(using: gameVersion)
            let ticketPoints = player.calculateTicketPoints()
            let bonusPoints = player.calculateBonusPoints(using: gameVersion)
            let stationPoints = player.calculateStationPoints(using: gameVersion)
            let meepleData = meepleResults[player.id] ?? (points: 0, details: [])
            
            let total = routePoints + ticketPoints + bonusPoints + stationPoints + meepleData.points
            
            // Get bonus details
            let bonusDetails = getBonusDetails(for: player)
            
            return PlayerFinalScore(
                player: player,
                routePoints: routePoints,
                ticketPoints: ticketPoints,
                bonusPoints: bonusPoints,
                stationPoints: stationPoints,
                meeplePoints: meepleData.points,
                totalScore: total,
                bonusDetails: bonusDetails,
                meepleDetails: meepleData.details
            )
        }
    }
    
    // MARK: - Bonus Details
    
    /// Get detailed breakdown of which bonuses a player earned
    private func getBonusDetails(for player: Player) -> [BonusDetail] {
        var details: [BonusDetail] = []
        
        for bonus in gameVersion.bonuses {
            let count = player.bonuses[bonus.id] ?? 0
            if count > 0 {
                let points = bonus.isPerItem ? (bonus.points * count) : bonus.points
                details.append(BonusDetail(bonusName: bonus.displayName, points: points))
            }
        }
        
        return details
    }
    
    /// Get sorted player scores (highest to lowest)
    func getSortedScores() -> [PlayerFinalScore] {
        calculateFinalScores().sorted { $0.totalScore > $1.totalScore }
    }
    
    /// Get the winner
    func getWinner() -> PlayerFinalScore? {
        getSortedScores().first
    }
    
    /// Get the player with the lowest score
    func getLoser() -> PlayerFinalScore? {
        getSortedScores().last
    }
    
    // MARK: - Meeple Scoring (Germany Edition)
    
    /// Calculate meeple majority points for all players with detailed breakdown
    private func calculateAllMeeplePointsWithDetails() -> [UUID: (points: Int, details: [MeepleDetail])] {
        // Check if this version has meeples
        guard gameVersion.features.hasMeeples,
              let meepleConfig = gameVersion.meepleConfig else {
            return [:]
        }
        
        var resultsByPlayer: [UUID: (points: Int, details: [MeepleDetail])] = [:]
        
        // For each meeple color, determine who gets points
        for color in meepleConfig.colors {
            let colorResults = calculateMeeplePointsForColorWithDetails(color, config: meepleConfig)
            
            // Add points and details to each player
            for (playerID, result) in colorResults {
                if resultsByPlayer[playerID] == nil {
                    resultsByPlayer[playerID] = (points: 0, details: [])
                }
                resultsByPlayer[playerID]!.points += result.points
                resultsByPlayer[playerID]!.details.append(result.detail)
            }
        }
        
        return resultsByPlayer
    }
    
    /// Calculate meeple points for a specific color with details
    private func calculateMeeplePointsForColorWithDetails(_ color: String, config: MeepleConfig) -> [UUID: (points: Int, detail: MeepleDetail)] {
        // Get all players' meeple counts for this color
        let playerCounts = players.map { player in
            (playerID: player.id, count: player.meeplesCollected[color] ?? 0)
        }
        
        // Group players by their count
        let countGroups = Dictionary(grouping: playerCounts, by: { $0.count })
            .sorted { $0.key > $1.key }
            .filter { $0.key > 0 }
        
        guard !countGroups.isEmpty else { return [:] }
        
        var results: [UUID: (points: Int, detail: MeepleDetail)] = [:]
        
        // Award first place points
        if let firstPlaceGroup = countGroups.first {
            let firstPlacePlayerIDs = firstPlaceGroup.value.map { $0.playerID }
            
            // Handle ties for first place
            if firstPlacePlayerIDs.count > 1 {
                let sharedPoints = (config.majorityPoints + config.secondPlacePoints) / firstPlacePlayerIDs.count
                for playerID in firstPlacePlayerIDs {
                    results[playerID] = (
                        points: sharedPoints,
                        detail: MeepleDetail(color: color, placement: "Tied 1st", points: sharedPoints)
                    )
                }
            } else {
                // Single first place winner
                results[firstPlacePlayerIDs[0]] = (
                    points: config.majorityPoints,
                    detail: MeepleDetail(color: color, placement: "1st", points: config.majorityPoints)
                )
                
                // Award second place if there is one
                if countGroups.count > 1 {
                    let secondPlaceGroup = countGroups[1]
                    let secondPlacePlayerIDs = secondPlaceGroup.value.map { $0.playerID }
                    
                    let secondPlacePoints = config.secondPlacePoints / secondPlacePlayerIDs.count
                    let placement = secondPlacePlayerIDs.count > 1 ? "Tied 2nd" : "2nd"
                    
                    for playerID in secondPlacePlayerIDs {
                        results[playerID] = (
                            points: secondPlacePoints,
                            detail: MeepleDetail(color: color, placement: placement, points: secondPlacePoints)
                        )
                    }
                }
            }
        }
        
        return results
    }
}

// MARK: - Player Final Score Model

/// Represents a player's complete final score breakdown
struct PlayerFinalScore: Identifiable {
    let player: Player
    let routePoints: Int
    let ticketPoints: Int
    let bonusPoints: Int
    let stationPoints: Int
    let meeplePoints: Int
    let totalScore: Int
    
    // Detailed breakdowns
    let bonusDetails: [BonusDetail]  // Which bonuses were earned
    let meepleDetails: [MeepleDetail]  // Which colors and placements
    
    var id: UUID { player.id }
    
    /// Score breakdown as a dictionary for display or export
    var breakdown: [String: Int] {
        [
            "Routes": routePoints,
            "Destination Tickets": ticketPoints,
            "Bonuses": bonusPoints,
            "Stations": stationPoints,
            "Meeples": meeplePoints,
            "Total": totalScore
        ]
    }
}

/// Details about a specific bonus earned
struct BonusDetail {
    let bonusName: String
    let points: Int
}

/// Details about meeple scoring for a specific color
struct MeepleDetail {
    let color: String
    let placement: String  // "1st" or "2nd"
    let points: Int
}

