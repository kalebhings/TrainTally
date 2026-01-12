//
//  LeaderboardViews.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/12/26.
//

import SwiftUI
import SwiftData

// MARK: - Main Leaderboard View

struct LeaderboardView: View {
    @State private var syncManager = CloudSyncManager.shared
    @State private var authManager = AuthenticationManager.shared
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if syncManager.dataSource == .cloud {
                CloudLeaderboardView()
            } else {
                LocalLeaderboardView()
            }
        }
        .navigationTitle("Leaderboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Local Leaderboard (SwiftData)

struct LocalLeaderboardView: View {
    @Query(
        filter: #Predicate<GameSession> { $0.isCompleted },
        sort: \GameSession.completedAt,
        order: .reverse
    ) private var completedGames: [GameSession]
    
    @State private var selectedVersion: String = "all"
    
    var body: some View {
        VStack(spacing: 0) {
            // Data source indicator
            HStack {
                Image(systemName: "iphone")
                Text("Local Leaderboard")
                    .font(.subheadline)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            
            // Version filter
            Picker("Game Version", selection: $selectedVersion) {
                Text("All Versions").tag("all")
                ForEach(GameConfigLoader.shared.allVersions) { version in
                    Text(version.displayName).tag(version.id)
                }
            }
            .pickerStyle(.menu)
            .padding()
            
            // Leaderboard content
            if filteredGames.isEmpty {
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "trophy",
                    description: Text("Play some games to see your stats here!")
                )
            } else {
                List {
                    Section("Your Stats") {
                        StatsRowView(title: "Games Played", value: "\(filteredGames.count)")
                        StatsRowView(title: "Total Wins", value: "\(totalWins)")
                        StatsRowView(title: "Win Rate", value: String(format: "%.1f%%", winRate))
                        if let avgScore = averageScore {
                            StatsRowView(title: "Average Score", value: String(format: "%.0f", avgScore))
                        }
                    }
                    
                    Section("Recent Games") {
                        ForEach(filteredGames.prefix(10)) { game in
                            LocalGameRowView(game: game)
                        }
                    }
                    
                    Section("High Scores") {
                        ForEach(topScores.prefix(10), id: \.gameId) { score in
                            HighScoreRowView(score: score)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredGames: [GameSession] {
        if selectedVersion == "all" {
            return completedGames
        }
        return completedGames.filter { $0.gameVersionId == selectedVersion }
    }
    
    private var totalWins: Int {
        filteredGames.compactMap { game in
            game.getWinner()
        }.count
    }
    
    private var winRate: Double {
        guard !filteredGames.isEmpty else { return 0 }
        return Double(totalWins) / Double(filteredGames.count) * 100
    }
    
    private var averageScore: Double? {
        let scores = filteredGames.compactMap { game -> Int? in
            guard let winner = game.getWinner() else { return nil }
            return winner.totalScore
        }
        
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    private var topScores: [(gameId: UUID, score: Int, playerName: String, version: String, date: Date)] {
        filteredGames.compactMap { game -> (UUID, Int, String, String, Date)? in
            guard let winner = game.getWinner(),
                  let version = game.gameVersion,
                  let date = game.completedAt else {
                return nil
            }
            
            return (game.id, winner.totalScore, winner.player.name, version.displayName, date)
        }
        .sorted { $0.score > $1.score }
    }
}

// MARK: - Cloud Leaderboard

struct CloudLeaderboardView: View {
    @State private var authManager = AuthenticationManager.shared
    @State private var leaderboard: LeaderboardResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedVersion = "all"
    
    var body: some View {
        VStack(spacing: 0) {
            // Data source indicator
            HStack {
                Image(systemName: "cloud")
                Text("Global Leaderboard")
                    .font(.subheadline)
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            
            // Version filter
            Picker("Game Version", selection: $selectedVersion) {
                Text("All Versions").tag("all")
                ForEach(GameConfigLoader.shared.allVersions) { version in
                    Text(version.displayName).tag(version.id)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .onChange(of: selectedVersion) { _, _ in
                Task {
                    await loadLeaderboard()
                }
            }
            
            // Content
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Error Loading Leaderboard",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if let leaderboard = leaderboard {
                    List {
                        ForEach(leaderboard.entries, id: \.userId) { entry in
                            CloudLeaderboardRowView(entry: entry)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "trophy",
                        description: Text("Leaderboard data not available")
                    )
                }
            }
        }
        .task {
            await loadLeaderboard()
        }
        .refreshable {
            await loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() async {
        guard authManager.isAuthenticated else {
            errorMessage = "Please sign in to view global leaderboards"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let token = try await authManager.getAuthToken()
            leaderboard = try await AWSAPIService.shared.fetchGlobalLeaderboard(
                token: token,
                gameVersion: selectedVersion
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Row Views

struct StatsRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

struct LocalGameRowView: View {
    let game: GameSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(game.gameVersion?.displayName ?? "Unknown")
                    .font(.headline)
                Spacer()
                if let date = game.completedAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let winner = game.getWinner() {
                HStack {
                    Circle()
                        .fill(winner.player.color.color)
                        .frame(width: 12, height: 12)
                    Text("\(winner.player.name) won with \(winner.totalScore) points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct HighScoreRowView: View {
    let score: (gameId: UUID, score: Int, playerName: String, version: String, date: Date)
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(score.playerName)
                    .font(.headline)
                Text(score.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(score.score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                Text(score.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CloudLeaderboardRowView: View {
    let entry: LeaderboardEntryData
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 36, height: 36)
                
                Text("#\(entry.rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label("\(entry.gamesPlayed)", systemImage: "gamecontroller.fill")
                    Label("\(entry.wins)", systemImage: "trophy.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", entry.score))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                
                Text("avg: \(String(format: "%.0f", entry.averageScore))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

#Preview("Local Leaderboard") {
    NavigationStack {
        LocalLeaderboardView()
    }
    .modelContainer(for: GameSession.self, inMemory: true)
}

#Preview("Cloud Leaderboard") {
    NavigationStack {
        CloudLeaderboardView()
    }
}
