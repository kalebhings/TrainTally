//
//  AWSAPIService.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/6/26.
//

import Foundation

class AWSAPIService {
    static let shared = AWSAPIService()
    
    private let baseURL = AWSConfiguration.apiEndpoint
    
    // MARK: - Game Submission
    
    /// Submit a completed game to the backend
    func submitGame(_ gameSession: GameSession, token: String) async throws {
        guard let url = URL(string: "\(baseURL)/games") else {
            throw APIError.invalidURL
        }
        
        guard let gameVersion = gameSession.gameVersion else {
            throw APIError.invalidGameData("Game version not found")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the request body matching the backend schema
        let gamePayload = GameSubmissionRequest(
            gameVersion: gameVersion.id,
            players: gameSession.players.map { player in
                PlayerPayload(
                    name: player.name,
                    color: player.color.rawValue,
                    score: player.calculateTotalScore(using: gameVersion),
                    trainCarsUsed: player.trainCarsUsed(),
                    destinationTickets: player.destinationTickets.map { ticket in
                        TicketPayload(
                            description: ticket.description,
                            points: ticket.pointValue,
                            completed: ticket.isCompleted
                        )
                    },
                    routePoints: player.calculateRoutePoints(using: gameVersion),
                    bonuses: player.bonuses.compactMap { bonusEntry in
                        if let bonus = gameVersion.bonuses.first(where: { $0.id == bonusEntry.key }) {
                            return BonusPayload(id: bonus.id, points: bonus.points * bonusEntry.value)
                        }
                        return nil
                    },
                    meeplePoints: gameVersion.features.hasMeeples ? 
                        player.calculateBonusPoints(using: gameVersion) : nil
                )
            },
            datePlayed: (gameSession.completedAt ?? gameSession.startedAt).iso8601String,
            shareWithGroups: []  // TODO: Add group sharing support
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(gamePayload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message from response
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorBody["error"] {
                throw APIError.serverError(message: errorMessage)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Game History
    
    /// Fetch user's game history from the cloud
    func fetchGameHistory(token: String, limit: Int = 20) async throws -> GameHistoryResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/games")!
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GameHistoryResponse.self, from: data)
    }
    
    // MARK: - Leaderboards
    
    /// Fetch global leaderboard
    func fetchGlobalLeaderboard(
        token: String,
        gameVersion: String = "all",
        limit: Int = 50
    ) async throws -> LeaderboardResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/leaderboards/global")!
        urlComponents.queryItems = [
            URLQueryItem(name: "gameVersion", value: gameVersion),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "timeframe", value: "all")
        ]
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LeaderboardResponse.self, from: data)
    }
    
    /// Fetch group leaderboard
    func fetchGroupLeaderboard(
        token: String,
        groupId: String,
        gameVersion: String = "all",
        limit: Int = 50
    ) async throws -> LeaderboardResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/leaderboards/groups/\(groupId)")!
        urlComponents.queryItems = [
            URLQueryItem(name: "gameVersion", value: gameVersion),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LeaderboardResponse.self, from: data)
    }
    
    // MARK: - Groups
    
    /// Create a new group
    func createGroup(token: String, name: String, description: String, isPrivate: Bool) async throws -> GroupResponse {
        guard let url = URL(string: "\(baseURL)/groups") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = CreateGroupRequest(
            groupName: name,
            description: description,
            isPrivate: isPrivate
        )
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(GroupResponse.self, from: data)
    }
    
    /// Join a group with invite code
    func joinGroup(token: String, inviteCode: String) async throws {
        guard let url = URL(string: "\(baseURL)/groups/join") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["inviteCode": inviteCode]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// List user's groups
    func listGroups(token: String) async throws -> [GroupInfo] {
        guard let url = URL(string: "\(baseURL)/groups") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(GroupListResponse.self, from: data)
        return result.groups
    }
}

// MARK: - API Models

struct GameSubmissionRequest: Codable {
    let gameVersion: String
    let players: [PlayerPayload]
    let datePlayed: String
    let shareWithGroups: [String]
}

struct PlayerPayload: Codable {
    let name: String
    let color: String
    let score: Int
    let trainCarsUsed: Int
    let destinationTickets: [TicketPayload]
    let routePoints: Int
    let bonuses: [BonusPayload]
    let meeplePoints: Int?
}

struct TicketPayload: Codable {
    let description: String
    let points: Int
    let completed: Bool
}

struct BonusPayload: Codable {
    let id: String
    let points: Int
}

struct GameHistoryResponse: Codable {
    let games: [GameData]
    let count: Int
    let lastKey: String?
}

struct GameData: Codable {
    let gameId: String
    let gameVersion: String
    let players: [PlayerPayload]
    let datePlayed: String
    let winner: WinnerData
    let timestamp: Int
}

struct WinnerData: Codable {
    let name: String
    let score: Int
    let color: String
}

struct LeaderboardResponse: Codable {
    let entries: [LeaderboardEntryData]
    let count: Int
    let gameVersion: String?
    let leaderboardType: String?
}

struct LeaderboardEntryData: Codable {
    let rank: Int
    let userId: String
    let username: String
    let score: Double
    let gamesPlayed: Int
    let wins: Int
    let averageScore: Double
    let lastUpdated: String?
}

struct CreateGroupRequest: Codable {
    let groupName: String
    let description: String
    let isPrivate: Bool
}

struct GroupResponse: Codable {
    let groupId: String
    let inviteCode: String
    let group: GroupInfo
}

struct GroupInfo: Codable {
    let groupId: String
    let groupName: String
    let description: String
    let memberCount: Int
    let role: String?
    let inviteCode: String?
    let createdAt: String
}

struct GroupListResponse: Codable {
    let groups: [GroupInfo]
    let count: Int
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidGameData(String)
    case httpError(statusCode: Int)
    case serverError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidGameData(let message):
            return "Invalid game data: \(message)"
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Date Extension
extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}


