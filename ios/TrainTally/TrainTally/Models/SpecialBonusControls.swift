//
//  SpecialBonusControls.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/12/26.
//

import SwiftUI

// MARK: - Special Bonus Control Router

/// Routes to appropriate UI control based on bonus type
struct SpecialBonusControl: View {
    let bonus: BonusConfig
    @Binding var player: Player
    let playerCount: Int
    
    var body: some View {
        if let scoringType = bonus.scoringType {
            switch scoringType {
            case .simple:
                StandardBonusControl(bonus: bonus, currentValue: bindingForBonus(bonus.id))
            case .playerRanked:
                PlayerRankedBonusControl(bonus: bonus, currentValue: bindingForBonus(bonus.id), playerCount: playerCount)
            case .multipleRegions:
                MultipleRegionsBonusControl(bonus: bonus, player: $player)
            case .conditional:
                ConditionalBonusControl(bonus: bonus, currentValue: bindingForBonus(bonus.id))
            }
        } else {
            // Legacy bonus
            StandardBonusControl(bonus: bonus, currentValue: bindingForBonus(bonus.id))
        }
    }
    
    private func bindingForBonus(_ bonusId: String) -> Binding<Int> {
        Binding(
            get: { player.bonuses[bonusId] ?? 0 },
            set: { player.bonuses[bonusId] = $0 }
        )
    }
}

// MARK: - Standard Bonus Control

struct StandardBonusControl: View {
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

// MARK: - Player Ranked Bonus (e.g., Japan Bullet Train)

struct PlayerRankedBonusControl: View {
    let bonus: BonusConfig
    @Binding var currentValue: Int
    let playerCount: Int
    
    @State private var showInfo = false
    @State private var sliderValue: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bonus.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Button {
                    showInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            
            Text(bonus.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Slider with +/- buttons
            VStack(spacing: 8) {
                HStack {
                    Text("Bullet Trains Completed")
                        .font(.caption)
                    Spacer()
                    Text("\(currentValue)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .frame(minWidth: 40)
                }
                
                HStack(spacing: 12) {
                    Button {
                        if currentValue > 0 {
                            currentValue -= 1
                            sliderValue = Double(currentValue)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(currentValue > 0 ? .blue : .gray)
                    }
                    .disabled(currentValue <= 0)
                    
                    Slider(value: $sliderValue, in: 0...30, step: 1)
                        .onChange(of: sliderValue) { _, newValue in
                            currentValue = Int(newValue)
                        }
                        .onChange(of: currentValue) { _, newValue in
                            sliderValue = Double(newValue)
                        }
                    
                    Button {
                        if currentValue < 30 {
                            currentValue += 1
                            sliderValue = Double(currentValue)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(currentValue < 30 ? .blue : .gray)
                    }
                    .disabled(currentValue >= 30)
                }
            }
            .padding(8)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Show expected points
            if let expectedPoints = getExpectedPoints() {
                HStack {
                    Text("Expected Points:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(expectedPoints >= 0 ? "+\(expectedPoints)" : "\(expectedPoints)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(expectedPoints >= 0 ? .green : .red)
                }
                .padding(.top, 4)
            }
            
            // Info sheet
            if showInfo {
                scoringInfoView
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            sliderValue = Double(currentValue)
        }
    }
    
    private var scoringInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scoring for \(playerCount) players:")
                .font(.caption2)
                .fontWeight(.semibold)
            
            if let scoringData = bonus.scoringData,
               let rankedPoints = scoringData.rankedPoints,
               let pointsForPlayerCount = rankedPoints[String(playerCount)] {
                
                ForEach(Array(pointsForPlayerCount.enumerated()), id: \.offset) { index, points in
                    HStack {
                        Text(ordinalString(for: index + 1))
                        Spacer()
                        Text(points >= 0 ? "+\(points) pts" : "\(points) pts")
                            .monospacedDigit()
                    }
                    .font(.caption2)
                }
                
                if let penalty = scoringData.noParticipationPenalty {
                    Divider()
                    HStack {
                        Text("No bullet trains")
                        Spacer()
                        Text("\(penalty) pts")
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func getExpectedPoints() -> Int? {
        // This shows expected points IF player is 1st
        // Actual points calculated at game end
        guard let scoringData = bonus.scoringData,
              let rankedPoints = scoringData.rankedPoints,
              let pointsForPlayerCount = rankedPoints[String(playerCount)] else {
            return nil
        }
        
        if currentValue == 0 {
            return scoringData.noParticipationPenalty
        }
        
        // Assume best case (1st place) for preview
        return pointsForPlayerCount.first
    }
    
    private func ordinalString(for number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Multiple Regions Bonus (e.g., Italy Connected Regions)

struct MultipleRegionsBonusControl: View {
    let bonus: BonusConfig
    @Binding var player: Player
    
    @State private var showRegionEntry = false
    @State private var regions: [ConnectedRegion] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(bonus.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(bonus.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        showRegionEntry.toggle()
                    }
                } label: {
                    Image(systemName: showRegionEntry ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            
            // Current regions summary
            if !regions.isEmpty {
                HStack {
                    Text("\(regions.count) region(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("+\(totalPoints) pts")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)
            } else {
                Text("No regions added yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            
            // Region entry
            if showRegionEntry {
                regionEntryView
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadRegions()
        }
    }
    
    private var regionEntryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Regions:")
                .font(.caption)
                .fontWeight(.medium)
            
            if regions.isEmpty {
                Text("Tap the + button to add a region")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            ForEach(Array(regions.enumerated()), id: \.element.id) { index, region in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Region \(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(pointsForRegion(size: region.size)) pts")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                if region.size > 1 {
                                    regions[index].size -= 1
                                    saveRegions()
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(region.size > 1 ? .blue : .gray)
                            }
                            .disabled(region.size <= 1)
                            
                            Text("\(region.size) regions")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .frame(minWidth: 70)
                            
                            Button {
                                if region.size < 17 {
                                    regions[index].size += 1
                                    saveRegions()
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(region.size < 17 ? .blue : .gray)
                            }
                            .disabled(region.size >= 17)
                        }
                    }
                    
                    Button {
                        withAnimation {
                            regions.remove(at: index)
                            saveRegions()
                        }
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                }
                .padding(8)
                .background(Color.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Button {
                withAnimation {
                    regions.append(ConnectedRegion(size: 1))
                    saveRegions()
                }
            } label: {
                Label("Add Region Connection", systemImage: "plus.circle.fill")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var totalPoints: Int {
        regions.reduce(0) { $0 + pointsForRegion(size: $1.size) }
    }
    
    private func pointsForRegion(size: Int) -> Int {
        guard let scoringData = bonus.scoringData,
              let regionPoints = scoringData.regionPoints else {
            return 0
        }
        return regionPoints[String(size)] ?? 0
    }
    
    private func loadRegions() {
        // Load from player.bonusData
        guard let dataString = player.bonusData[bonus.id],
              let data = dataString.data(using: .utf8),
              let decodedRegions = try? JSONDecoder().decode([ConnectedRegionData].self, from: data) else {
            regions = []
            return
        }
        
        regions = decodedRegions.map { ConnectedRegion(id: $0.id, size: $0.size) }
    }
    
    private func saveRegions() {
        // Save to player.bonusData as JSON
        let regionData = regions.map { ConnectedRegionData(id: $0.id, size: $0.size) }
        if let data = try? JSONEncoder().encode(regionData),
           let jsonString = String(data: data, encoding: .utf8) {
            player.bonusData[bonus.id] = jsonString
        }
    }
}

struct ConnectedRegion: Identifiable {
    var id = UUID()
    var size: Int
}

struct ConnectedRegionData: Codable {
    let id: UUID
    let size: Int
}

// MARK: - Conditional Bonus Control

struct ConditionalBonusControl: View {
    let bonus: BonusConfig
    @Binding var currentValue: Int
    
    var body: some View {
        Stepper(value: $currentValue, in: 0...10) {
            HStack {
                Text(bonus.displayName)
                Spacer()
                Text("\(currentValue)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
