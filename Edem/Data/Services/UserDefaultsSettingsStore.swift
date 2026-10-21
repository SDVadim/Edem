import Foundation
import Observation

@MainActor
@Observable
final class UserDefaultsSettingsStore: SettingsStore {
    private enum Key {
        static let userName = "settings.userName"
        static let email = "settings.email"
        static let simulateNoConnection = "settings.simulateNoConnection"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var userName: String {
        didSet { defaults.set(userName, forKey: Key.userName) }
    }

    var email: String {
        didSet { defaults.set(email, forKey: Key.email) }
    }

    var simulateNoConnection: Bool {
        didSet { defaults.set(simulateNoConnection, forKey: Key.simulateNoConnection) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        userName = defaults.string(forKey: Key.userName) ?? "Аня"
        email = defaults.string(forKey: Key.email) ?? "anya@example.com"
        simulateNoConnection = defaults.bool(forKey: Key.simulateNoConnection)
    }
}
