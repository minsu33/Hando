import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let providerID = "providerID"
        static let typefaceID = "typefaceID"
        static let refreshInterval = "refreshInterval"
    }

    static let minRefresh: TimeInterval = 60
    static let defaultRefresh: TimeInterval = 120

    private let defaults: UserDefaults

    @Published var providerID: String? {
        didSet { defaults.set(providerID, forKey: Key.providerID) }
    }
    @Published var typefaceID: String {
        didSet { defaults.set(typefaceID, forKey: Key.typefaceID) }
    }
    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        providerID = defaults.string(forKey: Key.providerID)
        typefaceID = defaults.string(forKey: Key.typefaceID) ?? TypefaceCatalog.defaultID
        let saved = defaults.double(forKey: Key.refreshInterval)
        refreshInterval = saved > 0 ? max(saved, Self.minRefresh) : Self.defaultRefresh
    }
}
