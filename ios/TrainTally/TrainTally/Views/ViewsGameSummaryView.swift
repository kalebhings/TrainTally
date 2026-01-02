//
//  GameSummaryView.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Game completion summary view separated from ContentView
//

import SwiftUI

// MARK: - Game Summary View

struct GameSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: GameSession
    let onFinish: () -> Void
    
    private var sortedScores: [PlayerFinalScore] {
        session.getSortedScores() ?? []
    }
    
    var body: some View {
        NavigationStack {
            if session.gameVersion != nil {
                ScrollView {
                    VStack(spacing: 20) {
                        // Winner trophy
                        if let winner = sortedScores.first {
                            WinnerDisplay(winner: winner)
                        }
                        
                        // Ranked player list
                        PlayerRankingsList(scores: sortedScores)
                        
                        // Action button
                        SaveAndExitButton(action: {
                            saveAndFinish()
                        })
                    }
                }
                .navigationTitle("Game Complete")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { dismiss() }
                    }
                }
            }
        }
    }
    
    private func saveAndFinish() {
        // Save player names for future games
        let playerNames = session.players.map { $0.name }
        PlayerNameManager.shared.saveNames(playerNames)
        onFinish()
    }
}

// MARK: - Winner Display

struct WinnerDisplay: View {
    let winner: PlayerFinalScore
    
    var body: some View {
        VStack {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("🎉 \(winner.player.name) Wins! 🎉")
                .font(.title)
                .fontWeight(.bold)
            
            Text("\(winner.totalScore) points")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Player Rankings List

struct PlayerRankingsList: View {
    let scores: [PlayerFinalScore]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(scores.enumerated()), id: \.element.id) { index, finalScore in
                PlayerRankRow(
                    rank: index,
                    finalScore: finalScore
                )
            }
        }
        .padding()
    }
}

// MARK: - Player Rank Row

struct PlayerRankRow: View {
    let rank: Int
    let finalScore: PlayerFinalScore
    @State private var isExpanded = false
    
    private var isWinner: Bool {
        rank == 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row (tappable)
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    // Rank emoji
                    Text(rankEmoji)
                        .font(.title2)
                    
                    // Player color
                    Circle()
                        .fill(finalScore.player.color.color)
                        .frame(width: 12, height: 12)
                    
                    // Player name
                    Text(finalScore.player.name)
                        .fontWeight(isWinner ? .bold : .regular)
                    
                    Spacer()
                    
                    // Score
                    Text("\(finalScore.totalScore) pts")
                        .fontWeight(.semibold)
                    
                    // Expand/collapse icon
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .foregroundStyle(.primary)
            
            // Score breakdown (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    ScoreBreakdownView(finalScore: finalScore)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var rankEmoji: String {
        switch rank {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(rank + 1)."
        }
    }
    
    private var backgroundColor: Color {
        isWinner ? .yellow.opacity(0.2) : .gray.opacity(0.1)
    }
}

// MARK: - Score Breakdown View

struct ScoreBreakdownView: View {
    let finalScore: PlayerFinalScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Score Breakdown")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            
            // Routes
            if finalScore.routePoints > 0 {
                BreakdownRow(
                    icon: "tram.fill",
                    label: "Routes",
                    value: finalScore.routePoints,
                    color: .blue
                )
            }
            
            // Destination Tickets
            if finalScore.ticketPoints != 0 {
                BreakdownRow(
                    icon: "ticket.fill",
                    label: "Destination Tickets",
                    value: finalScore.ticketPoints,
                    color: finalScore.ticketPoints > 0 ? Color.green : Color.red
                )
            }
            
            // Bonuses with details
            if !finalScore.bonusDetails.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    BreakdownRow(
                        icon: "star.fill",
                        label: "Bonuses",
                        value: finalScore.bonusPoints,
                        color: .orange
                    )
                    
                    // Show each bonus
                    ForEach(finalScore.bonusDetails, id: \.bonusName) { bonus in
                        HStack {
                            Text("  • \(bonus.bonusName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+\(bonus.points)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            
            // Stations
            if finalScore.stationPoints > 0 {
                BreakdownRow(
                    icon: "building.2.fill",
                    label: "Unused Stations",
                    value: finalScore.stationPoints,
                    color: .purple
                )
            }
            
            // Meeples with details
            if !finalScore.meepleDetails.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    BreakdownRow(
                        icon: "person.3.fill",
                        label: "Meeple Majority",
                        value: finalScore.meeplePoints,
                        color: .pink
                    )
                    
                    // Show each color result
                    ForEach(finalScore.meepleDetails, id: \.color) { meeple in
                        HStack {
                            Circle()
                                .fill(colorForMeeple(meeple.color))
                                .frame(width: 10, height: 10)
                            Text("\(meeple.color.capitalized) (\(meeple.placement))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+\(meeple.points)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            
            // Total
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "sum")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                Text("Total")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(finalScore.totalScore) pts")
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            .font(.subheadline)
        }
        .font(.caption)
    }
    
    // Helper to convert meeple color string to SwiftUI Color
    private func colorForMeeple(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "yellow": return .yellow
        case "blue": return .blue
        case "pink": return .pink
        case "orange": return .orange
        case "white": return .white
        case "black": return .black
        default: return .gray
        }
    }
}

// MARK: - Breakdown Row

struct BreakdownRow: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(label)
            
            Spacer()
            
            Text("\(value >= 0 ? "+" : "")\(value)")
                .fontWeight(.medium)
                .foregroundStyle(value >= 0 ? Color.primary : Color.red)
        }
    }
}

// MARK: - Save and Exit Button

struct SaveAndExitButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Save & Exit")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
}
