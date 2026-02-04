//
//  OnboardingView.swift
//  HoverSharky
//
//  Onboarding flow to explain head tracking controls and calibration
//

import SwiftUI
import AVKit

struct OnboardingView: View {
    @Environment(HeadTrackingManager.self) var headTrackingManager
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Ocean gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.3, blue: 0.5),
                    Color(red: 0.0, green: 0.5, blue: 0.7),
                    Color(red: 0.1, green: 0.6, blue: 0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    
                    HowToPlayPage()
                        .tag(1)
                    
                    CalibrationPage()
                        .tag(2)
                    
                    GetStartedPage(onStart: completeOnboarding)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            }
            
            // Page indicator at bottom
            VStack {
                Spacer()
                // Extra padding to push content above page indicator
                Color.clear.frame(height: 20)
            }
        }
    }
    
    private func completeOnboarding() {
        headTrackingManager.completeOnboarding()
        dismiss()
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        HStack(spacing: 40) {
            // Shark emoji on left
            Text("🦈")
                .font(.system(size: 80))
            
            // Text on right
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Shark Attack: User Your Head")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Control your shark using just your head movements!")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - How to Play Page

struct HowToPlayPage: View {
    var body: some View {
        HStack(spacing: 30) {
            // Left side: video demonstration
            LoopingVideoPlayer(videoName: "onboard_head", videoExtension: "mov")
                .frame(width: 200, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            // Right side: explanation
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Play")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Rotate your head in the direction you want the shark to swim!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 16) {
                    DirectionLabel(arrow: "←", text: "Left")
                    DirectionLabel(arrow: "→", text: "Right")
                    DirectionLabel(arrow: "↑", text: "Up")
                    DirectionLabel(arrow: "↓", text: "Down")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 280)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Looping Video Player

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoExtension: String
    
    func makeUIView(context: Context) -> PlayerUIView {
        return PlayerUIView(videoName: videoName, videoExtension: videoExtension)
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Nothing to update
    }
}

class PlayerUIView: UIView {
    private var player: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var looper: AVPlayerLooper?
    
    init(videoName: String, videoExtension: String) {
        super.init(frame: .zero)
        
        backgroundColor = .clear
        
        // Try to find the video file
        guard let path = Bundle.main.path(forResource: videoName, ofType: videoExtension) else {
            print("Video file not found: \(videoName).\(videoExtension)")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        self.player = player
        
        // Create looper for seamless looping
        self.looper = AVPlayerLooper(player: player, templateItem: playerItem)
        
        // Create and configure player layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        self.playerLayer = playerLayer
        layer.addSublayer(playerLayer)
        
        // Start playback
        player.play()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update player layer frame when view layout changes
        playerLayer?.frame = bounds
    }
}

struct DirectionLabel: View {
    let arrow: String
    let text: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(arrow)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.yellow)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}


// MARK: - Calibration Page

struct CalibrationPage: View {
    var body: some View {
        HStack(spacing: 40) {
            // Left side: icon and title
            VStack(spacing: 12) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                
                Text("Calibration")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Makes controls natural!")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Right side: steps
            VStack(alignment: .leading, spacing: 10) {
                CalibrationStep(number: 1, text: "Tap Calibrate before playing")
                CalibrationStep(number: 2, text: "Look in the direction shown")
                CalibrationStep(number: 3, text: "Tap to confirm each position")
                CalibrationStep(number: 4, text: "Done! Game learns your range")
            }
        }
        .padding(.horizontal, 40)
    }
}

struct CalibrationStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white))
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Get Started Page

struct GetStartedPage: View {
    let onStart: () -> Void
    
    var body: some View {
        HStack(spacing: 40) {
            // Left side: content
            VStack(spacing: 16) {
                Text("🎮")
                    .font(.system(size: 60))
                
                Text("Ready to Swim?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(spacing: 6) {
                    Text("Eat fish to score points")
                    Text("Avoid obstacles and torpedoes")
                    Text("See how far you can go!")
                }
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
            }
            
            // Right side: button
            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text("Let's Go!")
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingView()
        .environment(HeadTrackingManager())
}
