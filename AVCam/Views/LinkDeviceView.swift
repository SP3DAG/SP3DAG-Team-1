import SwiftUI

struct LinkDeviceView: View {
    @Binding var isLinked: Bool
    @State private var isScanning = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var deviceUUID: String?

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

                Group {
                    if let uuid = deviceUUID {
                        VStack(spacing: 8) {
                            Text("This device is currently linked to:")
                                .font(.headline)
                            Text(uuid)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)

                            Button("Unlink Device") {
                                UserDefaults.standard.removeObject(forKey: "deviceUUID")
                                deviceUUID = nil
                                isLinked = false
                            }
                            .foregroundColor(.red)
                            .padding(.top)
                        }

                    } else {
                        VStack(spacing: 12) {
                            Text("To start, visit the website and scan the QR code to link your device.")
                                .multilineTextAlignment(.center)
                                .font(.body)

                            Link("Go to example.com", destination: URL(string: "https://example.com")!)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .underline()

                            Button(action: {
                                isScanning = true
                            }) {
                                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }

                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }

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
                    }
                }
                .padding()
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
        .sheet(isPresented: $isScanning) {
            QRCodeScannerView { result in
                isScanning = false
                switch result {
                case .success(let payload):
                    Task {
                        await linkDevice(with: payload)
                    }
                case .failure(let error):
                    errorMessage = "Scan failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func linkDevice(with payload: String) async {
        do {
            guard let data = payload.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
                  let token = json["token"], let uuid = json["uuid"] else {
                errorMessage = "Invalid QR code format"
                return
            }

            let pem = try KeyManager.getPublicKey().toPEM()
            let success = try await APIService.uploadLinkToken(token: token, publicKey: pem)

            if success {
                UserDefaults.standard.set(uuid, forKey: "deviceUUID")
                deviceUUID = uuid
                isLinked = true
                showSuccess = true
            } else {
                errorMessage = "Linking failed. Try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
