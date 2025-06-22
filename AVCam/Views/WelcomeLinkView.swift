import SwiftUI

struct WelcomeLinkView: View {
    @Binding var isLinked: Bool
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [
                Color(hex: "#3B5463"),
                Color(hex: "#1D161D")
            ]), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    Image("StartImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)

                    Text("Welcome to GeoCam")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Tap below to link your device automatically.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 8)
                )
                .padding(.horizontal)

                Button(action: {
                    Task {
                        await linkDeviceAutomatically()
                    }
                }) {
                    Label("Link Device", systemImage: "link.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .disabled(isLoading)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Device linked successfully!")
                    }
                    .foregroundColor(.green)
                    .font(.subheadline)
                    .transition(.opacity)
                    .padding(.top, 4)
                }

                Spacer()
            }
            .animation(.easeInOut, value: showSuccess)
        }
    }

    private func linkDeviceAutomatically() async {
        isLoading = true
        errorMessage = nil
        showSuccess = false

        do {
            // 1. Ask backend to generate a new token + device ID
            let linkInfo = try await APIService.generateLinkToken()
            let token = linkInfo.token
            let uuid = linkInfo.device_uuid

            // 2. Convert public key to PEM
            let pem = try KeyManager.getPublicKey().toPEM()

            // 3. Upload public key to backend
            let success = try await APIService.uploadLinkToken(token: token, publicKey: pem)

            if success {
                UserDefaults.standard.set(uuid, forKey: "deviceUUID")
                SessionManager.shared.deviceID = uuid
                isLinked = true
                showSuccess = true
            } else {
                errorMessage = "Linking failed. Try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
#if DEBUG
struct WelcomeLinkView_Previews: PreviewProvider {
    static var previews: some View {
        SimulatedWelcomeContainer()
    }

    struct SimulatedWelcomeContainer: View {
        @State private var isLinked = false

        var body: some View {
            WelcomeLinkView(isLinked: $isLinked)
        }
    }
}
#endif
