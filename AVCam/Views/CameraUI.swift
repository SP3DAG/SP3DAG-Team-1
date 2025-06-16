import SwiftUI
import AVFoundation

struct CameraUI<CameraModel: Camera>: PlatformView {

    @State var camera: CameraModel
    @State private var showVerification = false
    let horizontalEdgePadding: CGFloat = 16

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
        .sheet(isPresented: $showVerification) {
            VerificationUIKitWrapper()
        }
    }
    var verifyButton: some View {
            Button(action: {
                withAnimation {
                    showVerification = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }) {
                Label("Verify", systemImage: "checkmark.shield.fill")
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(radius: 2)
            }
            .foregroundColor(.primary)
            .accessibilityLabel("Start verification")
        }

    @ViewBuilder
    var compactUI: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    FeaturesToolbar(camera: camera)
                    Spacer()
                    MainToolbar(camera: camera)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // Top-left verify button
                VStack {
                    HStack {
                        verifyButton
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, horizontalEdgePadding)
            }
        }
    }

    @ViewBuilder
    var regularUI: some View {
        VStack {
            Spacer()
            ZStack(alignment: .topLeading) {
                MainToolbar(camera: camera)
                FeaturesToolbar(camera: camera)
                    .frame(width: 250)
                    .offset(x: 250)

                Button(action: {
                    showVerification = true
                }) {
                    Text("Verify")
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
                .padding(.horizontal, horizontalEdgePadding)
                .offset(x: -250) // Adjust this if needed
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
