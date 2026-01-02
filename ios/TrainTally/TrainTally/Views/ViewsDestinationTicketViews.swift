//
//  DestinationTicketViews.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/29/25.
//  Destination ticket components separated from ContentView
//

import SwiftUI

// MARK: - Destination Tickets Section

struct DestinationTicketsSection: View {
    @Binding var player: Player
    @State private var showingAddTicket = false
    @State private var newTicketPoints = ""
    @State private var newTicketCompleted = true
    
    private var ticketPoints: Int {
        player.calculateTicketPoints()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Destination Tickets")
                    .font(.headline)
                Spacer()
                Text("\(ticketPoints >= 0 ? "+" : "")\(ticketPoints) pts")
                    .fontWeight(.semibold)
                    .foregroundStyle(ticketPoints >= 0 ? .green : .red)
            }
            
            // Existing tickets list
            ForEach(player.destinationTickets) { ticket in
                DestinationTicketRow(
                    ticket: ticket,
                    onDelete: {
                        player.destinationTickets.removeAll { $0.id == ticket.id }
                    }
                )
            }
            
            // Add ticket button
            Button {
                showingAddTicket = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Ticket")
                }
            }
            .sheet(isPresented: $showingAddTicket) {
                AddTicketSheet(
                    points: $newTicketPoints,
                    isCompleted: $newTicketCompleted,
                    onAdd: addTicket
                )
            }
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func addTicket() {
        guard let points = Int(newTicketPoints), points > 0 else { return }
        let ticket = DestinationTicket(pointValue: points, isCompleted: newTicketCompleted)
        player.destinationTickets.append(ticket)
        newTicketPoints = ""
        newTicketCompleted = true
        showingAddTicket = false
    }
}

// MARK: - Destination Ticket Row

struct DestinationTicketRow: View {
    let ticket: DestinationTicket
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Completion status icon
            Image(systemName: ticket.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ticket.isCompleted ? .green : .red)
            
            // Points
            Text("\(ticket.isCompleted ? "+" : "-")\(ticket.pointValue) pts")
            
            // Description (if any)
            if !ticket.description.isEmpty {
                Text("(\(ticket.description))")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Ticket Sheet

struct AddTicketSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var points: String
    @Binding var isCompleted: Bool
    let onAdd: () -> Void
    
    private var canAdd: Bool {
        Int(points) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Point Value", text: $points)
                    .keyboardType(.numberPad)
                
                Toggle("Completed", isOn: $isCompleted)
            }
            .navigationTitle("Add Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd() }
                        .disabled(!canAdd)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}
