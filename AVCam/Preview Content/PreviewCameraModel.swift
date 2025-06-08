import Foundation
import SwiftUI

class PreviewCameraModel: Camera {
    
    var prefersMinimizedUI = false
    var qualityPrioritization = QualityPrioritization.quality
    var shouldFlashScreen = false

    struct PreviewSourceStub: PreviewSource {
        func connect(to target: PreviewTarget) {}
    }

    let previewSource: PreviewSource = PreviewSourceStub()

    private(set) var status = CameraStatus.unknown
    @Published private(set) var captureActivity = CaptureActivity.idle
    private(set) var isSwitchingVideoDevices = false
    private(set) var thumbnail: CGImage?

    var error: Error?

    init(status: CameraStatus = .unknown) {
        self.status = status
    }

    func start() async {
        if status == .unknown {
            status = .running
        }
    }

    func switchVideoDevices() {
        logger.debug("Device switching isn't implemented in PreviewCamera.")
    }

    func capturePhoto() {
        logger.debug("Photo capture isn't implemented in PreviewCamera.")
    }

    func focusAndExpose(at point: CGPoint) {
        logger.debug("Focus and expose isn't implemented in PreviewCamera.")
    }

    func syncState() async {
        logger.debug("Syncing state isn't implemented in PreviewCamera.")
    }
}
