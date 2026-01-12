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
    
    // New: For complex bonuses with custom scoring logic
    let scoringType: BonusScoringType?
    let scoringData: BonusScoringData?
    
    // Fallback for older configs without new fields
    enum CodingKeys: String, CodingKey {
        case id, displayName, points, description
        case isExclusive, isPerItem, maxCount
        case scoringType, scoringData
    }
}

// MARK: - Bonus Scoring Types

enum BonusScoringType: String, Codable {
    case simple              // Standard bonus (existing behavior)
    case playerRanked        // Points based on player ranking (e.g., Japan Bullet Train)
    case multipleRegions     // Can earn multiple times (e.g., Italy Connected Regions)
    case conditional         // Points depend on game state
}

struct BonusScoringData: Codable, Hashable {
    // For player-ranked bonuses (e.g., Japan's Bullet Train)
    let rankedPoints: [String: [Int]]?  // playerCount (as String) -> [points by rank]
    let noParticipationPenalty: Int?  // Penalty for not participating
    
    // For multiple region bonuses (e.g., Italy's Connected Regions)
    let regionPoints: [String: Int]?  // regionSize (as String) -> points
    
    // For conditional bonuses
    let condition: String?
    let conditionPoints: [String: Int]?
    
    enum CodingKeys: String, CodingKey {
        case rankedPoints, noParticipationPenalty
        case regionPoints, condition, conditionPoints
    }
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
    private var cachedVersions: [String: GameVersion] = [:]
    private var sharedBonuses: [String: BonusConfig]?
    private var sharedRouteScoringTables: [String: [RouteScore]]?
    
    // MARK: - Public API
    
    /// Load all game versions (uses index file for better performance)
    func loadConfig() -> GameVersionConfig? {
        if let cached = cachedConfig {
            return cached
        }
        
        // Try new modular format first
        if let modularConfig = loadModularConfig() {
            cachedConfig = modularConfig
            return modularConfig
        }
        
        // Fall back to legacy monolithic format
        if let legacyConfig = loadLegacyConfig() {
            cachedConfig = legacyConfig
            return legacyConfig
        }
        
        return nil
    }
    
    /// Get a specific version by ID (lazy loads only that version)
    func getVersion(byId id: String) -> GameVersion? {
        // Check cache first
        if let cached = cachedVersions[id] {
            return cached
        }
        
        // Try to load from individual file (new format)
        if let version = loadVersionFromFile(id: id) {
            cachedVersions[id] = version
            return version
        }
        
        // Fall back to loading from main config
        let version = loadConfig()?.versions.first { $0.id == id }
        if let version = version {
            cachedVersions[id] = version
        } else {
            print("[!] Warning: Could not find version with id '\(id)'")
            print("Available versions: \(allVersions.map { $0.id }.joined(separator: ", "))")
        }
        return version
    }
    
    /// Get all available versions
    var allVersions: [GameVersion] {
        loadConfig()?.versions ?? []
    }
    
    /// Get lightweight version metadata without loading full configs
    var versionMetadata: [GameVersionMetadata] {
        loadVersionIndex()?.versions ?? []
    }
    
    /// Clear all caches (useful for testing or dynamic reloading)
    func clearCache() {
        cachedConfig = nil
        cachedVersions.removeAll()
        sharedBonuses = nil
        sharedRouteScoringTables = nil
    }
    
    // MARK: - Private Loading Methods
    
    /// Load from new modular format (index + individual files)
    private func loadModularConfig() -> GameVersionConfig? {
        guard let index = loadVersionIndex() else {
            return nil
        }
        
        // Load shared configurations
        loadSharedConfigurations()
        
        // Load each version
        var versions: [GameVersion] = []
        for metadata in index.versions {
            if let version = loadVersionFromFile(id: metadata.id) {
                versions.append(version)
            }
        }
        
        guard !versions.isEmpty else {
            print("Error: No versions could be loaded from modular format")
            return nil
        }
        
        print("Successfully loaded \(versions.count) game version(s) from modular format")
        return GameVersionConfig(versions: versions)
    }
    
    /// Load the version index file
    private func loadVersionIndex() -> GameVersionIndex? {
        guard let url = Bundle.main.url(forResource: "game-versions-index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode(GameVersionIndex.self, from: data) else {
            return nil
        }
        return index
    }
    
    /// Load a specific version from its individual file
    private func loadVersionFromFile(id: String) -> GameVersion? {
        // Try direct file name based on ID
        let fileName = id.replacingOccurrences(of: "_", with: "-")
        guard let url = Bundle.main.url(forResource: "Versions/\(fileName)", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        do {
            var rawVersion = try JSONDecoder().decode(RawGameVersion.self, from: data)
            return resolveGameVersion(from: rawVersion)
        } catch {
            print("Error loading version '\(id)': \(error)")
            return nil
        }
    }
    
    /// Load shared configurations (bonuses and route scoring tables)
    private func loadSharedConfigurations() {
        // Load shared bonuses
        if sharedBonuses == nil {
            if let url = Bundle.main.url(forResource: "Shared/bonuses", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let config = try? JSONDecoder().decode(SharedBonusConfig.self, from: data) {
                sharedBonuses = config.bonuses
            }
        }
        
        // Load shared route scoring tables
        if sharedRouteScoringTables == nil {
            if let url = Bundle.main.url(forResource: "Shared/route-scoring", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let config = try? JSONDecoder().decode(SharedRouteScoringConfig.self, from: data) {
                sharedRouteScoringTables = config.scoringTables
            }
        }
    }
    
    /// Resolve references in a raw game version (bonuses, route scoring)
    private func resolveGameVersion(from raw: RawGameVersion) -> GameVersion {
        // Resolve route scoring
        let routeScoring: [RouteScore]
        if let scoringRef = raw.routeScoringRef {
            routeScoring = sharedRouteScoringTables?[scoringRef] ?? raw.routeScoring ?? []
        } else {
            routeScoring = raw.routeScoring ?? []
        }
        
        // Resolve bonuses
        let bonuses: [BonusConfig]
        if let bonusRefs = raw.bonusRefs {
            bonuses = bonusRefs.compactMap { sharedBonuses?[$0] }
        } else {
            bonuses = raw.bonuses ?? []
        }
        
        return GameVersion(
            id: raw.id,
            displayName: raw.displayName,
            minPlayers: raw.minPlayers,
            maxPlayers: raw.maxPlayers,
            trainCarsPerPlayer: raw.trainCarsPerPlayer,
            stationsPerPlayer: raw.stationsPerPlayer,
            playerColors: raw.playerColors,
            routeScoring: routeScoring,
            features: raw.features,
            bonuses: bonuses,
            meepleConfig: raw.meepleConfig
        )
    }
    
    /// Load from legacy monolithic format
    private func loadLegacyConfig() -> GameVersionConfig? {
        guard let url = Bundle.main.url(forResource: "game-versions", withExtension: "json") else {
            print("Error: Could not find game configuration files")
            print("Make sure either game-versions-index.json or game-versions.json is in your bundle")
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("Error: Could not read game-versions.json")
            return nil
        }
        
        do {
            let config = try JSONDecoder().decode(GameVersionConfig.self, from: data)
            print("Successfully loaded \(config.versions.count) game version(s) from legacy format")
            return config
        } catch {
            print("Error decoding game config: \(error)")
            printDecodingError(error)
            return nil
        }
    }
    
    /// Pretty print decoding errors
    private func printDecodingError(_ error: Error) {
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
    }
}

// MARK: - Supporting Types for Modular Loading

/// Lightweight metadata for version index
struct GameVersionIndex: Codable {
    let versions: [GameVersionMetadata]
    let metadata: IndexMetadata?
}

struct GameVersionMetadata: Codable, Identifiable {
    let id: String
    let displayName: String
    let minPlayers: Int
    let maxPlayers: Int
    let configFile: String?
}

struct IndexMetadata: Codable {
    let version: String
    let lastUpdated: String
}

/// Raw game version that may contain references to shared configs
struct RawGameVersion: Codable {
    let id: String
    let displayName: String
    let minPlayers: Int
    let maxPlayers: Int
    let trainCarsPerPlayer: Int
    let stationsPerPlayer: Int?
    let playerColors: [String]
    
    // Can be either inline data or a reference to shared config
    let routeScoring: [RouteScore]?
    let routeScoringRef: String?
    
    let features: FeatureFlags
    
    // Can be either inline data or references to shared bonuses
    let bonuses: [BonusConfig]?
    let bonusRefs: [String]?
    
    let meepleConfig: MeepleConfig?
    
    enum CodingKeys: String, CodingKey {
        case id, displayName, minPlayers, maxPlayers
        case trainCarsPerPlayer, stationsPerPlayer, playerColors
        case routeScoring  // Used for both routeScoring array and string reference
        case features, bonuses  // Used for both bonuses array and string array
        case meepleConfig
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        minPlayers = try container.decode(Int.self, forKey: .minPlayers)
        maxPlayers = try container.decode(Int.self, forKey: .maxPlayers)
        trainCarsPerPlayer = try container.decode(Int.self, forKey: .trainCarsPerPlayer)
        stationsPerPlayer = try container.decodeIfPresent(Int.self, forKey: .stationsPerPlayer)
        playerColors = try container.decode([String].self, forKey: .playerColors)
        features = try container.decode(FeatureFlags.self, forKey: .features)
        meepleConfig = try container.decodeIfPresent(MeepleConfig.self, forKey: .meepleConfig)
        
        // Try to decode routeScoring as array first, then as string reference
        if let scoring = try? container.decode([RouteScore].self, forKey: .routeScoring) {
            routeScoring = scoring
            routeScoringRef = nil
        } else if let ref = try? container.decode(String.self, forKey: .routeScoring) {
            routeScoring = nil
            routeScoringRef = ref
        } else {
            routeScoring = nil
            routeScoringRef = nil
        }
        
        // Try to decode bonuses as array first, then as string array references
        if let bonusArray = try? container.decode([BonusConfig].self, forKey: .bonuses) {
            bonuses = bonusArray
            bonusRefs = nil
        } else if let refs = try? container.decode([String].self, forKey: .bonuses) {
            bonuses = nil
            bonusRefs = refs
        } else {
            bonuses = nil
            bonusRefs = nil
        }
    }
}
/// Shared bonus configuration
struct SharedBonusConfig: Codable {
    let bonuses: [String: BonusConfig]
}

/// Shared route scoring tables
struct SharedRouteScoringConfig: Codable {
    let scoringTables: [String: [RouteScore]]
}

