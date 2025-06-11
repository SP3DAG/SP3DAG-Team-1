import SwiftUI

struct LinkDeviceView: View {
    @Binding var isLinked: Bool
    @State private var isScanning = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var deviceUUID: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("GeoCam Device Linking")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let uuid = deviceUUID {
                Text("Already linked to device:")
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

            } else {
                Text("To start, scan the QR code from the website.")

                Button(action: {
                    isScanning = true
                }) {
                    Text("📷 Scan QR Code")
                        .fontWeight(.semibold)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                if showSuccess {
                    Text("Device linked successfully!")
                        .foregroundColor(.green)
                        .font(.headline)
                }
            }
        }
        .padding()
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
