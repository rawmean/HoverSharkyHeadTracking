import SwiftUI
import GameKit

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @Environment(\.dismiss) var dismiss
    var currentScore: Int = 0
    
    var body: some View {
        ZStack {
            // Background - fully opaque
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Leaderboard")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: viewModel.needsAuthentication ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                        Text(viewModel.needsAuthentication ? "Game Center Sign In Required" : "Could not load leaderboard")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if viewModel.needsAuthentication {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        }
                        
                        Button("Retry") {
                            viewModel.loadScores()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    }
                    Spacer()
                } else {
                    HStack(spacing: 20) {
                        // Left Panel: Your Stats (Fixed)
                        VStack {
                            YourStatsCard(
                                rank: viewModel.localPlayerEntry?.rank ?? 0,
                                bestScore: viewModel.bestScore,
                                currentScore: currentScore
                            )
                            Spacer()
                        }
                        .frame(maxWidth: 300)
                        .padding(.vertical)
                        
                        // Right Panel: Leaderboard List (Scrollable)
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.players) { entry in
                                    LeaderboardRow(entry: entry)
                                }
                            }
                            .padding(.vertical)
                            .padding(.trailing) // Extra padding for scroll bar space
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            viewModel.currentScore = currentScore
            viewModel.loadScores()
        }
    }
}

// MARK: - Your Stats Card

struct YourStatsCard: View {
    let rank: Int
    let bestScore: Int
    let currentScore: Int
    
    // Display rank, or "—" if not ranked yet
    private var rankDisplay: String {
        rank > 0 ? "#\(rank)" : "—"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Stats")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack(spacing: 24) {
                StatItem(title: "Rank", value: rankDisplay, color: rankColor(rank))
                StatItem(title: "Best", value: "\(bestScore)", color: .yellow)
                StatItem(title: "Current", value: "\(currentScore)", color: .cyan)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(minWidth: 70)
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardViewModel.LeaderboardEntry
    var isLocalPlayer: Bool = false
    
    // Determine if this row should be highlighted as local player
    private var shouldHighlight: Bool {
        isLocalPlayer || entry.isLocalPlayer
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(entry.rank)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(rankColor(entry.rank))
                .frame(width: 40)
            
            // Icon
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(entry.displayName.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            
            // Name
            Text(entry.displayName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Score
            Text("\(entry.score)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(shouldHighlight ? Color.blue.opacity(0.3) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(shouldHighlight ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white.opacity(0.7)
        }
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardView()
    }
}

@objc class LeaderboardFactory: NSObject {
    @objc static func createLeaderboardViewController() -> UIViewController {
        return createLeaderboardViewController(currentScore: 0)
    }
    
    @objc static func createLeaderboardViewController(currentScore: Int) -> UIViewController {
        let view = LeaderboardView(currentScore: currentScore)
        let controller = UIHostingController(rootView: view)
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = .clear
        return controller
    }
}

