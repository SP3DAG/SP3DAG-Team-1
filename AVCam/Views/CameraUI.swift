import SwiftUI
import AVFoundation

/// A view that presents the main camera user interface.
struct CameraUI<CameraModel: Camera>: PlatformView {
    
    @State var camera: CameraModel
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if isRegularSize {
                regularUI
            } else {
                compactUI
            }
        }
        .overlay {
            StatusOverlayView(status: camera.status)
        }
    }
    
    /// This view arranges UI elements vertically.
    @ViewBuilder
    var compactUI: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                FeaturesToolbar(camera: camera)
                Spacer()
                MainToolbar(camera: camera)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    /// This view arranges UI elements in a layered stack.
    @ViewBuilder
    var regularUI: some View {
        VStack {
            Spacer()
            ZStack {
                MainToolbar(camera: camera)
                FeaturesToolbar(camera: camera)
                    .frame(width: 250)
                    .offset(x: 250)
            }
            .frame(width: 740)
            .background(.ultraThinMaterial.opacity(0.8))
            .cornerRadius(12)
            .padding(.bottom, 32)
        }
    }
    
    var bottomPadding: CGFloat {
        let bounds = UIScreen.main.bounds
        let rect = AVMakeRect(aspectRatio: photoAspectRatio, insideRect: bounds)
        return (rect.minY.rounded() / 2) + 12
    }
}

#Preview {
    CameraUI(camera: PreviewCameraModel())
}
