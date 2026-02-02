//
//  SettingsView.swift
//  HoverSharky
//
//  Settings view with Contact Us, Unlock Premium, and How to Play
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showMailComposer = false
    @State private var showMailError = false
    @State private var showPaywall = false
    @State private var showHowToPlay = false
    @State private var storeManager = StoreManager.shared
    @State private var isMusicEnabled: Bool = GameSettingsManager.shared.isMusicEnabled
    @State private var isHandTappingEnabled: Bool = GameSettingsManager.shared.isHandTappingEnabled
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient - Ocean themed
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.2, blue: 0.35), Color(red: 0.02, green: 0.08, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Decorative shapes - bubbles
                Circle()
                    .fill(Color.cyan.opacity(0.4))
                    .frame(width: 120)
                    .blur(radius: 50)
                    .offset(x: -120, y: -250)
                
                Circle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 250)
                    .blur(radius: 60)
                    .offset(x: 100, y: 200)
                
                Form {
                    // Game Settings Section
                    Section {
                        Toggle(isOn: $isMusicEnabled) {
                            HStack {
                                Image(systemName: isMusicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .foregroundColor(.cyan)
                                    .frame(width: 30)
                                Text("Music")
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(.cyan)
                        .onChange(of: isMusicEnabled) { _, newValue in
                            GameSettingsManager.shared.isMusicEnabled = newValue
                        }
                        
                        Toggle(isOn: $isHandTappingEnabled) {
                            HStack {
                                Image(systemName: isHandTappingEnabled ? "hand.tap.fill" : "person.and.arrow.left.and.arrow.right")
                                    .foregroundColor(.cyan)
                                    .frame(width: 30)
                                Text("Hand Tapping Mode")
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(.cyan)
                        .onChange(of: isHandTappingEnabled) { _, newValue in
                            GameSettingsManager.shared.isHandTappingEnabled = newValue
                        }
                    } header: {
                        Text("Game Settings")
                            .foregroundColor(.cyan)
                    } footer: {
                        Text("When Hand Tapping Mode is off, head tracking controls the shark.")
                            .foregroundColor(.cyan.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                    
                    // Contact Us Section
                    Section {
                        Button(action: { contactUs() }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.cyan)
                                    .frame(width: 30)
                                Text("Contact Us")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.cyan.opacity(0.5))
                            }
                        }
                    } header: {
                        Text("Support")
                            .foregroundColor(.cyan)
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                    
                    // Unlock Premium Section
                    Section {
                        Button(action: { showPaywall = true }) {
                            HStack {
                                Image(systemName: storeManager.isUnlimitedUnlocked ? "checkmark.seal.fill" : "star.fill")
                                    .foregroundColor(.yellow)
                                    .frame(width: 30)
                                Text(storeManager.isUnlimitedUnlocked ? "Premium Unlocked" : "Unlock Premium")
                                    .foregroundColor(.white)
                                Spacer()
                                if !storeManager.isUnlimitedUnlocked {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.cyan.opacity(0.5))
                                }
                            }
                        }
                        .disabled(storeManager.isUnlimitedUnlocked)
                    } header: {
                        Text("Premium")
                            .foregroundColor(.cyan)
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                    
                    // How to Play Section
                    Section {
                        Button(action: { showHowToPlay = true }) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 30)
                                Text("How to Play")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.cyan.opacity(0.5))
                            }
                        }
                    } header: {
                        Text("Help")
                            .foregroundColor(.cyan)
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.2, blue: 0.35), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipient: "apps@maadotaa.com",
                subject: "\(appName) v\(appVersion)"
            )
        }
        .sheet(isPresented: $showPaywall) {
            StylishPaywallView()
        }
        .sheet(isPresented: $showHowToPlay) {
            HowToPlayView()
        }
        .alert("Cannot Send Email", isPresented: $showMailError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please configure an email account in your device settings, or email us directly at apps@maadotaa.com")
        }
    }
    
    // MARK: - Helpers
    
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "HoverSharky"
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func contactUs() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailError = true
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.setToRecipients([recipient])
        mailComposer.setSubject(subject)
        mailComposer.mailComposeDelegate = context.coordinator
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - How to Play View

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.2, blue: 0.35), Color(red: 0.02, green: 0.08, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(spacing: 5) {
                            Image("Shark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                            
                            Text("How to Play")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                        
                        // Control Section
                        InstructionCard(
                            icon: "person.and.arrow.left.and.arrow.right",
                            title: "Head Control",
                            description: "Move your head left/right and up/down to control the shark. The camera tracks your face to detect movement."
                        )
                        
                        InstructionCard(
                            icon: "hand.tap",
                            title: "Tap to Jump",
                            description: "If head tracking is disabled, tap anywhere on the screen to make the shark swim upward."
                        )
                        
                        // Objective Section
                        InstructionCard(
                            icon: "fish.fill",
                            title: "Eat Fish",
                            description: "Swim into fish to eat them and score points. The more fish you eat, the higher your score!"
                        )
                        
                        InstructionCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Avoid Dangers",
                            description: "Stay away from mines, barrels, torpedoes, and submarines. Colliding with them will cost you a life."
                        )
                        
                        // Tips Section
                        InstructionCard(
                            icon: "lightbulb.fill",
                            title: "Tips",
                            description: "• Calibrate head tracking for best results\n• Small fish are easier to catch\n• Medium fish are worth more points\n• Watch out for submarines - they fire torpedoes!"
                        )
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Instruction Card

private struct InstructionCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.cyan)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.cyan.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

#Preview {
    SettingsView()
}
