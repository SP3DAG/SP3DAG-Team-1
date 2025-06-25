import SwiftUI

struct LinkDeviceView: View {
    // External binding that other views can read
    @Binding var isLinked: Bool

    // Local state
    @State private var deviceUUID  : String?
    @State private var isLoading   = false
    @State private var errorMessage: String?

    // MARK: – Body
    var body: some View {
        VStack {
            Spacer()
            Group {
                if let uuid = deviceUUID {
                    linkedContent(uuid: uuid)
                } else if isLoading {
                    loadingContent
                } else {
                    errorContent
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .shadow(radius: 8)
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onAppear(perform: configure)
        .animation(.default, value: deviceUUID)
    }

    // MARK: – Sub-views
    private func linkedContent(uuid: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.green)

            Text("Device registered")
                .font(.largeTitle).fontWeight(.bold)

            VStack(spacing: 6) {
                Text("Device ID")
                    .font(.headline)
                Text(uuid)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var loadingContent: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.4)

            Text("Registering device…")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }

    private var errorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundColor(.orange)

            Text(errorMessage ?? "Registration failed")
                .multilineTextAlignment(.center)
                .font(.body)

            Button("Try Again") {
                Task { await linkDeviceAutomatically() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: – Lifecycle helpers
    private func configure() {
        // If already stored, just show it
        if let stored = UserDefaults.standard.string(forKey: "deviceUUID") {
            deviceUUID = stored
            isLinked   = true
        } else {
            // Otherwise kick off automatic registration
            Task { await linkDeviceAutomatically() }
        }
    }

    // MARK: – Networking
    private func linkDeviceAutomatically() async {
        isLoading     = true
        errorMessage  = nil

        do {
            let linkInfo   = try await APIService.generateLinkToken()
            let pem        = try KeyManager.getPublicKey().toPEM()
            let uploaded   = try await APIService.uploadLinkToken(token: linkInfo.token,
                                                                  publicKey: pem)

            guard uploaded else { throw URLError(.badServerResponse) }

            UserDefaults.standard.set(linkInfo.device_uuid, forKey: "deviceUUID")
            SessionManager.shared.deviceID = linkInfo.device_uuid

            deviceUUID = linkInfo.device_uuid
            isLinked   = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
