import SwiftUI

typealias AspectRatio = CGSize
let photoAspectRatio = AspectRatio(width: 3.0, height: 4.0)

@MainActor
struct PreviewContainer<Content: View, CameraModel: Camera>: View {

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var camera: CameraModel

    @State private var blurRadius = CGFloat.zero
    private let content: Content

    init(camera: CameraModel, @ViewBuilder content: () -> Content) {
        self.camera = camera
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let fullWidth = geometry.size.width
            let maxHeight = geometry.size.height
            let aspectRatio = photoAspectRatio.height / photoAspectRatio.width
            let previewHeight = fullWidth * aspectRatio
            
            // Shift preview upward slightly (e.g., 20 points)
            let verticalOffset = CGFloat(-20)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                content
                    .frame(width: fullWidth, height: previewHeight)
                    .clipped()
                    .offset(y: verticalOffset) // ⬅️ shift the preview up
                    .blur(radius: blurRadius, opaque: true)
                    .background(Color.black)

                Spacer(minLength: 0)
            }
            .frame(width: fullWidth, height: maxHeight)
        }
    }

    func updateBlurRadius(_: Bool, _ isSwitching: Bool) {
        withAnimation {
            blurRadius = isSwitching ? 30 : 0
        }
    }
}
