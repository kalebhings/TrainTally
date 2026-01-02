//
//  MenuViews.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Separated from ContentView for better organization
//

import SwiftUI
import SwiftData

// MARK: - Main Menu

struct MainMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<GameSession> { $0.isCompleted == true },
        sort: \GameSession.startedAt,
        order: .reverse
    ) private var completedGames: [GameSession]
    
    @State private var showingNewGame = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // App Title
                AppTitleView()
                
                Spacer()
                
                // Main Menu Buttons
                VStack(spacing: 16) {
                    // New Game Button
                    Button {
                        showingNewGame = true
                    } label: {
                        MenuButtonLabel(
                            icon: "plus.circle.fill",
                            title: "New Game",
                            style: .primary
                        )
                    }
                    
                    // History Button
                    NavigationLink {
                        HistoryView()
                    } label: {
                        MenuButtonLabel(
                            icon: "clock.fill",
                            title: "History",
                            style: .secondary
                        )
                    }
                    
                    // Leaderboard Button
                    NavigationLink {
                        LeaderboardView()
                    } label: {
                        MenuButtonLabel(
                            icon: "trophy.fill",
                            title: "Leaderboard",
                            style: .secondary
                        )
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Recent games count
                if !completedGames.isEmpty {
                    Text("\(completedGames.count) game\(completedGames.count == 1 ? "" : "s") played")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .sheet(isPresented: $showingNewGame) {
                GameSetupView()
            }
        }
    }
}

// MARK: - App Title Component

struct AppTitleView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("TrainTally")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Ticket to Ride Scorer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }
}

// MARK: - Menu Button Label Component

struct MenuButtonLabel: View {
    let icon: String
    let title: String
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
        }
        .font(.title2)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .padding()
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return .blue
        case .secondary: return .gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .primary
        }
    }
}

// MARK: - Leaderboard (Placeholder)

struct LeaderboardView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "trophy",
            description: Text("Leaderboards will be available soon")
        )
        .navigationTitle("Leaderboard")
    }
}
