/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that manages a photo capture output to take photographs.
*/

import AVFoundation
import CoreImage
import UIKit
import CoreLocation

enum PhotoCaptureError: Error {
    case noPhotoData
}

final class PhotoCapture: OutputService {
    
    @Published private(set) var captureActivity: CaptureActivity = .idle
    let output = AVCapturePhotoOutput()
    private var photoOutput: AVCapturePhotoOutput { output }
    private(set) var capabilities: CaptureCapabilities = .unknown

    func capturePhoto(with features: PhotoFeatures, location: CLLocation? = nil) async throws -> Photo {
        try await withCheckedThrowingContinuation { continuation in
            let photoSettings = createPhotoSettings(with: features)
            let delegate = PhotoCaptureDelegate(continuation: continuation, location: location)
            monitorProgress(of: delegate)
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }

    private func createPhotoSettings(with features: PhotoFeatures) -> AVCapturePhotoSettings {
        var photoSettings = AVCapturePhotoSettings()
        
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }

        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }

        photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        if let prioritization = AVCapturePhotoOutput.QualityPrioritization(rawValue: features.qualityPrioritization.rawValue) {
            photoSettings.photoQualityPrioritization = prioritization
        }

        return photoSettings
    }

    private func monitorProgress(of delegate: PhotoCaptureDelegate, isolation: isolated (any Actor)? = #isolation) {
        Task {
            _ = isolation
            for await activity in delegate.activityStream {
                captureActivity = activity
            }
        }
    }

    func updateConfiguration(for device: AVCaptureDevice) {
        photoOutput.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last ?? .zero
        photoOutput.maxPhotoQualityPrioritization = .quality
        photoOutput.isResponsiveCaptureEnabled = photoOutput.isResponsiveCaptureSupported
        photoOutput.isFastCapturePrioritizationEnabled = photoOutput.isFastCapturePrioritizationSupported
        photoOutput.isAutoDeferredPhotoDeliveryEnabled = photoOutput.isAutoDeferredPhotoDeliverySupported
        updateCapabilities(for: device)
    }

    private func updateCapabilities(for device: AVCaptureDevice) {
        capabilities = CaptureCapabilities()
    }
}

typealias PhotoContinuation = CheckedContinuation<Photo, Error>

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let continuation: PhotoContinuation
    private var isLivePhoto = false
    private var isProxyPhoto = false
    private var photoData: Data?
    private var livePhotoMovieURL: URL?
    private let location: CLLocation?

    let activityStream: AsyncStream<CaptureActivity>
    private let activityContinuation: AsyncStream<CaptureActivity>.Continuation

    init(continuation: PhotoContinuation, location: CLLocation?) {
        self.continuation = continuation
        self.location = location
        let (activityStream, activityContinuation) = AsyncStream.makeStream(of: CaptureActivity.self)
        self.activityStream = activityStream
        self.activityContinuation = activityContinuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        activityContinuation.yield(.photoCapture(willCapture: true))
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?, error: Error?) {
        if let error = error {
            logger.debug("Error capturing deferred photo: \(error)")
            return
        }
        photoData = deferredPhotoProxy?.fileDataRepresentation()
        isProxyPhoto = true
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.debug("Error capturing photo: \(String(describing: error))")
            return
        }
        photoData = photo.fileDataRepresentation()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        defer {
            activityContinuation.finish()
        }

        if let error {
            continuation.resume(throwing: error)
            return
        }

        guard let originalData = photoData, let image = UIImage(data: originalData) else {
            continuation.resume(throwing: PhotoCaptureError.noPhotoData)
            return
        }

        // Embed hidden message before saving
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        formatter.timeZone = .current  // <- Use device's local time zone
        let localTimeString = formatter.string(from: Date())
        var hiddenMessage = "Captured at: \(localTimeString)"
        if let location = location {
            let lat = String(format: "%.5f", location.coordinate.latitude)
            let lon = String(format: "%.5f", location.coordinate.longitude)
            hiddenMessage += " | Location: \(lat), \(lon)"
        }

        let finalData: Data
        if let deviceID = SessionManager.shared.deviceID {
            print("Device ID found: \(deviceID)")
            if let stegoImage = embedQRInBlueLSB(message: hiddenMessage, into: image, deviceID: deviceID),
               let stegoData = stegoImage.pngData() {
                print("Embedding succeeded")
                finalData = stegoData
            } else {
                print("Embedding failed, falling back to original")
                finalData = originalData
            }
        } else {
            print("No device ID found, falling back to original")
            finalData = originalData
        }

        let photo = Photo(data: finalData, isProxy: isProxyPhoto)
        continuation.resume(returning: photo)
    }
}

private func embedQRInBlueLSB(message: String, into image: UIImage, deviceID: String) -> UIImage? {
    let stego = QRSteganography(blockSize: 8)
    return stego.embedMultipleQRsInBlueChannel(image: image, qrTexts: [message], deviceID: deviceID)
}
