//
//  ScoringView.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Separated from ContentView for better organization
//

import SwiftUI
import SwiftData

// MARK: - Main Scoring View

struct ScoringView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var session: GameSession
    @State private var selectedPlayerIndex = 0
    @State private var showingEndGame = false
    
    let onGameComplete: () -> Void
    
    var gameVersion: GameVersion? {
        session.gameVersion
    }
    
    var body: some View {
        NavigationStack {
            if let version = gameVersion {
                VStack(spacing: 0) {
                    // Player Tabs
                    PlayerTabsView(
                        players: session.players,
                        selectedIndex: $selectedPlayerIndex,
                        gameVersion: version
                    )
                    
                    // Scoring Content (swipeable)
                    TabView(selection: $selectedPlayerIndex) {
                        ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                            PlayerScoringView(
                                player: binding(for: index),
                                gameVersion: version
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .navigationTitle(version.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Exit") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Finish") {
                            showingEndGame = true
                        }
                    }
                }
                .sheet(isPresented: $showingEndGame) {
                    GameSummaryView(session: session) {
                        session.completeGame()
                        dismiss() // Dismiss the summary
                        onGameComplete() // Trigger navigation back to main menu
                    }
                }
            } else {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Could not load game version")
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func binding(for index: Int) -> Binding<Player> {
        Binding(
            get: { session.players[index] },
            set: { session.updatePlayer($0) }
        )
    }
}

// MARK: - Player Tabs

struct PlayerTabsView: View {
    let players: [Player]
    @Binding var selectedIndex: Int
    let gameVersion: GameVersion
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    PlayerTabButton(
                        player: player,
                        isSelected: selectedIndex == index,
                        gameVersion: gameVersion
                    ) {
                        withAnimation {
                            selectedIndex = index
                        }
                    }
                }
            }
            .padding()
        }
        .background(.bar)
    }
}

// MARK: - Player Tab Button

struct PlayerTabButton: View {
    let player: Player
    let isSelected: Bool
    let gameVersion: GameVersion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(player.name)
                    .fontWeight(isSelected ? .bold : .regular)
                Text("\(player.calculateTotalScore(using: gameVersion))")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? player.color.color.opacity(0.2) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(player.color.color, lineWidth: isSelected ? 2 : 1)
            )
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Player Scoring View

struct PlayerScoringView: View {
    @Binding var player: Player
    let gameVersion: GameVersion
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Train Cars Tracker
                TrainCarsTrackerView(player: player, maxCars: gameVersion.trainCarsPerPlayer)
                
                // Route Scoring
                RouteScoringSection(player: $player, gameVersion: gameVersion)
                
                // Destination Tickets
                DestinationTicketsSection(player: $player)
                
                // Bonuses
                BonusScoringSection(player: $player, gameVersion: gameVersion)
                
                // Score Summary
                ScoreSummaryView(player: player, gameVersion: gameVersion)
            }
            .padding()
        }
    }
}
