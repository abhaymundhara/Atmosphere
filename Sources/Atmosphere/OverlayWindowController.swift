import AppKit

@MainActor
final class OverlayWindowController {
    private let simulationEngine: SimulationEngine
    private var windows: [NSWindow] = []
    private var overlayViews: [WeatherOverlayView] = []
    private var isVisible = false

    init(simulationEngine: SimulationEngine) {
        self.simulationEngine = simulationEngine
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show() {
        if windows.isEmpty {
            rebuildWindows()
        }
        windows.forEach { $0.orderFront(nil) }
        overlayViews.forEach { $0.startAnimating() }
        isVisible = true
    }

    func hide() {
        overlayViews.forEach { $0.stopAnimating() }
        windows.forEach { $0.orderOut(nil) }
        isVisible = false
    }

    func update(weatherState: WeatherState, obstacles: [WindowObstacle]) {
        guard isVisible else { return }
        simulationEngine.update(weatherState: weatherState)
        simulationEngine.update(obstacles: obstacles)
        overlayViews.forEach { view in
            view.weatherState = weatherState
            view.obstacles = obstacles
                .filter { view.frameInScreenCoordinates.intersects($0.bounds) }
                .prefix(24)
                .map { $0 }
        }
    }

    @objc private func screenParametersDidChange() {
        guard isVisible else {
            windows.forEach { $0.close() }
            windows.removeAll()
            overlayViews.removeAll()
            return
        }
        rebuildWindows()
    }

    private func rebuildWindows() {
        overlayViews.forEach { $0.stopAnimating() }
        windows.forEach { $0.close() }
        windows.removeAll()
        overlayViews.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.animationBehavior = .none
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

            let view = WeatherOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size), screenFrame: screen.frame)
            window.contentView = view
            window.orderFront(nil)
            windows.append(window)
            overlayViews.append(view)
        }
    }
}

final class WeatherOverlayView: NSView {
    private enum VisualKind {
        case rain
        case snow
        case splash
        case runoff
        case wind
        case settledSnow
    }

    private struct WeatherVisual {
        var kind: VisualKind
        var position: CGPoint
        var velocity: CGVector
        var life: TimeInterval
        var maxLife: TimeInterval
        var size: CGFloat
        var phase: CGFloat
    }

    let frameInScreenCoordinates: CGRect
    var weatherState: WeatherState = .clear
    var obstacles: [WindowObstacle] = []

    private var visuals: [WeatherVisual] = []
    private var animationTimer: Timer?
    private var lastUpdate = Date()
    private let maximumVisuals = 120

    init(frame: CGRect, screenFrame: CGRect) {
        self.frameInScreenCoordinates = screenFrame
        super.init(frame: frame)
        wantsLayer = false
        postsFrameChangedNotifications = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool {
        false
    }

    func startAnimating() {
        guard animationTimer == nil else { return }
        lastUpdate = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        visuals.removeAll()
        needsDisplay = true
    }

    private func tick() {
        let now = Date()
        let delta = min(now.timeIntervalSince(lastUpdate), 1.0 / 12.0)
        lastUpdate = now
        updateVisuals(deltaTime: delta)
        needsDisplay = true
    }

    private func updateVisuals(deltaTime: TimeInterval) {
        spawnVisuals(deltaTime: deltaTime)

        visuals = visuals.flatMap { visual -> [WeatherVisual] in
            var visual = visual
            visual.life -= deltaTime

            switch visual.kind {
            case .snow:
                visual.position.x += CGFloat(sin(Double(CGFloat(visual.life) * 2.0 + visual.phase))) * 8 * CGFloat(deltaTime)
            case .wind:
                visual.position.y += CGFloat(sin(Double(CGFloat(visual.life) * 5.5 + visual.phase))) * 14 * CGFloat(deltaTime)
            default:
                break
            }

            visual.position.x += visual.velocity.dx * CGFloat(deltaTime)
            visual.position.y += visual.velocity.dy * CGFloat(deltaTime)

            guard visual.life > 0, frameInScreenCoordinates.insetBy(dx: -180, dy: -180).contains(visual.position) else {
                return []
            }

            switch visual.kind {
            case .rain:
                if let obstacle = topCollision(for: visual.position) {
                    return splashVisuals(at: visual.position, obstacle: obstacle)
                }
            case .snow:
                if let obstacle = topCollision(for: visual.position) {
                    var settled = visual
                    settled.kind = .settledSnow
                    settled.position.y = obstacle.bounds.minY + 1
                    settled.velocity = .zero
                    settled.life = 4.5
                    settled.maxLife = 4.5
                    settled.size = CGFloat.random(in: 2.0...4.0)
                    return [settled]
                }
            case .splash, .runoff, .wind, .settledSnow:
                break
            }

            return [visual]
        }

        if visuals.count > maximumVisuals {
            visuals.removeFirst(visuals.count - maximumVisuals)
        }
    }

    private func spawnVisuals(deltaTime: TimeInterval) {
        guard visuals.count < maximumVisuals else { return }

        let windSpeed = CGFloat(weatherState.windSpeedMetersPerSecond)
        let windDirection = CGFloat((weatherState.windDirectionDegrees - 90) * .pi / 180)
        let windX = CGFloat(cos(Double(windDirection))) * windSpeed
        let intensity = CGFloat(max(weatherState.intensity, weatherState.precipitation == .none ? 0 : 0.25))

        switch weatherState.precipitation {
        case .rain:
            let spawnCount = min(maximumVisuals - visuals.count, max(1, Int((intensity * 14 * deltaTime).rounded(.up))))
            for _ in 0..<spawnCount {
                visuals.append(WeatherVisual(
                    kind: .rain,
                    position: CGPoint(
                        x: CGFloat.random(in: frameInScreenCoordinates.minX...frameInScreenCoordinates.maxX),
                        y: frameInScreenCoordinates.minY - CGFloat.random(in: 10...80)
                    ),
                    velocity: CGVector(dx: windX * 20, dy: CGFloat.random(in: 520...760)),
                    life: 2.2,
                    maxLife: 2.2,
                    size: CGFloat.random(in: 14...24),
                    phase: CGFloat.random(in: 0...(2 * .pi))
                ))
            }
        case .snow:
            let spawnCount = min(maximumVisuals - visuals.count, max(1, Int((intensity * 7 * deltaTime).rounded(.up))))
            for _ in 0..<spawnCount {
                visuals.append(WeatherVisual(
                    kind: .snow,
                    position: CGPoint(
                        x: CGFloat.random(in: frameInScreenCoordinates.minX...frameInScreenCoordinates.maxX),
                        y: frameInScreenCoordinates.minY - CGFloat.random(in: 10...80)
                    ),
                    velocity: CGVector(dx: windX * 5 + CGFloat.random(in: -18...18), dy: CGFloat.random(in: 48...110)),
                    life: 7,
                    maxLife: 7,
                    size: CGFloat.random(in: 2.0...4.4),
                    phase: CGFloat.random(in: 0...(2 * .pi))
                ))
            }
        case .none:
            break
        }

        if windSpeed >= 7 {
            let gustCount = min(maximumVisuals - visuals.count, Int((min(windSpeed / 16, 1.0) * 7 * deltaTime).rounded(.up)))
            for _ in 0..<gustCount {
                visuals.append(WeatherVisual(
                    kind: .wind,
                    position: CGPoint(
                        x: windX >= 0 ? frameInScreenCoordinates.minX - 120 : frameInScreenCoordinates.maxX + 120,
                        y: CGFloat.random(in: frameInScreenCoordinates.minY...(frameInScreenCoordinates.maxY - 120))
                    ),
                    velocity: CGVector(dx: (windX >= 0 ? 1 : -1) * CGFloat.random(in: 260...420), dy: CGFloat.random(in: -20...20)),
                    life: 2.4,
                    maxLife: 2.4,
                    size: CGFloat.random(in: 42...120),
                    phase: CGFloat.random(in: 0...(2 * .pi))
                ))
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.clear(bounds)
        drawSun(in: context)
        for visual in visuals {
            draw(visual, in: context)
        }
    }

    private func drawSun(in context: CGContext) {
        guard weatherState.isSunny, weatherState.precipitation == .none else { return }

        let origin = CGPoint(x: bounds.maxX - 120, y: bounds.minY + 70)
        for index in 0..<7 {
            let progress = CGFloat(index) / 6
            let angle = CGFloat.pi * (0.72 + progress * 0.28)
            let length = CGFloat(420 + index * 34)
            let alpha = CGFloat(0.045 + progress * 0.012)
            context.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.32, alpha: alpha).cgColor)
            context.setLineWidth(CGFloat(22 - min(index, 5) * 2))
            context.setLineCap(.round)
            context.move(to: origin)
            context.addLine(to: CGPoint(
                x: origin.x + CGFloat(cos(Double(angle))) * length,
                y: origin.y + CGFloat(sin(Double(angle))) * length
            ))
            context.strokePath()
        }
    }

    private func draw(_ visual: WeatherVisual, in context: CGContext) {
        let local = screenToView(visual.position)
        let alpha = CGFloat(max(0.08, min(1.0, visual.life / visual.maxLife)))
        context.saveGState()
        context.translateBy(x: local.x, y: local.y)

        switch visual.kind {
        case .rain:
            let angle = -CGFloat(atan2(Double(visual.velocity.dx), Double(visual.velocity.dy)))
            context.rotate(by: angle)
            context.setFillColor(NSColor(calibratedRed: 0.62, green: 0.82, blue: 1.0, alpha: 0.42 * alpha).cgColor)
            context.fill(CGRect(x: -0.7, y: -visual.size * 0.5, width: 1.4, height: visual.size))
        case .snow:
            context.rotate(by: visual.phase + CGFloat(visual.maxLife - visual.life) * 0.8)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.72 * alpha).cgColor)
            context.setLineWidth(0.7)
            for spoke in 0..<6 {
                let angle = CGFloat(spoke) * CGFloat.pi / 3
                context.move(to: .zero)
                context.addLine(to: CGPoint(x: CGFloat(cos(Double(angle))) * visual.size, y: CGFloat(sin(Double(angle))) * visual.size))
            }
            context.strokePath()
        case .splash:
            context.setFillColor(NSColor(calibratedRed: 0.76, green: 0.9, blue: 1.0, alpha: 0.46 * alpha).cgColor)
            context.fillEllipse(in: CGRect(x: -visual.size, y: -visual.size, width: visual.size * 2, height: visual.size * 2))
        case .runoff:
            context.setFillColor(NSColor(calibratedRed: 0.55, green: 0.8, blue: 1.0, alpha: 0.34 * alpha).cgColor)
            context.fill(CGRect(x: -0.8, y: -visual.size * 0.5, width: 1.6, height: visual.size))
        case .wind:
            context.rotate(by: CGFloat(atan2(Double(visual.velocity.dy), Double(visual.velocity.dx))))
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.18 * alpha).cgColor)
            context.setLineWidth(1.1)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: -visual.size * 0.5, y: 0))
            context.addCurve(
                to: CGPoint(x: visual.size * 0.5, y: 0),
                control1: CGPoint(x: -visual.size * 0.18, y: CGFloat(sin(Double(visual.phase))) * 8),
                control2: CGPoint(x: visual.size * 0.18, y: CGFloat(cos(Double(visual.phase))) * 8)
            )
            context.strokePath()
        case .settledSnow:
            context.setFillColor(NSColor.white.withAlphaComponent(0.42 * alpha).cgColor)
            context.fillEllipse(in: CGRect(x: -visual.size, y: -visual.size * 0.35, width: visual.size * 2.2, height: visual.size * 0.7))
        }

        context.restoreGState()
    }

    private func topCollision(for point: CGPoint) -> WindowObstacle? {
        obstacles.first { obstacle in
            CGRect(x: obstacle.bounds.minX, y: obstacle.bounds.minY - 4, width: obstacle.bounds.width, height: 14).contains(point)
        }
    }

    private func splashVisuals(at point: CGPoint, obstacle: WindowObstacle) -> [WeatherVisual] {
        [
            WeatherVisual(kind: .splash, position: point, velocity: CGVector(dx: -55, dy: -45), life: 0.22, maxLife: 0.22, size: 1.8, phase: 0),
            WeatherVisual(kind: .splash, position: point, velocity: CGVector(dx: 55, dy: -45), life: 0.22, maxLife: 0.22, size: 1.8, phase: 0),
            WeatherVisual(kind: .runoff, position: CGPoint(x: point.x, y: obstacle.bounds.minY + 4), velocity: CGVector(dx: 0, dy: 90), life: 0.75, maxLife: 0.75, size: 12, phase: 0)
        ]
    }

    private func screenToView(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - frameInScreenCoordinates.minX,
            y: bounds.height - (point.y - frameInScreenCoordinates.minY)
        )
    }
}
