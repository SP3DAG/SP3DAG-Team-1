import SwiftUI

struct WelcomeLinkView: View {
    @Binding var isLinked: Bool
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

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
                        //.foregroundColor(.blue)

                    Text("Welcome to GeoCam")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        Text("To get started, link your device by scanning a QR code.")
                        Text("Go to example.com to generate your QR code.")
                    }
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 8)
                )
                .padding(.horizontal)

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
                        .padding(.horizontal)
                }

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
