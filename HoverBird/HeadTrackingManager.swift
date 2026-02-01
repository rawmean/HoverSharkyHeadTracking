//
//  EyeTrackingManager.swift
//  BreakOut
//
//  Created by Ramin Rezaiifar on 1/24/26.
//

import ARKit
import Observation

/// Calibration state for head tracking
enum CalibrationState {
    case notStarted
    case lookingLeft
    case lookingRight
    case completed
}

/// Manages ARKit face tracking to detect head and eye movement for game control
@MainActor
@Observable
class HeadTrackingManager: NSObject {
    
    /// Normalized horizontal tracking position from -1.0 (left) to 1.0 (right)
    var trackingPositionX: Float = 0.0
    
    /// Head position in meters relative to the device (x: left-right, y: up-down, z: distance)
    var headPositionX: Float = 0.0
    var headPositionY: Float = 0.0
    var headPositionZ: Float = 0.0
    
    /// Whether face tracking is currently active
    var isTracking: Bool = false
    
    /// Error message if face tracking fails
    var errorMessage: String?
    
    /// Whether the environment is too dark for tracking
    var isEnvironmentTooDark: Bool = false
    
    /// Current calibration state
    var calibrationState: CalibrationState = .notStarted
    
    /// Whether the user has completed the onboarding instructions
    var onboardingCompleted: Bool = false
    
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
    static var isSupported: Bool {
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
    
    /// Apply calibration and low-pass filter to raw eye position
    private func processEyePosition(_ rawY: Float, headTranslation: SIMD3<Float>?) {
        rawEyeY = rawY
        
        // Process eye position (steering)
        let calibratedPosition: Float
        if calibrationState == .completed {
            let range = rightCalibrationValue - leftCalibrationValue
            if range != 0 {
                calibratedPosition = ((rawEyeY - leftCalibrationValue) / range) * 2 - 1
            } else {
                calibratedPosition = 0
            }
        } else {
            calibratedPosition = rawEyeY * 15.0
        }
        
        let clampedPosition = max(-1.0, min(1.0, calibratedPosition))
        filteredEyePosition = filteredEyePosition + smoothingFactor * (clampedPosition - filteredEyePosition)
        trackingPositionX = filteredEyePosition
        
        // Process head position (3D effect)
        if let translation = headTranslation {
            // Calibrate neutral pose on first valid reading
            if !hasSetNeutralPose {
                neutralHeadX = translation.x
                neutralHeadY = translation.y
                neutralHeadZ = translation.z
                hasSetNeutralPose = true
                
                // Initialize filtered values to neutral pose
                filteredHeadX = translation.x
                filteredHeadY = translation.y
                filteredHeadZ = translation.z
            }
            
            // Apply smoothing to head position
            filteredHeadX = filteredHeadX + headSmoothingFactor * (translation.x - filteredHeadX)
            filteredHeadY = filteredHeadY + headSmoothingFactor * (translation.y - filteredHeadY)
            filteredHeadZ = filteredHeadZ + headSmoothingFactor * (translation.z - filteredHeadZ)
            
            // Apply offset relative to neutral pose for frontal view at neutral position
            headPositionX = filteredHeadX - neutralHeadX
            headPositionY = filteredHeadY - neutralHeadY
            headPositionZ = (filteredHeadZ - neutralHeadZ) * 0.50 // Scale factor if needed
        }
    }
}

@MainActor
extension HeadTrackingManager: ARSessionDelegate {
    
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            return
        }
        
        // Extract eye rotation from the face transform
        // Using Y-axis rotation for horizontal eye movement (looking left/right)
        let eyeY = -faceAnchor.rightEyeTransform.eulerAngles.y
        
        // Extract head translation (position in 3D space)
        let translation = faceAnchor.transform.translation

        Task { @MainActor in
            self.processEyePosition(eyeY, headTranslation: translation)
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
