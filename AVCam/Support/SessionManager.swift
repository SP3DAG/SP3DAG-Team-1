import Foundation

class SessionManager: ObservableObject {
    @Published var isSignedIn: Bool

    init() {
        // Check if user ID exists
        self.isSignedIn = UserDefaults.standard.string(forKey: "appleUserID") != nil
    }

    func signIn(userID: String) {
        UserDefaults.standard.set(userID, forKey: "appleUserID")
        self.isSignedIn = true
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        self.isSignedIn = false
    }
}
