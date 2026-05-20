import Foundation

@MainActor
final class PreferencesStore {
    private enum Keys {
        static let debugMode = "debugMode"
        static let intensityMultiplier = "intensityMultiplier"
        static let overlayEnabled = "overlayEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.intensityMultiplier) == nil {
            defaults.set(1.0, forKey: Keys.intensityMultiplier)
        }
        if defaults.object(forKey: Keys.overlayEnabled) == nil {
            defaults.set(true, forKey: Keys.overlayEnabled)
        }
    }

    var debugMode: DebugWeatherMode {
        get { DebugWeatherMode(rawValue: defaults.string(forKey: Keys.debugMode) ?? "") ?? .live }
        set { defaults.set(newValue.rawValue, forKey: Keys.debugMode) }
    }

    var intensityMultiplier: Double {
        get { defaults.double(forKey: Keys.intensityMultiplier) }
        set { defaults.set(min(max(newValue, 0.1), 2.0), forKey: Keys.intensityMultiplier) }
    }

    var overlayEnabled: Bool {
        get { defaults.bool(forKey: Keys.overlayEnabled) }
        set { defaults.set(newValue, forKey: Keys.overlayEnabled) }
    }
}
