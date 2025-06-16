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
    @State private var showInfo = false
    
    let horizontalEdgePadding: CGFloat = 16

    var body: some View {
        ZStack {
            // === Camera content ===
            ZStack {
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
            .blur(radius: camera.isLoading ? 4 : 0)
            .disabled(camera.isLoading)
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
            // === Settings and Info buttons ===
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .padding(.trailing, 4)
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(camera.isLoading)
                    .opacity(camera.isLoading ? 0.4 : 1.0)

                    Button(action: {
                        showSettings = true
                        print("Settings tapped")
                    }) {
                        Image(systemName: "gearshape.fill")
                            .padding(.leading, 4)
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(camera.isLoading)
                    .opacity(camera.isLoading ? 0.4 : 1.0)
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, horizontalEdgePadding)
            .zIndex(30)
            .sheet(isPresented: $showInfo) {
                InfoView()
            }
        }
    }
}

enum SwipeDirection {
    case left
    case right
    case up
    case down
}
