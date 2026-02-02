//
//  GameRoundTracker.swift
//  HoverSharky
//
//  Tracks free rounds played for paywall enforcement
//

import Foundation

@MainActor
@objc class GameRoundTracker: NSObject {
    @objc static let shared = GameRoundTracker()
    
    private let roundsPlayedKey = "hoversharky_rounds_played"
    private let maxFreeRounds = 3
    
    private override init() {
        super.init()
    }
    
    // MARK: - Round Count
    
    /// Number of rounds played
    @objc var roundsPlayed: Int {
        return UserDefaults.standard.integer(forKey: roundsPlayedKey)
    }
    
    /// Remaining free rounds
    @objc var remainingFreeRounds: Int {
        return max(0, maxFreeRounds - roundsPlayed)
    }
    
    // MARK: - Check & Update
    
    /// Returns true if user can play a free round (< 3 played) OR has purchased
    @objc func canPlayFreeRound() -> Bool {
        // If user has purchased, always allow
        if StoreManager.shared.isUnlimitedUnlocked {
            return true
        }
        // Otherwise check round count
        return roundsPlayed < maxFreeRounds
    }
    
    /// Increment rounds played count (call when game ends)
    @objc func incrementRoundCount() {
        // Only increment if not yet purchased
        if !StoreManager.shared.isUnlimitedUnlocked {
            let current = roundsPlayed
            UserDefaults.standard.set(current + 1, forKey: roundsPlayedKey)
            print("GameRoundTracker: Rounds played = \(current + 1)")
        }
    }
    
    /// Reset round count (for testing)
    @objc func resetRoundCount() {
        UserDefaults.standard.set(0, forKey: roundsPlayedKey)
        print("GameRoundTracker: Round count reset")
    }
    
    /// Check if user needs to see paywall
    @objc var shouldShowPaywall: Bool {
        return !canPlayFreeRound()
    }
}
