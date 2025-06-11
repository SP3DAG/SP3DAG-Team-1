import SwiftUI
import Combine
import CoreLocation
import Foundation
import Security

@Observable
final class CameraModel: NSObject, Camera {

    private(set) var status = CameraStatus.unknown
    private(set) var captureActivity = CaptureActivity.idle
    private(set) var isSwitchingVideoDevices = false
    private(set) var prefersMinimizedUI = false
    private(set) var isSwitchingModes = false
    private(set) var shouldFlashScreen = false
    private(set) var thumbnail: CGImage?
    private(set) var error: Error?

    var previewSource: PreviewSource { captureService.previewSource }

    var showGeoSignedConfirmation: Bool = false

    private let mediaLibrary = MediaLibrary()
    private let captureService = CaptureService()
    private var cameraState = CameraState()

    // MARK: - Location support
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Starting the camera

    func start() async {
        guard await captureService.isAuthorized else {
            status = .unauthorized
            return
        }
        do {
            await syncState()
            try await captureService.start(with: cameraState)
            observeState()
            status = .running
        } catch {
            logger.error("Failed to start capture service. \(error)")
            status = .failed
        }
    }

    func syncState() async {
        cameraState = await CameraState.current
        qualityPrioritization = cameraState.qualityPrioritization
    }

    func switchVideoDevices() async {
        isSwitchingVideoDevices = true
        defer { isSwitchingVideoDevices = false }
        await captureService.selectNextVideoDevice()
    }

    // MARK: - Photo capture

    func capturePhoto() async {
        print("Starting capturePhoto()")

        do {
            let photoFeatures = PhotoFeatures(qualityPrioritization: qualityPrioritization)
            print("Created photo features")

            let photo = try await captureService.capturePhoto(with: photoFeatures, location: currentLocation)
            print("Photo captured")

            try await mediaLibrary.save(photo: photo)
            print("Photo saved to media library")

            DispatchQueue.main.async {
                self.showGeoSignedConfirmation = true
                print("Triggered animation")
            }
        } catch {
            print("Error during photo capture: \(error)")
            self.error = error
        }
    }


    var qualityPrioritization = QualityPrioritization.quality {
        didSet {
            cameraState.qualityPrioritization = qualityPrioritization
        }
    }

    func focusAndExpose(at point: CGPoint) async {
        await captureService.focusAndExpose(at: point)
    }

    private func flashScreen() {
        shouldFlashScreen = true
        withAnimation(.linear(duration: 0.01)) {
            shouldFlashScreen = false
        }
    }

    // MARK: - Internal state observations

    private func observeState() {
        Task {
            for await thumbnail in mediaLibrary.thumbnails.compactMap({ $0 }) {
                self.thumbnail = thumbnail
            }
        }

        Task {
            for await activity in await captureService.$captureActivity.values {
                if activity.willCapture {
                    flashScreen()
                } else {
                    captureActivity = activity
                }
            }
        }

        Task {
            for await isShowingFullscreenControls in await captureService.$isShowingFullscreenControls.values {
                withAnimation {
                    prefersMinimizedUI = isShowingFullscreenControls
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension CameraModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}

func testKeyGeneration() {
    do {
        let privateKey = try KeyManager.loadOrCreatePrivateKey()
        print("Private key generated or loaded.")

        let publicKey = try KeyManager.getPublicKey()
        print("Public key extracted.")

        // Print key attributes (just basic inspection)
        if let privateKeyAttrs = SecKeyCopyAttributes(privateKey) as? [String: Any],
           let publicKeyAttrs = SecKeyCopyAttributes(publicKey) as? [String: Any] {
            print("Private Key Attributes: \(privateKeyAttrs)")
            print("Public Key Attributes: \(publicKeyAttrs)")
        }

    } catch {
        print("Key generation failed: \(error.localizedDescription)")
    }
}
