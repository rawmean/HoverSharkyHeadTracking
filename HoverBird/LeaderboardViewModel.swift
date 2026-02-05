import Foundation
@preconcurrency import GameKit
import SwiftUI

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var players: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var localPlayerEntry: LeaderboardEntry?
    @Published var currentScore: Int = 0
    
    /// Best score = max of Game Center score and current score
    var bestScore: Int {
        max(localPlayerEntry?.score ?? 0, currentScore)
    }
    
    struct LeaderboardEntry: Identifiable, Sendable {
        let id = UUID()
        let rank: Int
        let score: Int
        let playerAlias: String
        let playerID: String
        var image: UIImage?
        var isLocalPlayer: Bool = false
        
        var displayName: String {
            playerAlias
        }
    }
    
    private let leaderboardID = "HoverSharkyLeaderBoardID"
    
    /// Whether user needs to sign in to Game Center
    @Published var needsAuthentication = false
    
    func loadScores() {
        isLoading = true
        errorMessage = nil
        needsAuthentication = false
        
        // Check if authenticated with Game Center
        let localPlayer = GKLocalPlayer.local
        guard localPlayer.isAuthenticated else {
            self.isLoading = false
            self.needsAuthentication = true
            self.errorMessage = "Please sign in to Game Center to view the leaderboard."
            return
        }
        
        Task {
            do {
                let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
                guard let leaderboard = leaderboards.first else {
                    self.isLoading = false
                    self.errorMessage = "Leaderboard not found"
                    return
                }
                
                let (localEntry, entries, _) = try await leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 50))
                
                var loadedPlayers: [LeaderboardEntry] = []
                let localPlayerID = localPlayer.gamePlayerID
                var localPlayerInList = false
                
                // First pass: collect all entries and calculate local player's best score
                var localPlayerBestScore = 0
                var localPlayerGameCenterRank = 0
                
                for entry in entries {
                    let isLocal = entry.player.gamePlayerID == localPlayerID
                    if isLocal {
                        localPlayerInList = true
                        localPlayerBestScore = max(entry.score, self.currentScore)
                        localPlayerGameCenterRank = entry.rank
                    }
                }
                
                // If local player not in entries but has a localEntry, get their best score from there
                if !localPlayerInList, let local = localEntry {
                    localPlayerBestScore = max(local.score, self.currentScore)
                    localPlayerGameCenterRank = local.rank
                }
                
                // Calculate where the local player's best score would rank
                // Count how many entries have a score >= local player's best score
                var calculatedRank = 1
                for entry in entries {
                    if entry.player.gamePlayerID != localPlayerID && entry.score >= localPlayerBestScore {
                        calculatedRank += 1
                    }
                }
                
                // Second pass: build the player list
                for entry in entries {
                    let isLocal = entry.player.gamePlayerID == localPlayerID
                    
                    // For local player, use best score, actual alias, and calculated rank
                    let displayScore: Int
                    let displayName: String
                    let displayRank: Int
                    if isLocal {
                        displayScore = localPlayerBestScore
                        displayName = localPlayer.alias
                        displayRank = calculatedRank
                    } else {
                        displayScore = entry.score
                        displayName = entry.player.alias
                        displayRank = entry.rank
                    }
                    
                    let newEntry = LeaderboardEntry(
                        rank: displayRank,
                        score: displayScore,
                        playerAlias: displayName,
                        playerID: entry.player.gamePlayerID,
                        image: nil,
                        isLocalPlayer: isLocal
                    )
                    loadedPlayers.append(newEntry)
                    
                    // If this is the local player, also set the localPlayerEntry
                    if isLocal {
                        self.localPlayerEntry = newEntry
                    }
                }
                
                // If local player has an entry but isn't in the top entries, add them at correct position
                if let local = localEntry {
                    // Only set localPlayerEntry if not already set from the entries loop
                    if self.localPlayerEntry == nil {
                        self.localPlayerEntry = LeaderboardEntry(
                            rank: calculatedRank,
                            score: localPlayerBestScore,
                            playerAlias: localPlayer.alias,
                            playerID: local.player.gamePlayerID,
                            image: nil,
                            isLocalPlayer: true
                        )
                    }
                    
                    // Insert local player into list if not already there
                    if !localPlayerInList {
                        let localLeaderboardEntry = LeaderboardEntry(
                            rank: calculatedRank,
                            score: localPlayerBestScore,
                            playerAlias: localPlayer.alias,
                            playerID: local.player.gamePlayerID,
                            image: nil,
                            isLocalPlayer: true
                        )
                        
                        // Find the correct position based on score (descending order)
                        var insertIndex = loadedPlayers.count
                        for (index, player) in loadedPlayers.enumerated() {
                            if localPlayerBestScore > player.score {
                                insertIndex = index
                                break
                            }
                        }
                        loadedPlayers.insert(localLeaderboardEntry, at: insertIndex)
                    }
                }
                
                // Sort by score descending to ensure correct order
                loadedPlayers.sort { $0.score > $1.score }
                
                self.players = loadedPlayers
                self.isLoading = false
                await self.loadImages(entries: entries, localEntry: localEntry)
                
            } catch {
                self.isLoading = false
                // Provide user-friendly error message
                if error.localizedDescription.contains("authenticated") {
                    self.needsAuthentication = true
                    self.errorMessage = "Please sign in to Game Center to view the leaderboard."
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadImages(entries: [GKLeaderboard.Entry], localEntry: GKLeaderboard.Entry?) async {
        // Load images for entries in the list - match by playerID since list is sorted
        for entry in entries {
            do {
                let image = try await entry.player.loadPhoto(for: .normal)
                let playerID = entry.player.gamePlayerID
                
                // Find this player in our sorted list and update their image
                if let index = self.players.firstIndex(where: { $0.playerID == playerID }) {
                    self.players[index].image = image
                }
                
                // Also update localPlayerEntry if this is the local player
                if self.localPlayerEntry?.playerID == playerID {
                    self.localPlayerEntry?.image = image
                }
            } catch {
                // Photo loading failed, continue with next
            }
        }
        
        // Load local player's image directly from GKLocalPlayer
        let localPlayer = GKLocalPlayer.local
        if localPlayer.isAuthenticated {
            do {
                let image = try await localPlayer.loadPhoto(for: .normal)
                
                // Update localPlayerEntry
                self.localPlayerEntry?.image = image
                
                // Find local player in list by isLocalPlayer flag (more reliable than playerID)
                if let index = self.players.firstIndex(where: { $0.isLocalPlayer }) {
                    self.players[index].image = image
                }
            } catch {
                // Photo loading failed - try printing error for debugging
                print("Failed to load local player photo: \(error)")
            }
        }
    }
}
