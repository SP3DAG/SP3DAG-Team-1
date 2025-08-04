# GeoCam

GeoCam is a prototype camera application developed by the Institute for Geoinformatics at the University of Münster. The project addresses the growing challenge of verifying the authenticity of digital media, particularly in the context of misinformation and manipulated images.

## Key Features

- Capture cryptographically signed and geotagged images
- Visual feedback and verification workflows
- Integration with a backend for key management and media validation
- Modular architecture for handling camera input, capture sessions, and secure processing

## Project Structure

Below is an overview of the main directories and their responsibilities:

- **AVCamApp.swift**  
  Entry point of the SwiftUI application.

- **Capture/**  
  Contains lower-level AVFoundation logic for photo and video capture. Includes:
  - `PhotoCapture.swift` for managing AVFoundation capture outputs.

- **Model/**  
  Core data types and state management. Includes:
  - `CameraState.swift` for managing camera state transitions.
  - `KeyManager.swift` for handling public/private keys.
  - `QRSteganography.swift` for embedding metadata in QR codes and hiding them using steganography.

- **Support/**  
  General-purpose utilities and shared services. Includes:
  - `APIService.swift` for backend communication.
  - `SessionManager.swift` and `SignInManager.swift` for session and authentication logic.
  - `SecKey_PEM.swift` and `SevenHasher.swift` for cryptographic support.

- **Views/**  
  The SwiftUI-based user interface. Includes:
  - `CameraUI.swift` and `CameraPreview.swift` for live camera interaction.
  - `VerificationViewController.swift` and related files for image verification.
  - `Toolbars/` and `Overlays/` for user controls and real-time visual feedback.

## Local Installation

To run GeoCam locally with a custom backend, you must specify the IP address of your backend server.

1. Open `APIService.swift`
2. Locate the following section (lines 56 to 59):

    ```swift
    static var baseURL: String {
        return "http://192.168.178.42:10000" // ONLY CHANGE IP ADDRESS, NO NEED TO CHANGE PORT
    }
    ```

3. Replace `192.168.178.42` with the IP address of the computer running your backend service. The port should remain `10000`.

Make sure both your iOS device and backend server are on the same local network.
