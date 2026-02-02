//
//  GameSettingsManager.swift
//  HoverSharky
//
//  Singleton manager for game settings that can be accessed from both Swift and Objective-C
//

import Foundation

@MainActor
@objc class GameSettingsManager: NSObject {
    
    @objc static let shared = GameSettingsManager()
    
    private let musicEnabledKey = "isMusicEnabled"
    private let handTappingEnabledKey = "isHandTappingEnabled"
    
    private override init() {
        super.init()
        // Set defaults if not already set
        if UserDefaults.standard.object(forKey: musicEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: musicEnabledKey)
        }
        if UserDefaults.standard.object(forKey: handTappingEnabledKey) == nil {
            // Default to head tracking enabled (handTapping disabled means head tracking is on)
            UserDefaults.standard.set(false, forKey: handTappingEnabledKey)
        }
    }
    
    /// Whether music is enabled. Default is true.
    @objc var isMusicEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: musicEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: musicEnabledKey) }
    }
    
    /// Whether hand tapping mode is enabled (instead of head tracking). Default is false (head tracking enabled).
    @objc var isHandTappingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: handTappingEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: handTappingEnabledKey) }
    }
    
    /// Convenience property: true when head tracking should be used
    @objc var isHeadTrackingEnabled: Bool {
        return !isHandTappingEnabled
    }
    
    // MARK: - High Score Tracking
    
    private let localHighScoreKey = "localHighScore"
    
    /// The local high score - persisted independently of Game Center
    @objc var localHighScore: Int {
        get { UserDefaults.standard.integer(forKey: localHighScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: localHighScoreKey) }
    }
    
    /// Updates the local high score if the new score is higher. Returns true if updated.
    @objc func updateHighScoreIfNeeded(_ score: Int) -> Bool {
        if score > localHighScore {
            localHighScore = score
            return true
        }
        return false
    }
}
