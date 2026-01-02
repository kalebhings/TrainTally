//
//  GameVersion.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/19/25.
//

import Foundation

// MARK: - Game Version Configuration
struct GameVersionConfig: Codable {
    let versions: [GameVersion]
}

struct RouteScore: Codable, Hashable {
    let length: Int
    let points: Int
}

struct GameVersion: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let minPlayers: Int
    let maxPlayers: Int
    let trainCarsPerPlayer: Int
    let stationsPerPlayer: Int?
    let playerColors: [String]  // Available player colors for this version
    let routeScoring: [RouteScore]
    let features: FeatureFlags
    let bonuses: [BonusConfig]
    let meepleConfig: MeepleConfig?
    
    // Computed property to get route scoring as sorted array
    var sortedRouteScoring: [(length: Int, points: Int)] {
        routeScoring
            .map { (length: $0.length, points: $0.points) }
            .sorted { $0.length < $1.length }
    }
    
    // Get max route length for this version
    var maxRouteLength: Int {
        sortedRouteScoring.last?.length ?? 6
    }
    
    // Get points for a specific route length
    func points(forRouteLength length: Int) -> Int {
        routeScoring.first(where: { $0.length == length })?.points ?? 0
    }
    
    // Get available player colors as PlayerColor enums
    var availablePlayerColors: [PlayerColor] {
        playerColors.compactMap { colorString in
            PlayerColor.from(string: colorString)
        }
    }
}

struct FeatureFlags: Codable, Hashable {
    let hasStations: Bool
    let hasMeeples: Bool
    let hasFerries: Bool
    let hasShips: Bool
}

struct BonusConfig: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let points: Int
    let description: String
    let isExclusive: Bool
    let isPerItem: Bool
    let maxCount: Int?
}

struct MeepleConfig: Codable, Hashable {
    let colors: [String]
    let majorityPoints: Int
    let secondPlacePoints: Int
}

// MARK: - Config Loader
class GameConfigLoader {
    static let shared = GameConfigLoader()
    
    private var cachedConfig: GameVersionConfig?
    
    func loadConfig() -> GameVersionConfig? {
        if let cached = cachedConfig {
            return cached
        }
        
        guard let url = Bundle.main.url(forResource: "game-versions", withExtension: "json") else {
            print("Error: Could not find game-versions.json in bundle")
            print("Make sure the file is added to your target's 'Copy Bundle Resources'")
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("Error: Could not read game-versions.json")
            return nil
        }
        
        do {
            let config = try JSONDecoder().decode(GameVersionConfig.self, from: data)
            cachedConfig = config
            print("Successfully loaded \(config.versions.count) game version(s)")
            return config
        } catch {
            print("Error decoding game config: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key '\(key.stringValue)' at: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch for type '\(type)' at: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found for type '\(type)' at: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at: \(context.codingPath)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            return nil
        }
    }
    
    func getVersion(byId id: String) -> GameVersion? {
        let version = loadConfig()?.versions.first { $0.id == id }
        if version == nil {
            print("[!] Warning: Could not find version with id '\(id)'")
            print("Available versions: \(allVersions.map { $0.id }.joined(separator: ", "))")
        }
        return version
    }
    
    var allVersions: [GameVersion] {
        loadConfig()?.versions ?? []
    }
}
