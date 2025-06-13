import SwiftUI

struct SigningProgressView: View {
    @Binding var show: Bool

    var onDismiss: (() -> Void)? = nil

    @State private var showWarp = false

    var body: some View {
        ZStack {
            if show {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .frame(width: 240, height: 220)
                    .shadow(radius: 8)

                VStack(spacing: 16) {
                    if !showWarp {
                        // Show loading spinner
                        LoadingIndicatorView(size: 50, color: .white)
                            .frame(height: 64)
                            .onAppear {
                                // Simulate transition to warp
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        showWarp = true
                                    }
                                }
                            }
                    } else {
                        // Show warp animation
                        GlobeWarpMorphView(show: $show, onDismiss: {
                            onDismiss?()
                            showWarp = false
                        })
                        .transition(.opacity)
                    }

                    Text(showWarp ? "Successfully Geo-Signed" : "Embedding Information")
                        .font(.headline)
                        .foregroundColor(.white)
                        .opacity(0.9)
                        .frame(height: 24)
                }
            }
        }
    }
}
