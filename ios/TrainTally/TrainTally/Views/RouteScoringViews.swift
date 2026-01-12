//
//  RouteScoringViews.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Route scoring components separated from ContentView
//

import SwiftUI

// MARK: - Route Scoring Section

struct RouteScoringSection: View {
    @Binding var player: Player
    let gameVersion: GameVersion
    
    private var routePoints: Int {
        player.calculateRoutePoints(using: gameVersion)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Routes")
                    .font(.headline)
                Spacer()
                Text("\(routePoints) pts")
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            
            // Route buttons grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(gameVersion.sortedRouteScoring, id: \.length) { route in
                    RouteButton(
                        length: route.length,
                        points: route.points,
                        count: player.routeCount(forLength: route.length),
                        onIncrement: { player.addRoute(length: route.length) },
                        onDecrement: { player.removeRoute(length: route.length) }
                    )
                }
            }
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Route Button

struct RouteButton: View {
    let length: Int
    let points: Int
    let count: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            // Route info
            Text("\(length) 🚂")
                .font(.headline)
            Text("+\(points) pts")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Counter controls
            HStack(spacing: 8) {
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(count > 0 ? .red : .gray)
                }
                .disabled(count == 0)
                
                Text("\(count)")
                    .fontWeight(.bold)
                    .frame(minWidth: 20)
                
                Button(action: onIncrement) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}
