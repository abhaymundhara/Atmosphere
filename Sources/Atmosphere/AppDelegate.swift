import AppKit
import Foundation

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = PreferencesStore()
    private let locationService = LocationService()
    private let weatherProvider = OpenMeteoWeatherProvider()
    private let geometryProvider = CoreGraphicsWindowGeometryProvider()
    private let simulationEngine = SimulationEngine()

    private var overlayController: OverlayWindowController?
    private var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var geometryTimer: Timer?
    private var weatherState: WeatherState = .clear

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayWindowController(simulationEngine: simulationEngine)
        settingsController = SettingsWindowController(preferences: preferences)
        settingsController?.onChange = { [weak self] in
            self?.applyPreferences()
        }

        buildStatusMenu()
        overlayController?.show()
        applyPreferences()
        startTimers()
        Task { await refreshWeather() }
    }

    private func buildStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Atmosphere"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Refresh Weather", action: #selector(refreshWeatherFromMenu), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Atmosphere", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func startTimers() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshWeather() }
        }
        geometryTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshGeometry() }
        }
    }

    private func refreshGeometry() {
        let obstacles = geometryProvider.currentObstacles()
        overlayController?.update(weatherState: effectiveWeatherState(), obstacles: obstacles)
    }

    private func effectiveWeatherState() -> WeatherState {
        var state = preferences.debugMode.weatherState ?? weatherState
        state.intensity = min(max(state.intensity * preferences.intensityMultiplier, 0), 1)
        return state
    }

    private func applyPreferences() {
        preferences.overlayEnabled ? overlayController?.show() : overlayController?.hide()
        refreshGeometry()
    }

    private func refreshWeather() async {
        guard preferences.debugMode == .live else {
            weatherState = preferences.debugMode.weatherState ?? .clear
            refreshGeometry()
            return
        }

        do {
            let coordinate = try await locationService.requestCurrentCoordinate()
            weatherState = try await weatherProvider.currentWeather(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } catch {
            weatherState = .debugRain
        }
        refreshGeometry()
    }

    @objc private func showSettings() {
        settingsController?.show()
    }

    @objc private func refreshWeatherFromMenu() {
        Task { await refreshWeather() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
