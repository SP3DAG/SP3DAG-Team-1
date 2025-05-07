/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that provides the interface to the features of the camera.
*/

import SwiftUI
import Combine
import CoreLocation

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

    private(set) var isHDRVideoSupported = false
    private let mediaLibrary = MediaLibrary()
    private let captureService = CaptureService()
    private var cameraState = CameraState()

    // MARK: - Location support
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation?

    override init() {
        super.init()
        
        // Start location updates
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
        captureMode = cameraState.captureMode
        qualityPrioritization = cameraState.qualityPrioritization
        isLivePhotoEnabled = cameraState.isLivePhotoEnabled
        isHDRVideoEnabled = cameraState.isVideoHDREnabled
    }

    var captureMode = CaptureMode.photo {
        didSet {
            guard status == .running else { return }
            Task {
                isSwitchingModes = true
                defer { isSwitchingModes = false }
                try? await captureService.setCaptureMode(captureMode)
                cameraState.captureMode = captureMode
            }
        }
    }

    func switchVideoDevices() async {
        isSwitchingVideoDevices = true
        defer { isSwitchingVideoDevices = false }
        await captureService.selectNextVideoDevice()
    }

    // MARK: - Photo capture

    func capturePhoto() async {
        do {
            let photoFeatures = PhotoFeatures(isLivePhotoEnabled: isLivePhotoEnabled, qualityPrioritization: qualityPrioritization)
            let photo = try await captureService.capturePhoto(with: photoFeatures, location: currentLocation)
            try await mediaLibrary.save(photo: photo)
        } catch {
            self.error = error
        }
    }

    var isLivePhotoEnabled = true {
        didSet {
            cameraState.isLivePhotoEnabled = isLivePhotoEnabled
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

    // MARK: - Video capture

    var isHDRVideoEnabled = false {
        didSet {
            guard status == .running, captureMode == .video else { return }
            Task {
                await captureService.setHDRVideoEnabled(isHDRVideoEnabled)
                cameraState.isVideoHDREnabled = isHDRVideoEnabled
            }
        }
    }

    func toggleRecording() async {
        switch await captureService.captureActivity {
        case .movieCapture:
            do {
                let movie = try await captureService.stopRecording()
                try await mediaLibrary.save(movie: movie)
            } catch {
                self.error = error
            }
        default:
            await captureService.startRecording()
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
            for await capabilities in await captureService.$captureCapabilities.values {
                isHDRVideoSupported = capabilities.isHDRSupported
                cameraState.isVideoHDRSupported = capabilities.isHDRSupported
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
