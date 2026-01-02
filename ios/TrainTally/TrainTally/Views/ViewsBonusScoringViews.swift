//
//  BonusScoringViews.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Bonus and meeple scoring components separated from ContentView
//

import SwiftUI

// MARK: - Bonus Scoring Section

struct BonusScoringSection: View {
    @Binding var player: Player
    let gameVersion: GameVersion
    
    private var bonusPoints: Int {
        player.calculateBonusPoints(using: gameVersion) + 
        player.calculateStationPoints(using: gameVersion)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Bonuses")
                    .font(.headline)
                Spacer()
                Text("+\(bonusPoints) pts")
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            
            // Regular bonuses
            ForEach(gameVersion.bonuses) { bonus in
                BonusControl(
                    bonus: bonus,
                    currentValue: Binding(
                        get: { player.bonuses[bonus.id] ?? 0 },
                        set: { player.bonuses[bonus.id] = $0 }
                    )
                )
            }
            
            // Stations (Europe version)
            if gameVersion.features.hasStations {
                StationControl(
                    unusedStations: $player.unusedStations,
                    maxStations: gameVersion.stationsPerPlayer ?? 3
                )
            }
            
            // Meeples (Germany version)
            if gameVersion.features.hasMeeples, let meepleConfig = gameVersion.meepleConfig {
                MeepleSection(
                    player: $player,
                    meepleConfig: meepleConfig
                )
            }
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Bonus Control

struct BonusControl: View {
    let bonus: BonusConfig
    @Binding var currentValue: Int
    
    var body: some View {
        if bonus.isPerItem {
            // Stepper for per-item bonuses
            Stepper(value: $currentValue, in: 0...(bonus.maxCount ?? 10)) {
                HStack {
                    Text(bonus.displayName)
                    Spacer()
                    Text("\(currentValue) × \(bonus.points) pts")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // Toggle for exclusive bonuses
            Toggle(isOn: Binding(
                get: { currentValue > 0 },
                set: { currentValue = $0 ? 1 : 0 }
            )) {
                VStack(alignment: .leading) {
                    Text(bonus.displayName)
                    Text("+\(bonus.points) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Station Control

struct StationControl: View {
    @Binding var unusedStations: Int
    let maxStations: Int
    
    var body: some View {
        Stepper(value: $unusedStations, in: 0...maxStations) {
            HStack {
                Text("Unused Stations")
                Spacer()
                Text("\(unusedStations)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Meeple Section

struct MeepleSection: View {
    @Binding var player: Player
    let meepleConfig: MeepleConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)
            
            // Header
            Text("Meeples Collected")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Track meeples during the game. Bonuses calculated at game end.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Meeple color counters
            ForEach(meepleConfig.colors, id: \.self) { color in
                MeepleColorCounter(
                    color: color,
                    count: Binding(
                        get: { player.meeplesCollected[color] ?? 0 },
                        set: { player.meeplesCollected[color] = $0 }
                    )
                )
            }
            
            // Scoring info
            Divider()
                .padding(.vertical, 4)
            
            Text("Meeple Bonuses (awarded at game end)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("1st: \(meepleConfig.majorityPoints)pts per color, 2nd: \(meepleConfig.secondPlacePoints)pts")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }
}

// MARK: - Meeple Color Counter

struct MeepleColorCounter: View {
    let color: String
    @Binding var count: Int
    
    var body: some View {
        Stepper(value: $count, in: 0...10) {
            HStack {
                Circle()
                    .fill(meepleColor)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                Text(color.capitalized)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var meepleColor: Color {
        switch color.lowercased() {
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
