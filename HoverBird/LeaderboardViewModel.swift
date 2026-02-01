import Foundation
@preconcurrency import GameKit
import SwiftUI

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var players: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var localPlayerEntry: LeaderboardEntry?
    
    struct LeaderboardEntry: Identifiable, Sendable {
        let id = UUID()
        let rank: Int
        let score: Int
        let playerAlias: String
        let playerID: String
        var image: UIImage?
        
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
                
                for entry in entries {
                    let newEntry = LeaderboardEntry(
                        rank: entry.rank,
                        score: entry.score,
                        playerAlias: entry.player.alias,
                        playerID: entry.player.gamePlayerID,
                        image: nil
                    )
                    loadedPlayers.append(newEntry)
                }
                
                self.players = loadedPlayers
                
                if let local = localEntry {
                    self.localPlayerEntry = LeaderboardEntry(
                        rank: local.rank,
                        score: local.score,
                        playerAlias: local.player.alias,
                        playerID: local.player.gamePlayerID,
                        image: nil
                    )
                }
                
                self.isLoading = false
                await self.loadImages(entries: entries)
                
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
    
    private func loadImages(entries: [GKLeaderboard.Entry]) async {
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
    }
}
