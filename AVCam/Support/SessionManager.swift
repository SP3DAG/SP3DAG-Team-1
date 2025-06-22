import Foundation

final class SessionManager {
    static let shared = SessionManager()

    private init() {}

    var deviceID: String?
}
