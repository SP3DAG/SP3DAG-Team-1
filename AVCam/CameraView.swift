import SwiftUI
import AVFoundation
import AVKit
import NVActivityIndicatorView

@MainActor
struct CameraView: PlatformView {
    @Bindable var camera: CameraModel
    @Binding var showSettings: Bool

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var swipeDirection = SwipeDirection.left

    var body: some View {
        ZStack {
            // === Camera content ===
            Group {
                PreviewContainer(camera: camera) {
                    CameraPreview(source: camera.previewSource)
                        .onCameraCaptureEvent { event in
                            if event.phase == .ended {
                                Task {
                                    await camera.capturePhoto()
                                }
                            }
                        }
                        .onTapGesture { location in
                            Task { await camera.focusAndExpose(at: location) }
                        }
                        .opacity(camera.shouldFlashScreen ? 0 : 1)
                }

                CameraUI(camera: camera)
            }
            .allowsHitTesting(!camera.isInteractionLocked)
            .zIndex(0)

            // === Loading overlay ===
            if camera.isLoading && !camera.showGeoSignedConfirmation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .zIndex(10)

                VStack {
                    LoadingIndicatorView()
                        .frame(width: 60, height: 60)
                    Text("Processing...")
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
                .ignoresSafeArea()
                .zIndex(11)
            }

            // === Signing animation ===
            if camera.showGeoSignedConfirmation {
                GlobeWarpMorphView(show: $camera.showGeoSignedConfirmation) {
                    camera.isLoading = false
                }
                .transition(.opacity)
                .zIndex(20)
            }

            // === Settings button (always on top) ===
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showSettings = true
                        print("Settings tapped")
                    }) {
                        Image(systemName: "gearshape.fill")
                            .padding()
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(camera.isInteractionLocked)
                    .opacity(camera.isInteractionLocked ? 0.4 : 1.0)
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .zIndex(30)
        }
    }
}

enum SwipeDirection {
    case left
    case right
    case up
    case down
}
