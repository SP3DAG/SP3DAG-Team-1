/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main user interface for the sample app.
*/

import SwiftUI
import AVFoundation
import AVKit

@MainActor
struct CameraView: PlatformView {
    @Bindable var camera: CameraModel
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    
    // The direction a person swipes on the camera preview or mode selector.
    @State var swipeDirection = SwipeDirection.left
    
    var body: some View {
        ZStack {
            // A container view that manages the placement of the preview.
            PreviewContainer(camera: camera) {
                // A view that provides a preview of the captured content.
                CameraPreview(source: camera.previewSource)
                    // Handle capture events from device hardware buttons.
                    .onCameraCaptureEvent { event in
                        if event.phase == .ended {
                            Task {
                                switch camera.captureMode {
                                case .photo:
                                    // Capture a photo when pressing a hardware button.
                                    await camera.capturePhoto()
                                case .video:
                                    // Toggle video recording when pressing a hardware button.
                                    await camera.toggleRecording()
                                }
                            }
                        }
                    }
                    // Focus and expose at the tapped point.
                    .onTapGesture { location in
                        Task { await camera.focusAndExpose(at: location) }
                    }
                    // Switch between capture modes by swiping left and right.
                    .simultaneousGesture(swipeGesture)
                    // Flash the screen briefly
                    .opacity(camera.shouldFlashScreen ? 0 : 1)
            }

            // The main camera user interface.
            CameraUI(camera: camera, swipeDirection: $swipeDirection)

            // Overlay animation on top of everything
            if camera.showGeoSignedConfirmation {
                GlobeWarpMorphView(show: $camera.showGeoSignedConfirmation)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
    }
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded {
                // Capture swipe direction.
                swipeDirection = $0.translation.width < 0 ? .left : .right
            }
    }
}
enum SwipeDirection {
    case left
    case right
    case up
    case down
}
