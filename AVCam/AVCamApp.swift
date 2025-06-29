import os
import SwiftUI

@main
struct AVCamApp: App {
    @State private var camera = CameraModel()
    @State private var isLinked: Bool = UserDefaults.standard.string(forKey: "deviceUUID") != nil
    @State private var showSettings = false
    @Environment(\.scenePhase) var scenePhase

    init() {
        if let id = UserDefaults.standard.string(forKey: "deviceUUID") {
            SessionManager.shared.deviceID = id
        }
    }

    var body: some Scene {
        WindowGroup {
            if isLinked {
                ZStack(alignment: .topTrailing) {
                    CameraView(camera: camera, showSettings: $showSettings)
                        .statusBarHidden(false)
                        .task {
                            await camera.start()
                            do {
                                let pem = try KeyManager.getPublicKey().toPEM()
                                print("Public Key PEM:\n\(pem)")
                            } catch {
                                print("Failed to get PEM key: \(error)")
                            }
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            guard camera.status == .running, newPhase == .active else { return }
                            Task { @MainActor in
                                await camera.syncState()
                            }
                        }
                }
                .sheet(isPresented: $showSettings) {
                    LinkDeviceView(isLinked: $isLinked)
                }
            } else {
                WelcomeLinkView(isLinked: $isLinked)
            }
        }
    }
}

let logger = Logger()
