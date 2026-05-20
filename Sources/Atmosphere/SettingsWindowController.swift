import AppKit

@MainActor
final class SettingsWindowController {
    private let preferences: PreferencesStore
    private var window: NSWindow?
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
            contentRect: CGRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Atmosphere"
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
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let title = NSTextField(labelWithString: "Atmosphere")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let mode = NSPopUpButton()
        DebugWeatherMode.allCases.forEach { mode.addItem(withTitle: $0.rawValue.capitalized) }
        mode.selectItem(withTitle: preferences.debugMode.rawValue.capitalized)
        mode.target = self
        mode.action = #selector(modeChanged(_:))

        let intensity = NSSlider(value: preferences.intensityMultiplier, minValue: 0.1, maxValue: 2.0, target: self, action: #selector(intensityChanged(_:)))

        let overlay = NSButton(checkboxWithTitle: "Enable overlay", target: self, action: #selector(overlayChanged(_:)))
        overlay.state = preferences.overlayEnabled ? .on : .off

        root.addArrangedSubview(title)
        root.addArrangedSubview(NSTextField(labelWithString: "Weather source / debug mode"))
        root.addArrangedSubview(mode)
        root.addArrangedSubview(NSTextField(labelWithString: "Intensity"))
        root.addArrangedSubview(intensity)
        root.addArrangedSubview(overlay)
        return root
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
