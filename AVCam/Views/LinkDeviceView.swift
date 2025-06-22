import SwiftUI

struct LinkDeviceView: View {
    @Binding var isLinked: Bool
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var deviceUUID: String?
    @State private var isLoading = false

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "link.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)

                Text("GeoCam Device Linking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if let uuid = deviceUUID {
                    VStack(spacing: 8) {
                        Text("This device is linked to:")
                            .font(.headline)
                        Text(uuid)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)

                        if showSuccess {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Device linked successfully!")
                            }
                            .foregroundColor(.green)
                            .font(.subheadline)
                            .transition(.opacity)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Tap the button below to link this device to the GeoCam system.")
                            .multilineTextAlignment(.center)
                            .font(.body)

                        Button(action: {
                            Task {
                                await linkDeviceAutomatically()
                            }
                        }) {
                            Label("Link Device", systemImage: "link")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isLoading ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(isLoading)

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(radius: 10)
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            deviceUUID = UserDefaults.standard.string(forKey: "deviceUUID")
            isLinked = deviceUUID != nil
        }
    }

    private func linkDeviceAutomatically() async {
        isLoading = true
        errorMessage = nil
        showSuccess = false

        do {
            let linkInfo = try await APIService.generateLinkToken()
            let token = linkInfo.token
            let uuid = linkInfo.device_uuid

            let pem = try KeyManager.getPublicKey().toPEM()
            let success = try await APIService.uploadLinkToken(token: token, publicKey: pem)

            if success {
                UserDefaults.standard.set(uuid, forKey: "deviceUUID")
                SessionManager.shared.deviceID = uuid
                deviceUUID = uuid
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
