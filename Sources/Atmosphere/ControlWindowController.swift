import AppKit

@MainActor
final class ControlWindowController {
    private var window: NSWindow?
    private let button = NSButton()
    var onOpenDashboard: (() -> Void)?

    func show() {
        if window == nil {
            window = makeWindow()
        }

        update(weatherState: .debugRain)
        positionWindow()
        window?.orderFrontRegardless()
    }

    func update(weatherState: WeatherState) {
        let image = NSImage(systemSymbolName: weatherState.menuSymbolName, accessibilityDescription: weatherState.dashboardCondition)
        image?.isTemplate = true
        button.image = image
        button.title = " \(weatherState.dashboardCondition)"
        button.toolTip = "Open Atmosphere Dashboard - \(weatherState.statusSummary)"
        positionWindow()
    }

    private func makeWindow() -> NSWindow {
        let contentRect = CGRect(x: 0, y: 0, width: 168, height: 38)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = makeContentView(frame: contentRect)
        return window
    }

    private func makeContentView(frame: CGRect) -> NSView {
        let root = NSVisualEffectView(frame: frame)
        root.material = .hudWindow
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 12
        root.layer?.masksToBounds = true

        button.frame = root.bounds.insetBy(dx: 10, dy: 4)
        button.autoresizingMask = [.width, .height]
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.font = .systemFont(ofSize: 14, weight: .semibold)
        button.imagePosition = .imageLeading
        button.alignment = .center
        button.target = self
        button.action = #selector(openDashboard)
        root.addSubview(button)

        return root
    }

    private func positionWindow() {
        guard let window, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = CGPoint(
            x: visible.maxX - size.width - 18,
            y: visible.maxY - size.height - 18
        )
        window.setFrameOrigin(origin)
    }

    @objc private func openDashboard() {
        onOpenDashboard?()
    }
}
