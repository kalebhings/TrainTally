//
//  BonusCalculator.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/12/26.
//

import Foundation

/// Handles complex bonus calculations for different game versions
struct BonusCalculator {
    let gameVersion: GameVersion
    let players: [Player]
    
    // MARK: - Calculate Bonus Points
    
    /// Calculate bonus points for a specific player
    func calculateBonusPoints(for player: Player) -> Int {
        var totalPoints = 0
        
        for bonus in gameVersion.bonuses {
            let points = calculateBonus(bonus, for: player)
            totalPoints += points
        }
        
        return totalPoints
    }
    
    /// Calculate detailed bonus breakdown for all players (for final scoring)
    func calculateDetailedBonuses() -> [UUID: [BonusDetail]] {
        var detailsByPlayer: [UUID: [BonusDetail]] = [:]
        
        for player in players {
            var details: [BonusDetail] = []
            
            for bonus in gameVersion.bonuses {
                let points = calculateBonus(bonus, for: player)
                let count = player.bonuses[bonus.id] ?? 0
                
                if points != 0 || count > 0 {
                    details.append(BonusDetail(
                        bonusName: bonus.displayName,
                        points: points,
                        count: count
                    ))
                }
            }
            
            detailsByPlayer[player.id] = details
        }
        
        return detailsByPlayer
    }
    
    // MARK: - Calculate Individual Bonus
    
    private func calculateBonus(_ bonus: BonusConfig, for player: Player) -> Int {
        guard let scoringType = bonus.scoringType else {
            // Legacy simple bonus
            return calculateSimpleBonus(bonus, for: player)
        }
        
        switch scoringType {
        case .simple:
            return calculateSimpleBonus(bonus, for: player)
        case .playerRanked:
            return calculatePlayerRankedBonus(bonus, for: player)
        case .multipleRegions:
            return calculateMultipleRegionsBonus(bonus, for: player)
        case .conditional:
            return calculateConditionalBonus(bonus, for: player)
        }
    }
    
    // MARK: - Simple Bonus
    
    private func calculateSimpleBonus(_ bonus: BonusConfig, for player: Player) -> Int {
        let count = player.bonuses[bonus.id] ?? 0
        
        if bonus.isPerItem {
            return bonus.points * count
        } else {
            return count > 0 ? bonus.points : 0
        }
    }
    
    // MARK: - Player Ranked Bonus (e.g., Japan Bullet Train)
    
    private func calculatePlayerRankedBonus(_ bonus: BonusConfig, for player: Player) -> Int {
        guard let scoringData = bonus.scoringData,
              let rankedPoints = scoringData.rankedPoints else {
            return 0
        }
        
        let playerCount = players.count
        guard let pointsArray = rankedPoints[String(playerCount)] else {
            print("Warning: No ranking points defined for \(playerCount) players")
            return 0
        }
        
        // Get player's count for this bonus
        let playerValue = player.bonuses[bonus.id] ?? 0
        
        // If player didn't participate, apply penalty
        if playerValue == 0 {
            return scoringData.noParticipationPenalty ?? 0
        }
        
        // Get all players' values and rank them
        let playerValues = players.map { ($0.id, $0.bonuses[bonus.id] ?? 0) }
            .filter { $0.1 > 0 }  // Only players who participated
            .sorted { $0.1 > $1.1 }  // Sort by value (highest first)
        
        // Find player's rank
        guard let playerIndex = playerValues.firstIndex(where: { $0.0 == player.id }) else {
            return scoringData.noParticipationPenalty ?? 0
        }
        
        // Handle ties - players with same value get average of their ranks
        let playerVal = playerValues[playerIndex].1
        let tiedPlayers = playerValues.filter { $0.1 == playerVal }
        
        if tiedPlayers.count > 1 {
            // Calculate average points for tied positions
            let startRank = playerIndex
            let endRank = min(startRank + tiedPlayers.count - 1, pointsArray.count - 1)
            let tiedPoints = (startRank...endRank).map { pointsArray[$0] }
            return tiedPoints.reduce(0, +) / tiedPlayers.count
        } else {
            // No tie, use direct rank
            return playerIndex < pointsArray.count ? pointsArray[playerIndex] : 0
        }
    }
    
    // MARK: - Multiple Regions Bonus (e.g., Italy Connected Regions)
    
    private func calculateMultipleRegionsBonus(_ bonus: BonusConfig, for player: Player) -> Int {
        guard let scoringData = bonus.scoringData,
              let regionPoints = scoringData.regionPoints else {
            return 0
        }
        
        // Get stored regions data from player.bonusData
        if let dataString = player.bonusData[bonus.id],
           let data = dataString.data(using: .utf8),
           let regions = try? JSONDecoder().decode([ConnectedRegionData].self, from: data) {
            // Calculate total points from all regions
            var totalPoints = 0
            for region in regions {
                let points = regionPoints[String(region.size)] ?? 0
                totalPoints += points
            }
            return totalPoints
        }
        
        return 0
    }
    
    // Region data structure for decoding
    private struct ConnectedRegionData: Codable {
        let id: UUID
        let size: Int
    }
    
    // MARK: - Conditional Bonus
    
    private func calculateConditionalBonus(_ bonus: BonusConfig, for player: Player) -> Int {
        guard let scoringData = bonus.scoringData,
              let condition = scoringData.condition,
              let conditionPoints = scoringData.conditionPoints else {
            return 0
        }
        
        // Evaluate condition and return appropriate points
        // This is extensible for future conditional bonuses
        let conditionMet = player.bonuses[condition] ?? 0
        let conditionKey = String(conditionMet)
        
        return conditionPoints[conditionKey] ?? 0
    }
}

// MARK: - Enhanced Bonus Detail

struct BonusDetail {
    let bonusName: String
    let points: Int
    let count: Int
    
    init(bonusName: String, points: Int, count: Int = 0) {
        self.bonusName = bonusName
        self.points = points
        self.count = count
    }
}
