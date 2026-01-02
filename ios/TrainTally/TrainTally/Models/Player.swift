//
//  Player.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/19/25.
//

import Foundation
import SwiftUI

// MARK: - Player Color
enum PlayerColor: String, CaseIterable, Codable, Identifiable {
    case red
    case blue
    case green
    case yellow
    case black
    case purple
    case white
    case orange
    case pink
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .black: return .black
        case .purple: return .purple
        case .white: return Color(white: 0.95) // Light gray for visibility
        case .orange: return .orange
        case .pink: return .pink
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    // Convert string to PlayerColor
    static func from(string: String) -> PlayerColor? {
        return PlayerColor(rawValue: string.lowercased())
    }
}

// MARK: - Destination Ticket
struct DestinationTicket: Identifiable, Codable, Hashable {
    let id: UUID
    var pointValue: Int
    var isCompleted: Bool
    var description: String
    
    init(pointValue: Int, isCompleted: Bool, description: String = "") {
        self.id = UUID()
        self.pointValue = pointValue
        self.isCompleted = isCompleted
        self.description = description
    }
    
    var actualPoints: Int {
        isCompleted ? pointValue : -pointValue
    }
}

// MARK: - Player
struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: PlayerColor
    
    // Route tracking: [routeLength: count]
    var routesClaimed: [Int: Int]
    
    // Destination tickets
    var destinationTickets: [DestinationTicket]
    
    // Bonuses earned (bonus id -> count or bool as int)
    var bonuses: [String: Int]
    
    // For Europe - stations
    var unusedStations: Int
    
    // For Germany - meeples collected per color
    var meeplesCollected: [String: Int]
    
    init(name: String, color: PlayerColor) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.routesClaimed = [:]
        self.destinationTickets = []
        self.bonuses = [:]
        self.unusedStations = 0
        self.meeplesCollected = [:]
    }
    
    // MARK: - Scoring Calculations
    
    func calculateRoutePoints(using gameVersion: GameVersion) -> Int {
        var total = 0
        for (length, count) in routesClaimed {
            let pointsPerRoute = gameVersion.points(forRouteLength: length)
            total += pointsPerRoute * count
        }
        return total
    }
    
    func calculateTicketPoints() -> Int {
        destinationTickets.reduce(0) { $0 + $1.actualPoints }
    }
    
    func calculateBonusPoints(using gameVersion: GameVersion) -> Int {
        var total = 0
        for bonus in gameVersion.bonuses {
            if let count = bonuses[bonus.id], count > 0 {
                if bonus.isPerItem {
                    total += bonus.points * count
                } else {
                    total += bonus.points
                }
            }
        }
        return total
    }
    
    func calculateStationPoints(using gameVersion: GameVersion) -> Int {
        guard gameVersion.features.hasStations else { return 0 }
        // Find the unused_stations bonus config
        if let stationBonus = gameVersion.bonuses.first(where: { $0.id == "unused_stations" }) {
            return unusedStations * stationBonus.points
        }
        return 0
    }
    
    func calculateTotalScore(using gameVersion: GameVersion) -> Int {
        calculateRoutePoints(using: gameVersion) +
        calculateTicketPoints() +
        calculateBonusPoints(using: gameVersion) +
        calculateStationPoints(using: gameVersion)
    }
    
    // MARK: - Train Car Tracking
    
    func trainCarsUsed() -> Int {
        routesClaimed.reduce(0) { total, entry in
            total + (entry.key * entry.value)
        }
    }
    
    func trainCarsRemaining(maxCars: Int) -> Int {
        maxCars - trainCarsUsed()
    }
    
    // MARK: - Route Helpers
    
    mutating func addRoute(length: Int) {
        routesClaimed[length, default: 0] += 1
    }
    
    mutating func removeRoute(length: Int) {
        guard let current = routesClaimed[length], current > 0 else { return }
        if current == 1 {
            routesClaimed.removeValue(forKey: length)
        } else {
            routesClaimed[length] = current - 1
        }
    }
    
    func routeCount(forLength length: Int) -> Int {
        routesClaimed[length] ?? 0
    }
    
    var totalRoutesClaimed: Int {
        routesClaimed.values.reduce(0, +)
    }
}
