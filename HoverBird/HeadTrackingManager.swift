//
//  EyeTrackingManager.swift
//  BreakOut
//
//  Created by Ramin Rezaiifar on 1/24/26.
//

import ARKit
import Observation
import SwiftUI
import SpriteKit
import GameKit

// MARK: - App Entry Point

@main
struct HoverSharkApp: App {
    @State private var headTrackingManager = HeadTrackingManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(headTrackingManager)
                .ignoresSafeArea()
                .statusBar(hidden: true)
        }
    }
}

// MARK: - Content Views

struct ContentView: View {
    @Environment(HeadTrackingManager.self) var headTrackingManager
    @State private var isGameActive = false
    
    var body: some View {
        ZStack {
            // Show onboarding on first launch
            if !headTrackingManager.onboardingCompleted {
                OnboardingView()
            } else if isGameActive {
                GameView(isGameActive: $isGameActive)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                MainMenu(isGameActive: $isGameActive)
            }
            
            // Debug/Status Overlay (only show when not in onboarding)
            if headTrackingManager.onboardingCompleted {
                if headTrackingManager.isTracking {
                    VStack {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("Head Tracking Active")
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        Spacer()
                    }
                } else if let error = headTrackingManager.errorMessage {
                     VStack {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            headTrackingManager.startTracking()
        }
    }
}

struct MainMenu: View {
    @Binding var isGameActive: Bool
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all) // Placeholder background
            
            VStack(spacing: 30) {
                Text("Shark Attack: User Your Head")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: false)
                    .frame(width: 500)
                
                Button(action: {
                    withAnimation {
                        isGameActive = true
                    }
                }) {
                    Text("START GAME")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(Color.orange)
                                .shadow(radius: 5)
                        )
                }
                
                Text("Use your head to control the shark!")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Game View (SpriteKit Bridge)

struct GameView: UIViewRepresentable {
    @Binding var isGameActive: Bool
    @Environment(HeadTrackingManager.self) var headTrackingManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
        
        // Load the scene
        let scene = MyScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .aspectFill
        
        // Pass the HeadTrackingManager to the scene
        scene.headTracker = headTrackingManager
        
        // Set the score delegate to the coordinator to handle game over
        scene.scoreDelegate = context.coordinator
        
        skView.presentScene(scene)
        return skView
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        // Handle updates if necessary
    }
    
    class Coordinator: NSObject, MySceneDelegate {
        var parent: GameView
        
        init(_ parent: GameView) {
            self.parent = parent
        }
        
        func didFinishGame(withScore score: Int) {
            print("Game Finished with score: \(score)")
            // Here you could show a game over modal or transition back to menu
        }
    }
}

// MARK: - HeadTrackingManager

/// Steps for Head Calibration
@objc enum HeadCalibrationStep: Int {
    case idle
    case center
    case up
    case down
    case left
    case right
    case done
}

/// Manages ARKit face tracking to detect head and eye movement for game control
@objc
@MainActor
@Observable
class HeadTrackingManager: NSObject {
    
    /// Shared singleton instance for app-wide access
    static let shared = HeadTrackingManager()
    
    /// Normalized horizontal tracking position from -1.0 (left) to 1.0 (right)
    @objc dynamic var trackingPositionX: Float = 0.0
    
    /// Head position in meters relative to the device (x: left-right, y: up-down, z: distance)
    @objc dynamic var headPositionX: Float = 0.0
    @objc dynamic var headPositionY: Float = 0.0
    @objc dynamic var headPositionZ: Float = 0.0
    
    /// Whether face tracking is currently active
    @objc dynamic var isTracking: Bool = false
    
    /// Error message if face tracking fails
    @objc dynamic var errorMessage: String?
    
    /// Whether the environment is too dark for tracking
    @objc dynamic var isEnvironmentTooDark: Bool = false
    
    /// Whether face is currently detected (false if camera may be covered)
    @objc dynamic var isFaceDetected: Bool = true
    
    /// Warning message when face cannot be detected
    @objc dynamic var faceDetectionWarning: String?
    
    /// Current head calibration step
    @objc dynamic var headCalibrationStep: HeadCalibrationStep = .idle
    
    /// User-facing text for the current calibration step
    @objc dynamic var calibrationStatusMessage: String = ""
    
    /// Calibrated sensitivities
    @objc dynamic var headSensitivityX: Float = 2500.0
    @objc dynamic var headSensitivityY: Float = 2500.0
    
    // Calibration storage
    private var calibMinX: Float = 0
    private var calibMaxX: Float = 0
    private var calibMinY: Float = 0
    private var calibMaxY: Float = 0
    
    /// Whether the user has completed the onboarding instructions
    @objc dynamic var onboardingCompleted: Bool = false
    
    private var arSession: ARSession?
    
    /// Last time face was detected (for timeout detection)
    private var lastFaceDetectedTime: Date = Date()
    
    /// Timer to check for face detection timeout
    private var faceDetectionTimer: Timer?
    
    /// Head position filter states
    private var filteredHeadX: Float = 0.0
    private var filteredHeadY: Float = 0.0
    private var filteredHeadZ: Float = -0.95 // Default distance of 50cm
    
    /// Neutral (baseline) head pose for frontal view
    private var neutralHeadX: Float = 0.0
    private var neutralHeadY: Float = 0.0
    private var neutralHeadZ: Float = -0.95 // Default distance
    private var hasSetNeutralPose: Bool = false
    
    /// Smoothing factor for low-pass filter (0.0 to 1.0, lower = smoother but more lag)
    private let headSmoothingFactor: Float = 0.90 // Increased from 0.1 for more responsiveness
    
    // MARK: - UserDefaults Keys
    private let onboardingCompletedKey = "headTracking.onboarding.completed"
    private let headSensitivityXKey = "headTracking.headSensitivityX"
    private let headSensitivityYKey = "headTracking.headSensitivityY"
    private let headCalibrationCompletedKey = "headTracking.headCalibration.completed"
    
    /// Check if the device supports face tracking
    @objc static var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }
    
    override init() {
        super.init()
        loadOnboardingState()
        loadHeadCalibration()
        authenticateGameCenter()
    }
    
    // MARK: - Game Center Authentication
    
    /// Authenticate with Game Center
    private func authenticateGameCenter() {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                // Present the authentication view controller if needed
                // This is handled by the system when user needs to sign in
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(viewController, animated: true)
                }
            } else if localPlayer.isAuthenticated {
                print("Game Center: Authenticated as \(localPlayer.alias)")
            } else if let error = error {
                print("Game Center authentication error: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadOnboardingState() {
        onboardingCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
    }
    
    func completeOnboarding() {
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
    }
    
    /// Start the AR face tracking session
    func startTracking() {
        guard HeadTrackingManager.isSupported else {
            errorMessage = "Head tracking is not supported on this device. Requires iPhone X or later with TrueDepth camera."
            return
        }
        
        arSession = ARSession()
        arSession?.delegate = self
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isTracking = true
        errorMessage = nil
        isFaceDetected = true
        faceDetectionWarning = nil
        lastFaceDetectedTime = Date()
        startFaceDetectionTimer()
    }
    
    /// Start a timer to check for face detection timeout
    private func startFaceDetectionTimer() {
        faceDetectionTimer?.invalidate()
        faceDetectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkFaceDetectionTimeout()
            }
        }
    }
    
    /// Check if face detection has timed out
    private func checkFaceDetectionTimeout() {
        let timeout: TimeInterval = 2.0 // seconds
        if Date().timeIntervalSince(lastFaceDetectedTime) > timeout {
            isFaceDetected = false
            faceDetectionWarning = "Face not detected. Please ensure camera is not covered."
        }
    }
    
    func stopTracking() {
        faceDetectionTimer?.invalidate()
        faceDetectionTimer = nil
        arSession?.pause()
        arSession = nil
        isTracking = false
        isFaceDetected = true
        faceDetectionWarning = nil
        trackingPositionX = 0.0
        headPositionX = 0.0
        headPositionY = 0.0
        headPositionZ = 0.0
        
        // Reset neutral pose calibration
        hasSetNeutralPose = false
        neutralHeadX = 0.0
        neutralHeadY = 0.0
        neutralHeadZ = -0.95
    }
    
    /// Reset tracking (useful when restarting the game)
    func resetTracking() {
        stopTracking()
        startTracking()
    }
    
    // MARK: - Head Calibration
    
    @objc func startHeadCalibration() {
        headCalibrationStep = .center
        calibrationStatusMessage = "Look at Center & Tap"
        // Reset to defaults
        headSensitivityX = 2500.0
        headSensitivityY = 2500.0
    }

    @objc func nextHeadCalibrationStep() {
        switch headCalibrationStep {
        case .idle:
            break
        case .center:
            // Set neutral pose to current
            neutralHeadX = filteredHeadX
            neutralHeadY = filteredHeadY
            neutralHeadZ = filteredHeadZ
            hasSetNeutralPose = true
            
            headCalibrationStep = .up
            calibrationStatusMessage = "Look UP & Tap"
            
        case .up:
            // Record Max Y (Up is usually positive Y in 3D or screen? Need to check coordinate system)
            // ARKit Face: +Y is Up relative to face.
            // But we track translation.
            // Let's assume user looked "Up", regardless of sign, we want the Delta.
            calibMaxY = headPositionY // This is current offset from neutral
            
            headCalibrationStep = .down
            calibrationStatusMessage = "Look DOWN & Tap"
            
        case .down:
            calibMinY = headPositionY
            
            headCalibrationStep = .left
            calibrationStatusMessage = "Look LEFT & Tap"
            
        case .left:
            // ARKit: Right might be +X?
            calibMinX = headPositionX
            
            headCalibrationStep = .right
            calibrationStatusMessage = "Look RIGHT & Tap"
            
        case .right:
            calibMaxX = headPositionX
            
            calculateSensitivities()
            headCalibrationStep = .idle // Done
            calibrationStatusMessage = "Calibration Complete!"
            
        case .done:
            headCalibrationStep = .idle
            calibrationStatusMessage = ""
        }
    }
    
    private func calculateSensitivities() {
        // Range Y = MaxY - MinY.
        // If user moved up 5cm and down 5cm, range is 10cm (0.1m).
        // we want 0.1m to map to Full Speed (or Screen Height?)
        // Sensitivity maps Position -> Velocity/Impulse.
        // Let's say at Max Excursion, we want Speed S.
        // Velocity = Position * Sensitivity.
        // S = (Range/2) * Sensitivity
        // Sensitivity = S * 2 / Range.
        
        let rangeX = abs(calibMaxX - calibMinX)
        let rangeY = abs(calibMaxY - calibMinY)
        
        // Safety check
        let minRange: Float = 0.02 // 2cm
        
        if rangeX > minRange {
            // Target: At max excursion, we want meaningful velocity.
            // Previous heuristic was 2500 for arbitrary movement.
            // Let's assume 2500 corresponds to ~0.02m (2cm) offset? 0.02 * 2500 = 50.
            // So Target Velocity ~ 50.
            let targetVelocity: Float = 50.0
            headSensitivityX = targetVelocity / (rangeX / 2.0)
        } else {
            headSensitivityX = 2500.0
        }
        
        if rangeY > minRange {
            let targetVelocity: Float = 50.0
            headSensitivityY = targetVelocity / (rangeY / 2.0)
        } else {
            headSensitivityY = 2500.0
        }
        
        print("Calibrated Sensitivities: X=\(headSensitivityX), Y=\(headSensitivityY)")
        
        // Save head calibration
        saveHeadCalibration()
    }
    
    // MARK: - Head Calibration Persistence
    
    /// Save head calibration sensitivities to UserDefaults
    private func saveHeadCalibration() {
        UserDefaults.standard.set(headSensitivityX, forKey: headSensitivityXKey)
        UserDefaults.standard.set(headSensitivityY, forKey: headSensitivityYKey)
        UserDefaults.standard.set(true, forKey: headCalibrationCompletedKey)
        print("Head calibration saved: sensitivityX=\(headSensitivityX), sensitivityY=\(headSensitivityY)")
    }
    
    /// Load head calibration sensitivities from UserDefaults
    private func loadHeadCalibration() {
        if UserDefaults.standard.bool(forKey: headCalibrationCompletedKey) {
            headSensitivityX = UserDefaults.standard.float(forKey: headSensitivityXKey)
            headSensitivityY = UserDefaults.standard.float(forKey: headSensitivityYKey)
            
            // Ensure sensitivities are valid (not zero)
            if headSensitivityX <= 0 { headSensitivityX = 2500.0 }
            if headSensitivityY <= 0 { headSensitivityY = 2500.0 }
            
            print("Head calibration loaded: sensitivityX=\(headSensitivityX), sensitivityY=\(headSensitivityY)")
        } else {
            print("No saved head calibration found. Using defaults.")
        }
    }
}
    
@MainActor
extension HeadTrackingManager: ARSessionDelegate {
    
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            return
        }
        
        // Extract head rotation (Euler angles)
        // Note: Coordinate space might vary, but typically:
        // X = Pitch (Nodding Yes)
        // Y = Yaw (Shaking No)
        // Z = Roll (Tilting head sideways)
        let rotation = faceAnchor.transform.eulerAngles
        let isTrackingFace = faceAnchor.isTracked

        Task { @MainActor in
            if isTrackingFace {
                self.lastFaceDetectedTime = Date()
                if !self.isFaceDetected {
                    self.isFaceDetected = true
                    self.faceDetectionWarning = nil
                }
            }
            self.processHeadPose(rotation: rotation)
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.isTracking = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.isTracking = false
        }
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.resetTracking()
        }
    }
    
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            switch camera.trackingState {
            case .limited(let reason):
                if reason == .insufficientFeatures {
                    self.isEnvironmentTooDark = true
                } else {
                    self.isEnvironmentTooDark = false
                }
            default:
                self.isEnvironmentTooDark = false
            }
        }
    }
}

extension HeadTrackingManager {
    /// Apply calibration and low-pass filter to raw head pose (rotation)
    /// Uses an adaptive neutral reference that slowly drifts toward current pose,
    /// making control independent of absolute head position relative to camera.
    /// - Parameter rotation: Euler angles (x: Pitch, y: Yaw, z: Roll)
    private func processHeadPose(rotation: SIMD3<Float>) {
        
        // Calibrate neutral pose on first valid reading
        if !hasSetNeutralPose {
            neutralHeadX = rotation.y // Yaw mapped to X
            neutralHeadY = rotation.x // Pitch mapped to Y
            neutralHeadZ = rotation.z // Roll mapped to Z (unused for position mostly)
            hasSetNeutralPose = true
            
            // Initialize filtered values to neutral pose
            filteredHeadX = rotation.y
            filteredHeadY = rotation.x
            filteredHeadZ = rotation.z
        }
        
        // Apply smoothing to head rotation (fast response)
        filteredHeadX = filteredHeadX + headSmoothingFactor * (rotation.y - filteredHeadX)
        filteredHeadY = filteredHeadY + headSmoothingFactor * (rotation.x - filteredHeadY)
        filteredHeadZ = filteredHeadZ + headSmoothingFactor * (rotation.z - filteredHeadZ)
        
        // Adaptive neutral reference: slowly drift neutral toward current filtered pose
        // This makes the control relative to recent head position, not absolute camera position
        // Lower values = slower adaptation = more "absolute" feel
        // Higher values = faster adaptation = more "relative to body" feel
        let neutralAdaptRate: Float = 0.01  // Slow drift toward current pose
        neutralHeadX = neutralHeadX + neutralAdaptRate * (filteredHeadX - neutralHeadX)
        neutralHeadY = neutralHeadY + neutralAdaptRate * (filteredHeadY - neutralHeadY)
        
        // Apply offset relative to adaptive neutral pose
        // X: Yaw (Left/Right)
        // Y: Pitch (Up/Down)
        headPositionX = filteredHeadX - neutralHeadX
        // Invert Y axis for natural look-up -> go-up feel
        headPositionY = -(filteredHeadY - neutralHeadY)
        headPositionZ = 0 // Not using depth from rotation for now
        
        // Unused Eye Logic - keeping variable reset
        trackingPositionX = 0
    }
}

extension simd_float4x4 {
    /// Extract Euler angles from a 4x4 transformation matrix
    nonisolated var eulerAngles: simd_float3 {
        simd_float3(
            x: asin(-self[2][1]),
            y: atan2(self[2][0], self[2][2]),
            z: atan2(self[0][1], self[1][1])
        )
    }
    
    /// Extract translation from a 4x4 transformation matrix
    nonisolated var translation: SIMD3<Float> {
        SIMD3<Float>(self[3][0], self[3][1], self[3][2])
    }
}
