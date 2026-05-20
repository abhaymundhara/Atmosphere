import AppKit

@MainActor
final class SettingsWindowController {
    private let preferences: PreferencesStore
    private var window: NSWindow?
    private let conditionLabel = NSTextField(labelWithString: "Loading weather")
    private let detailLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    private let effectLabel = NSTextField(labelWithString: "")
    var onChange: (() -> Void)?

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Atmosphere Dashboard"
        panel.center()
        panel.contentView = makeContentView()
        panel.isReleasedWhenClosed = false
        window = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeContentView() -> NSView {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)

        let title = NSTextField(labelWithString: "Atmosphere")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        conditionLabel.font = .systemFont(ofSize: 32, weight: .bold)
        detailLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        sourceLabel.textColor = .secondaryLabelColor
        effectLabel.textColor = .secondaryLabelColor

        let mode = NSPopUpButton()
        DebugWeatherMode.allCases.forEach { mode.addItem(withTitle: $0.rawValue.capitalized) }
        mode.selectItem(withTitle: preferences.debugMode.rawValue.capitalized)
        mode.target = self
        mode.action = #selector(modeChanged(_:))

        let intensity = NSSlider(value: preferences.intensityMultiplier, minValue: 0.1, maxValue: 2.0, target: self, action: #selector(intensityChanged(_:)))

        let overlay = NSButton(checkboxWithTitle: "Enable overlay", target: self, action: #selector(overlayChanged(_:)))
        overlay.state = preferences.overlayEnabled ? .on : .off

        root.addArrangedSubview(title)
        root.addArrangedSubview(conditionLabel)
        root.addArrangedSubview(detailLabel)
        root.addArrangedSubview(sourceLabel)
        root.addArrangedSubview(effectLabel)
        root.addArrangedSubview(separator())
        root.addArrangedSubview(NSTextField(labelWithString: "Weather source / debug mode"))
        root.addArrangedSubview(mode)
        root.addArrangedSubview(NSTextField(labelWithString: "Intensity"))
        root.addArrangedSubview(intensity)
        root.addArrangedSubview(overlay)
        return root
    }

    func update(weatherState: WeatherState) {
        conditionLabel.stringValue = weatherState.dashboardCondition
        let temperature = weatherState.temperatureCelsius.map { "\(Int($0.rounded())) C" } ?? "Temperature --"
        let wind = "Wind \(Int(weatherState.windSpeedMetersPerSecond.rounded())) m/s at \(Int(weatherState.windDirectionDegrees.rounded())) deg"
        detailLabel.stringValue = "\(temperature)     \(wind)"

        sourceLabel.stringValue = preferences.debugMode == .live
            ? "Source: live weather"
            : "Source: \(preferences.debugMode.rawValue.capitalized) debug mode"

        if weatherState.precipitation == .none {
            effectLabel.stringValue = weatherState.isSunny
                ? "No precipitation effect right now. Use Rain, Snow, or Wind debug mode to preview collisions."
                : "No precipitation effect right now."
        } else {
            let percent = Int((weatherState.intensity * 100).rounded())
            effectLabel.stringValue = "\(weatherState.precipitation.displayName) effect active at \(percent)% intensity."
        }
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        let selected = sender.titleOfSelectedItem?.lowercased() ?? DebugWeatherMode.live.rawValue
        preferences.debugMode = DebugWeatherMode(rawValue: selected) ?? .live
        onChange?()
    }

    @objc private func intensityChanged(_ sender: NSSlider) {
        preferences.intensityMultiplier = sender.doubleValue
        onChange?()
    }

    @objc private func overlayChanged(_ sender: NSButton) {
        preferences.overlayEnabled = sender.state == .on
        onChange?()
    }
}
