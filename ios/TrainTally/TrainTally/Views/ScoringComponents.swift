//
//  ScoringComponents.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Scoring section components separated from ContentView
//

import SwiftUI

// MARK: - Train Cars Tracker

struct TrainCarsTrackerView: View {
    let player: Player
    let maxCars: Int
    
    private var carsUsed: Int {
        player.trainCarsUsed()
    }
    
    private var isOverLimit: Bool {
        carsUsed > maxCars
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "tram.fill")
                Text("Train Cars")
                    .fontWeight(.medium)
                Spacer()
                Text("\(carsUsed) / \(maxCars) used")
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: Double(carsUsed), total: Double(maxCars))
                .tint(isOverLimit ? .red : .blue)
            
            if isOverLimit {
                Text("⚠️ Over limit by \(carsUsed - maxCars) cars!")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Score Summary

struct ScoreSummaryView: View {
    let player: Player
    let gameVersion: GameVersion
    
    private var totalScore: Int {
        player.calculateTotalScore(using: gameVersion)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Current Score")
                .font(.headline)
            
            Text("\(totalScore)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.blue)
            
            // Breakdown
            VStack(alignment: .leading, spacing: 4) {
                ScoreBreakdownRow(
                    label: "Routes",
                    value: player.calculateRoutePoints(using: gameVersion)
                )
                ScoreBreakdownRow(
                    label: "Tickets",
                    value: player.calculateTicketPoints()
                )
                ScoreBreakdownRow(
                    label: "Bonuses",
                    value: player.calculateBonusPoints(using: gameVersion) + player.calculateStationPoints(using: gameVersion)
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Meeple note
            if gameVersion.features.hasMeeples {
                Text("Meeple bonuses calculated at game end")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Score Breakdown Row

struct ScoreBreakdownRow: View {
    let label: String
    let value: Int
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value >= 0 ? "+" : "")\(value)")
        }
    }
}
