//
//  HistoryViews.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Separated from ContentView for better organization
//

import SwiftUI
import SwiftData

// MARK: - History List View

struct HistoryView: View {
    @Query(
        filter: #Predicate<GameSession> { $0.isCompleted == true },
        sort: \GameSession.startedAt,
        order: .reverse
    ) private var gameSessions: [GameSession]
    
    var body: some View {
        List {
            if gameSessions.isEmpty {
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "clock",
                    description: Text("Your completed games will appear here")
                )
            } else {
                ForEach(gameSessions) { session in
                    HistoryRowView(session: session)
                }
            }
        }
        .navigationTitle("History")
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let session: GameSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Game version and completion status
            HStack {
                Text(session.gameVersion?.displayName ?? "Unknown")
                    .fontWeight(.medium)
                Spacer()
                if session.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            // Player count
            Text("\(session.playerCount) players")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Winner info (only for completed games)
            if session.isCompleted, let winner = session.getWinner() {
                Text("Winner: \(winner.player.name) - \(winner.totalScore) pts")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            // Date
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
