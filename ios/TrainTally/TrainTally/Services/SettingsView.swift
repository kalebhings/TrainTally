//
//  SettingsView.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/12/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var authManager = AuthenticationManager.shared
    @State private var syncManager = CloudSyncManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAuthSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Cloud Sync Section
                Section {
                    Toggle("Enable Cloud Sync", isOn: $syncManager.isCloudSyncEnabled)
                        .disabled(!authManager.isAuthenticated)
                        .onChange(of: syncManager.isCloudSyncEnabled) { oldValue, newValue in
                            if newValue && !authManager.isAuthenticated {
                                // Prevent enabling without auth
                                syncManager.isCloudSyncEnabled = false
                                showingAuthSheet = true
                            }
                        }
                    
                    if syncManager.isCloudSyncEnabled {
                        if let lastSync = syncManager.lastSyncDate {
                            HStack {
                                Text("Last Sync")
                                Spacer()
                                Text(lastSync, style: .relative)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Button("Sync Now") {
                            Task {
                                await syncNow()
                            }
                        }
                        .disabled(syncManager.syncStatus == .syncing)
                        
                        if syncManager.syncStatus == .syncing {
                            HStack {
                                ProgressView()
                                Text("Syncing...")
                            }
                        }
                        
                        if let error = syncManager.syncError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Cloud Sync")
                } footer: {
                    Text("Enable cloud sync to share your scores and compete on global leaderboards. All data is also saved locally.")
                }
                
                // Account Section
                Section("Account") {
                    if authManager.isAuthenticated {
                        if let email = authManager.currentUserEmail {
                            HStack {
                                Text("Signed in as")
                                Spacer()
                                Text(email)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await signOut()
                            }
                        }
                    } else {
                        Button("Sign In / Sign Up") {
                            showingAuthSheet = true
                        }
                    }
                }
                
                // AWS Configuration Status
                if !AWSConfiguration.isConfigured {
                    Section {
                        Label {
                            Text("AWS backend not configured")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    } footer: {
                        Text("Update AWSConfiguration.swift with your CloudFormation outputs to enable cloud sync.")
                    }
                }
                
                // Local Data Section
                Section {
                    NavigationLink("View Local Games") {
                        LocalDataView()
                    }
                } header: {
                    Text("Local Data")
                } footer: {
                    Text("Your game data is always saved locally, even without cloud sync.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAuthSheet) {
                AuthenticationView()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func syncNow() async {
        do {
            try await syncManager.syncAllUnsubmittedGames(context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func signOut() async {
        await authManager.signOut()
        syncManager.disableCloudSync()
    }
}

// MARK: - Local Data View

struct LocalDataView: View {
    @Query(
        filter: #Predicate<GameSession> { $0.isCompleted },
        sort: \GameSession.completedAt,
        order: .reverse
    ) private var completedGames: [GameSession]
    
    var body: some View {
        List {
            ForEach(completedGames) { game in
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.gameVersion?.displayName ?? "Unknown Game")
                        .font(.headline)
                    
                    if let winner = game.getWinner() {
                        Text("\(winner.player.name) won with \(winner.totalScore) points")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let date = game.completedAt {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        if game.isSubmittedToCloud {
                            Label("Synced", systemImage: "checkmark.icloud")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Local Only", systemImage: "iphone")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Local Games")
        .overlay {
            if completedGames.isEmpty {
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "tray",
                    description: Text("Completed games will appear here")
                )
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: GameSession.self, inMemory: true)
}
