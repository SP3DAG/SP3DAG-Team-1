import SwiftUI

/// A SwiftUI-compatible wrapper for VerificationViewController (UIKit)
struct VerificationUIKitWrapper: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UIViewController {
        // Embed the UIKit view controller in a navigation controller if desired
        let verificationVC = VerificationViewController()
        let navController = UINavigationController(rootViewController: verificationVC)
        return navController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No dynamic update logic needed for now
    }
}
