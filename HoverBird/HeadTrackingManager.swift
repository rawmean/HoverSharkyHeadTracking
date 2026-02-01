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
            if isGameActive {
                GameView(isGameActive: $isGameActive)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                MainMenu(isGameActive: $isGameActive)
            }
            
            // Debug/Status Overlay
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
                Text("Hover Sharky")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                
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

/// Calibration state for head tracking
enum CalibrationState {
    case notStarted
    case lookingLeft
    case lookingRight
    case completed
}

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
    
    /// Current calibration state
    var calibrationState: CalibrationState = .notStarted
    
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
    
    /// Raw eye position before filtering and calibration
    private var rawEyeY: Float = 0.0
    
    /// Calibration values
    private var leftCalibrationValue: Float = -0.15
    private var rightCalibrationValue: Float = 0.15
    
    /// Low-pass filter state
    private var filteredEyePosition: Float = 0.0
    
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
    private let smoothingFactor: Float = 0.15
    private let headSmoothingFactor: Float = 0.90 // Increased from 0.1 for more responsiveness
    
    // MARK: - UserDefaults Keys
    private let calibrationLeftKey = "headTracking.calibration.left"
    private let calibrationRightKey = "headTracking.calibration.right"
    private let calibrationCompletedKey = "headTracking.calibration.completed"
    private let onboardingCompletedKey = "headTracking.onboarding.completed"
    
    /// Check if the device supports face tracking
    @objc static var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }
    
    override init() {
        super.init()
        loadOnboardingState()
        loadCalibration()
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
    }
    
    /// Stop the AR face tracking session
    func stopTracking() {
        arSession?.pause()
        arSession = nil
        isTracking = false
        trackingPositionX = 0.0
        filteredEyePosition = 0.0
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
    
    // MARK: - Calibration
    
    /// Start the calibration process
    func startCalibration() {
        calibrationState = .lookingLeft
        filteredEyePosition = 0.0
    }
    
    /// Record the current eye position as the left calibration point
    func recordLeftPosition() {
        leftCalibrationValue = rawEyeY
        calibrationState = .lookingRight
    }
    
    /// Record the current eye position as the right calibration point
    func recordRightPosition() {
        rightCalibrationValue = rawEyeY
        
        // Ensure left and right are different enough
        if abs(rightCalibrationValue - leftCalibrationValue) < 0.05 {
            // Not enough difference, use defaults
            print("Calibration points too close, using default values.")
            leftCalibrationValue = -0.15
            rightCalibrationValue = 0.15
        }
        
        calibrationState = .completed
        saveCalibration()
    }
    
    /// Reset calibration to start over
    func resetCalibration() {
        calibrationState = .notStarted
        leftCalibrationValue = -0.15
        rightCalibrationValue = 0.15
        filteredEyePosition = 0.0
        clearCalibration()
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
        
        print("Calibrated Sentivities: X=\(headSensitivityX), Y=\(headSensitivityY)")
        
        // Save these if we want persistence (omitted for now as per minimal change)
    }
    
    // MARK: - Calibration Persistence
    
    /// Save calibration values to UserDefaults
    private func saveCalibration() {
        UserDefaults.standard.set(leftCalibrationValue, forKey: calibrationLeftKey)
        UserDefaults.standard.set(rightCalibrationValue, forKey: calibrationRightKey)
        UserDefaults.standard.set(true, forKey: calibrationCompletedKey)
        print("Calibration saved: left=\(leftCalibrationValue), right=\(rightCalibrationValue)")
    }
    
    /// Load calibration values from UserDefaults
    private func loadCalibration() {
        if UserDefaults.standard.bool(forKey: calibrationCompletedKey) {
            leftCalibrationValue = UserDefaults.standard.float(forKey: calibrationLeftKey)
            rightCalibrationValue = UserDefaults.standard.float(forKey: calibrationRightKey)
            calibrationState = .completed
            print("Calibration loaded: left=\(leftCalibrationValue), right=\(rightCalibrationValue)")
        } else {
            // First time or no calibration: use sensible defaults and allow starting
            leftCalibrationValue = -0.15
            rightCalibrationValue = 0.15
            calibrationState = .completed
            print("No saved calibration found. Using defaults: left=-0.15, right=0.15")
        }
    }
    
    /// Clear saved calibration from UserDefaults
    private func clearCalibration() {
        UserDefaults.standard.removeObject(forKey: calibrationLeftKey)
        UserDefaults.standard.removeObject(forKey: calibrationRightKey)
        UserDefaults.standard.removeObject(forKey: calibrationCompletedKey)
        print("Calibration cleared")
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

        Task { @MainActor in
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
        
        // Apply smoothing to head rotation
        filteredHeadX = filteredHeadX + headSmoothingFactor * (rotation.y - filteredHeadX)
        filteredHeadY = filteredHeadY + headSmoothingFactor * (rotation.x - filteredHeadY)
        filteredHeadZ = filteredHeadZ + headSmoothingFactor * (rotation.z - filteredHeadZ)
        
        // Apply offset relative to neutral pose
        // X: Yaw (Left/Right)
        // Y: Pitch (Up/Down) - Note: ARKit Pitch might be inverted relative to screen Y.
        // Usually looking UP is positive Pitch in some systems, or negative?
        // We will rely on Calibration to determine Min/Max and direction.
        
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
