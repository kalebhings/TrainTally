//
//  ContentView.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/19/25.
//  Refactored on 12/29/25 - Views separated into organized files
//

import SwiftUI
import SwiftData

/// Main entry point for the app
/// All view components are now organized in separate files under Views/
struct ContentView: View {
    var body: some View {
        MainMenuView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: GameSession.self, inMemory: true)
}
