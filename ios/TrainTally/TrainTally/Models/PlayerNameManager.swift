//
//  PlayerNameManager.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 12/19/25.
//

import Foundation
import Combine
import NaturalLanguage

/// Manages saved player names across game sessions
class PlayerNameManager: ObservableObject {
    static let shared = PlayerNameManager()
    
    private let savedNamesKey = "SavedPlayerNames"
    private let maxSavedNames = 20
    
    @Published private(set) var savedNames: [String] = []
    
    private init() {
        loadSavedNames()
    }
    
    /// Load saved names from UserDefaults
    private func loadSavedNames() {
        if let names = UserDefaults.standard.stringArray(forKey: savedNamesKey) {
            savedNames = names
        }
    }
    
    /// Save a player name (if it's not a default name like "Player 1")
    func saveName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Don't save empty names or default names like "Player 1", "Player 2", etc.
        guard !trimmedName.isEmpty,
              !isDefaultName(trimmedName),
              isValidName(trimmedName) else {
            return
        }
        
        // Don't add if already exists
        if savedNames.contains(trimmedName) {
            return
        }
        
        // Add to beginning of list
        savedNames.insert(trimmedName, at: 0)
        
        // Keep only the most recent names
        if savedNames.count > maxSavedNames {
            savedNames = Array(savedNames.prefix(maxSavedNames))
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(savedNames, forKey: savedNamesKey)
    }
    
    /// Check if a name is a default name like "Player 1", "Player 2", etc.
    private func isDefaultName(_ name: String) -> Bool {
        let pattern = "^Player \\d+$"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(name.startIndex..., in: name)
        return regex?.firstMatch(in: name, range: range) != nil
    }
    
    /// Validate that a name only contains letters and spaces
    private func isValidName(_ name: String) -> Bool {
        // Check if name contains only letters and spaces
        let letterSet = CharacterSet.letters.union(.whitespaces)
        let nameCharacterSet = CharacterSet(charactersIn: name)
        
        guard letterSet.isSuperset(of: nameCharacterSet) else {
            return false
        }
        
        // Check for inappropriate content
        return !containsInappropriateContent(name)
    }
    
    /// Check for inappropriate content using Apple's Natural Language framework
    /// This performs sentiment analysis to detect potentially offensive content
    /// without requiring hardcoded word lists
    private func containsInappropriateContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check for excessive character repetition (e.g., "aaaaaaa")
        let repeatingPattern = #"(.)\1{4,}"#  // 5 or more of the same character
        if let regex = try? NSRegularExpression(pattern: repeatingPattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return true
        }
        
        // 2. Use Natural Language sentiment analysis
        // Very negative sentiment may indicate offensive language
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed
        
        if let sentiment = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore).0,
           let score = Double(sentiment.rawValue) {
            // Sentiment ranges from -1.0 (very negative) to 1.0 (very positive)
            // Flag names with extremely negative sentiment (< -0.7)
            if score < -0.7 {
                return true
            }
        }
        
        // 3. Check for common patterns of abuse
        // All caps with short names often indicates shouting/aggression
        if trimmed.count <= 8 && trimmed == trimmed.uppercased() && trimmed != trimmed.lowercased() {
            return true
        }
        
        // 4. Check for excessive punctuation (!!!, ???, etc.)
        let punctuationPattern = #"[!?]{3,}"#
        if let regex = try? NSRegularExpression(pattern: punctuationPattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return true
        }
        
        return false
    }
    
    /// Save multiple names at once (e.g., when completing a game)
    func saveNames(_ names: [String]) {
        for name in names {
            saveName(name)
        }
    }
    
    /// Get all saved names plus default suggestions
    func getAllSuggestions(defaultName: String) -> [String] {
        var suggestions = [defaultName]
        suggestions.append(contentsOf: savedNames)
        return suggestions
    }
    
    /// Public validation function to check if a name is acceptable
    /// Returns nil if valid, or an error message if invalid
    func validateName(_ name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Empty name
        if trimmedName.isEmpty {
            return "Name cannot be empty"
        }
        
        // Check for numbers or symbols
        let letterSet = CharacterSet.letters.union(.whitespaces)
        let nameCharacterSet = CharacterSet(charactersIn: trimmedName)
        
        if !letterSet.isSuperset(of: nameCharacterSet) {
            return "Name can only contain letters and spaces"
        }
        
        // Check for inappropriate content
        if containsInappropriateContent(trimmedName) {
            return "Please use appropriate language"
        }
        
        return nil // Valid name
    }
}
