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
    
    /// Local high score from device (independent of Game Center)
    var localHighScore: Int {
        GameSettingsManager.shared.localHighScore
    }
    
    /// Best score = max of Game Center score, local high score, and current score
    var bestScore: Int {
        max(localPlayerEntry?.score ?? 0, localHighScore, currentScore)
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
                
                for entry in entries {
                    let isLocal = entry.player.gamePlayerID == localPlayerID
                    if isLocal {
                        localPlayerInList = true
                    }
                    
                    let newEntry = LeaderboardEntry(
                        rank: entry.rank,
                        score: entry.score,
                        playerAlias: entry.player.alias,
                        playerID: entry.player.gamePlayerID,
                        image: nil,
                        isLocalPlayer: isLocal
                    )
                    loadedPlayers.append(newEntry)
                }
                
                // If local player has an entry but isn't in the top entries, add them at correct position
                if let local = localEntry {
                    self.localPlayerEntry = LeaderboardEntry(
                        rank: local.rank,
                        score: local.score,
                        playerAlias: local.player.alias,
                        playerID: local.player.gamePlayerID,
                        image: nil,
                        isLocalPlayer: true
                    )
                    
                    // Insert local player into list if not already there
                    if !localPlayerInList {
                        let localLeaderboardEntry = LeaderboardEntry(
                            rank: local.rank,
                            score: local.score,
                            playerAlias: local.player.alias,
                            playerID: local.player.gamePlayerID,
                            image: nil,
                            isLocalPlayer: true
                        )
                        
                        // Find the correct position based on rank
                        var insertIndex = loadedPlayers.count
                        for (index, player) in loadedPlayers.enumerated() {
                            if local.rank < player.rank {
                                insertIndex = index
                                break
                            }
                        }
                        loadedPlayers.insert(localLeaderboardEntry, at: insertIndex)
                    }
                }
                
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
        // Load images for entries in the list
        for (index, entry) in entries.enumerated() {
            do {
                let image = try await entry.player.loadPhoto(for: .normal)
                if index < self.players.count {
                    self.players[index].image = image
                }
                
                if self.localPlayerEntry?.playerID == entry.player.gamePlayerID {
                    self.localPlayerEntry?.image = image
                }
            } catch {
                // Photo loading failed, continue with next
            }
        }
        
        // Load local player's image if they're not in the top entries
        if let local = localEntry {
            let localPlayerID = local.player.gamePlayerID
            let isInList = entries.contains { $0.player.gamePlayerID == localPlayerID }
            
            if !isInList {
                do {
                    let image = try await local.player.loadPhoto(for: .normal)
                    self.localPlayerEntry?.image = image
                    
                    // Update in players list too
                    if let index = self.players.firstIndex(where: { $0.playerID == localPlayerID }) {
                        self.players[index].image = image
                    }
                } catch {
                    // Photo loading failed
                }
            }
        }
    }
}
