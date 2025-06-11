import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Welcome to GeoCam")
                .font(.title)
                .padding()

            SignInWithAppleButton(.signIn, onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            }, onCompletion: { result in
                switch result {
                case .success(let authorization):
                    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        let userID = appleIDCredential.user
                        print("Signed in as: \(userID)")
                        session.signIn(userID: userID)
                    }
                case .failure(let error):
                    print("Sign in failed: \(error.localizedDescription)")
                }
            })
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding()

            Spacer()
        }
    }
}
