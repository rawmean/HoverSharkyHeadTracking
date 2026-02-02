//
//  StylishPaywallView.swift
//  HoverSharky
//
//  Stylish paywall view for in-app purchase
//

import SwiftUI
import StoreKit

struct StylishPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @State private var storeManager = StoreManager.shared
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    
    var body: some View {
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
            
            Circle()
                .fill(Color.teal.opacity(0.3))
                .frame(width: 80)
                .blur(radius: 30)
                .offset(x: -50, y: 100)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // Benefits Section
                    benefitsSection
                    
                    // Purchase Section
                    purchaseSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Shark Icon
//            ZStack {
////                Circle()
////                    .fill(
////                        LinearGradient(
////                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
////                            startPoint: .topLeading,
////                            endPoint: .bottomTrailing
////                        )
////                    )
////                    .frame(width: 140, height: 140)
//                
//                Image("Shark1-01")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 100, height: 100)
//            }
//            .padding(.bottom, 10)
            
            Text("🦈 Go Unlimited")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text("Swim forever with full access!")
                .font(.subheadline)
                .foregroundColor(.cyan.opacity(0.8))
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            BenefitRow(
                icon: "infinity",
                title: "Unlimited Gameplay",
                description: "No more session limits. Play for hours without interruption."
            )
            BenefitRow(
                icon: "heart.fill",
                title: "Endless Lives",
                description: "Keep swimming and chasing your high score."
            )
            BenefitRow(
                icon: "bolt.fill",
                title: "Support Development",
                description: "Help an indie developer bring more updates and features."
            )
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            if let error = purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button(action: performPurchase) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(priceString)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color.cyan, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: .cyan.opacity(0.4), radius: 10)
            }
            .disabled(isPurchasing)
            
            Button(action: {
                Task {
                    await storeManager.updatePurchasedProducts()
                    if storeManager.isUnlimitedUnlocked {
                        dismiss()
                    }
                }
            }) {
                Text("Restore Purchase")
                    .font(.footnote)
                    .foregroundColor(.cyan)
            }
            
            Text("One-time purchase. No subscription.")
                .font(.caption2)
                .foregroundColor(.cyan.opacity(0.7))
        }
    }
    
    private var priceString: String {
        if let product = storeManager.products.first {
            return "Unlock for \(product.displayPrice)"
        }
        return "Unlock Everything"
    }
    
    private func performPurchase() {
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                try await storeManager.purchase()
                if storeManager.isUnlimitedUnlocked {
                    dismiss()
                }
            } catch {
                purchaseError = "Purchase failed. Please try again."
            }
            isPurchasing = false
        }
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.cyan)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.cyan.opacity(0.8))
            }
        }
    }
}

#Preview {
    StylishPaywallView()
}
