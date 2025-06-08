import AVFoundation

// MARK: - Supporting types

/// An enumeration that describes the current status of the camera.
enum CameraStatus {
    case unknown
    case unauthorized
    case failed
    case running
    case interrupted
}

/// An enumeration that defines the activity states the capture service supports.
///
/// This type provides feedback to the UI regarding the active status of the `CaptureService` actor.
enum CaptureActivity {
    case idle
    case photoCapture(willCapture: Bool = false)

    var willCapture: Bool {
        if case .photoCapture(let willCapture) = self {
            return willCapture
        }
        return false
    }
}

/// A structure that represents a captured photo.
struct Photo: Sendable {
    let data: Data
    let isProxy: Bool
}

/// A structure for photo capture feature configuration.
struct PhotoFeatures {
    let qualityPrioritization: QualityPrioritization
}

/// A structure that represents the capture capabilities of `CaptureService`.
struct CaptureCapabilities {
    static let unknown = CaptureCapabilities()
}

/// Photo quality/speed tradeoff configuration.
enum QualityPrioritization: Int, Identifiable, CaseIterable, CustomStringConvertible, Codable {
    var id: Self { self }
    case speed = 1
    case balanced
    case quality

    var description: String {
        switch self {
        case .speed: return "Speed"
        case .balanced: return "Balanced"
        case .quality: return "Quality"
        }
    }
}

/// Camera-related setup errors.
enum CameraError: Error {
    case videoDeviceUnavailable
    case audioDeviceUnavailable
    case addInputFailed
    case addOutputFailed
    case setupFailed
    case deviceChangeFailed
}

/// Protocol for capture services (e.g. photo).
protocol OutputService {
    associatedtype Output: AVCaptureOutput
    var output: Output { get }
    var captureActivity: CaptureActivity { get }
    var capabilities: CaptureCapabilities { get }
    func updateConfiguration(for device: AVCaptureDevice)
    func setVideoRotationAngle(_ angle: CGFloat)
}

extension OutputService {
    func setVideoRotationAngle(_ angle: CGFloat) {
        output.connection(with: .video)?.videoRotationAngle = angle
    }

    func updateConfiguration(for device: AVCaptureDevice) {}
}
