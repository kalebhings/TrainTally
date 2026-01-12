//
//  GameSetupView.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Separated from ContentView for better organization
//

import SwiftUI
import SwiftData

// MARK: - Game Setup View

struct GameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedVersion: GameVersion?
    @State private var playerCount = 2
    @State private var playerNames: [String] = ["Player 1", "Player 2"]
    @State private var playerColors: [PlayerColor] = [.red, .blue]
    @State private var currentSession: GameSession?
    @State private var shouldDismissToRoot = false
    
    @StateObject private var nameManager = PlayerNameManager.shared
    
    private let gameVersions = GameConfigLoader.shared.allVersions
    
    var body: some View {
        NavigationStack {
            Form {
                // Game Version Selection
                GameVersionSection(
                    selectedVersion: $selectedVersion,
                    gameVersions: gameVersions
                )
                
                // Player Configuration
                if let version = selectedVersion {
                    PlayerConfigurationSection(
                        version: version,
                        playerCount: $playerCount,
                        playerNames: $playerNames,
                        playerColors: $playerColors,
                        nameManager: nameManager,
                        onPlayerCountChange: adjustPlayerNames,
                        onColorSelect: selectColor
                    )
                }
                
                // Start Game Button
                Section {
                    Button {
                        startGame()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Start Game")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(selectedVersion == nil)
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: $currentSession) { session in
                ScoringView(session: session, onGameComplete: {
                    // When game is completed, dismiss this view
                    shouldDismissToRoot = true
                })
            }
            .onChange(of: shouldDismissToRoot) { _, shouldDismiss in
                if shouldDismiss {
                    // Dismiss the GameSetupView sheet to return to main menu
                    dismiss()
                }
            }
            .onAppear {
                setupInitialState()
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupInitialState() {
        if selectedVersion == nil {
            selectedVersion = gameVersions.first
        }
        if playerColors.isEmpty, let version = selectedVersion {
            initializeColors(for: version)
        }
    }
    
    private func adjustPlayerNames(to count: Int) {
        // Adjust names array
        while playerNames.count < count {
            playerNames.append("Player \(playerNames.count + 1)")
        }
        while playerNames.count > count {
            playerNames.removeLast()
        }
        
        // Adjust colors array
        guard let version = selectedVersion else { return }
        let availableColors = version.availablePlayerColors
        
        while playerColors.count < count {
            let usedColors = Set(playerColors)
            let unusedColors = availableColors.filter { !usedColors.contains($0) }
            let newColor = unusedColors.randomElement() ?? availableColors.randomElement() ?? .red
            playerColors.append(newColor)
        }
        while playerColors.count > count {
            playerColors.removeLast()
        }
    }
    
    private func initializeColors(for version: GameVersion) {
        let availableColors = version.availablePlayerColors
        playerColors = (0..<playerCount).map { index in
            availableColors[index % availableColors.count]
        }
    }
    
    private func selectColor(_ color: PlayerColor, forPlayerAt index: Int) {
        guard let version = selectedVersion else { return }
        let availableColors = version.availablePlayerColors
        
        // If another player has this color, swap them
        if let existingIndex = playerColors.firstIndex(of: color), existingIndex != index {
            let usedColors = Set(playerColors.enumerated().compactMap { idx, playerColor in
                idx != existingIndex ? playerColor : nil
            })
            let unusedColors = availableColors.filter { !usedColors.contains($0) }
            
            if let randomColor = unusedColors.randomElement() {
                playerColors[existingIndex] = randomColor
            }
        }
        
        playerColors[index] = color
    }
    
    private func startGame() {
        guard let version = selectedVersion else { return }
        
        // Create players with selected colors
        let players = playerNames.enumerated().map { index, name in
            Player(name: name, color: playerColors[index])
        }
        
        let session = GameSession(gameVersionId: version.id, players: players)
        modelContext.insert(session)
        
        // Save player names for future use
        nameManager.saveNames(playerNames)
        
        // Launch the game
        currentSession = session
    }
}

// MARK: - Game Version Section

struct GameVersionSection: View {
    @Binding var selectedVersion: GameVersion?
    let gameVersions: [GameVersion]
    
    var body: some View {
        Section("Game Version") {
            Picker("Version", selection: $selectedVersion) {
                Text("Select a version").tag(nil as GameVersion?)
                ForEach(gameVersions) { version in
                    Text(version.displayName).tag(version as GameVersion?)
                }
            }
            
            if let version = selectedVersion {
                LabeledContent("Max Route Length", value: "\(version.maxRouteLength)")
                LabeledContent("Train Cars", value: "\(version.trainCarsPerPlayer)")
                if version.features.hasStations {
                    LabeledContent("Stations", value: "\(version.stationsPerPlayer ?? 3)")
                }
            }
        }
    }
}

// MARK: - Player Configuration Section

struct PlayerConfigurationSection: View {
    let version: GameVersion
    @Binding var playerCount: Int
    @Binding var playerNames: [String]
    @Binding var playerColors: [PlayerColor]
    let nameManager: PlayerNameManager
    let onPlayerCountChange: (Int) -> Void
    let onColorSelect: (PlayerColor, Int) -> Void
    
    var body: some View {
        Section("Players") {
            // Player count stepper
            Stepper("Number of Players: \(playerCount)",
                   value: $playerCount,
                   in: version.minPlayers...version.maxPlayers)
            .onChange(of: playerCount) { oldValue, newValue in
                onPlayerCountChange(newValue)
            }
            
            // Player configuration rows
            ForEach(0..<playerCount, id: \.self) { index in
                PlayerConfigRow(
                    index: index,
                    name: $playerNames[index],
                    color: $playerColors[index],
                    availableColors: version.availablePlayerColors,
                    savedNames: nameManager.savedNames,
                    onColorSelect: { color in
                        onColorSelect(color, index)
                    }
                )
            }
        }
    }
}

// MARK: - Player Configuration Row

struct PlayerConfigRow: View {
    let index: Int
    @Binding var name: String
    @Binding var color: PlayerColor
    let availableColors: [PlayerColor]
    let savedNames: [String]
    let onColorSelect: (PlayerColor) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Color picker
            Menu {
                ForEach(availableColors) { availableColor in
                    Button {
                        onColorSelect(availableColor)
                    } label: {
                        HStack {
                            Circle()
                                .fill(availableColor.color)
                                .frame(width: 20, height: 20)
                            Text(availableColor.displayName)
                            if color == availableColor {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Circle()
                    .fill(color.color)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                    )
            }
            
            // Name field with suggestions
            VStack(alignment: .leading, spacing: 0) {
                TextField("Player \(index + 1)", text: $name)
                    .textFieldStyle(.plain)
                    .font(.body)
                
                // Recent names menu
                if !savedNames.isEmpty {
                    Menu {
                        ForEach(savedNames, id: \.self) { savedName in
                            Button(savedName) {
                                name = savedName
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                            Text("Recent names")
                                .font(.caption)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }
}
