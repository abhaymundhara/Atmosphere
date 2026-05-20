import AppKit
import SpriteKit

@MainActor
final class OverlayWindowController {
    private let simulationEngine: SimulationEngine
    private var windows: [NSWindow] = []
    private var scenes: [AtmosphereScene] = []

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
        rebuildWindows()
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
    }

    func update(weatherState: WeatherState, obstacles: [WindowObstacle]) {
        simulationEngine.update(weatherState: weatherState)
        simulationEngine.update(obstacles: obstacles)
        scenes.forEach { scene in
            scene.weatherState = weatherState
            scene.obstacles = obstacles.filter { scene.frameInScreenCoordinates.intersects($0.bounds) }
        }
    }

    @objc private func screenParametersDidChange() {
        rebuildWindows()
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
        scenes.removeAll()

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
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

            let view = SKView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.allowsTransparency = true
            view.ignoresSiblingOrder = true
            view.shouldCullNonVisibleNodes = true
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor

            let scene = AtmosphereScene(size: screen.frame.size, screenFrame: screen.frame, simulationEngine: simulationEngine)
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            view.presentScene(scene)

            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
            scenes.append(scene)
        }
    }
}

final class AtmosphereScene: SKScene {
    let frameInScreenCoordinates: CGRect
    private let simulationEngine: SimulationEngine
    private var lastUpdateTime: TimeInterval?
    private var particleNodes: [ObjectIdentifier: SKShapeNode] = [:]
    private let sunNode = SKShapeNode(rect: .zero)

    var weatherState: WeatherState = .clear
    var obstacles: [WindowObstacle] = []

    init(size: CGSize, screenFrame: CGRect, simulationEngine: SimulationEngine) {
        self.frameInScreenCoordinates = screenFrame
        self.simulationEngine = simulationEngine
        super.init(size: size)
        anchorPoint = CGPoint(x: 0, y: 1)
        setupSunNode()
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = min(currentTime - (lastUpdateTime ?? currentTime), 1.0 / 20.0)
        lastUpdateTime = currentTime

        simulationEngine.step(in: frameInScreenCoordinates, deltaTime: delta)
        renderParticles()
        renderSun()
    }

    private func setupSunNode() {
        sunNode.fillColor = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.28, alpha: 0.08)
        sunNode.strokeColor = .clear
        sunNode.blendMode = .add
        addChild(sunNode)
    }

    private func renderParticles() {
        removeChildren(in: children.filter { $0.name == "particle" })

        for particle in simulationEngine.particles where frameInScreenCoordinates.insetBy(dx: -80, dy: -80).contains(particle.position) {
            let local = screenToScene(particle.position)
            let node: SKShapeNode
            switch particle.kind {
            case .rain:
                node = SKShapeNode(rectOf: CGSize(width: 1.5, height: 18), cornerRadius: 0.75)
                node.fillColor = NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 0.52)
                node.strokeColor = .clear
                node.zRotation = -0.18
            case .snow:
                node = SKShapeNode(circleOfRadius: 2.4)
                node.fillColor = NSColor.white.withAlphaComponent(0.78)
                node.strokeColor = .clear
            case .splash:
                node = SKShapeNode(circleOfRadius: 1.7)
                node.fillColor = NSColor(calibratedRed: 0.7, green: 0.9, blue: 1.0, alpha: 0.5)
                node.strokeColor = .clear
            case .runoff:
                node = SKShapeNode(rectOf: CGSize(width: 1.2, height: 14), cornerRadius: 0.6)
                node.fillColor = NSColor(calibratedRed: 0.6, green: 0.82, blue: 1.0, alpha: 0.38)
                node.strokeColor = .clear
            }
            node.name = "particle"
            node.position = local
            node.blendMode = .alpha
            addChild(node)
        }
    }

    private func renderSun() {
        sunNode.isHidden = !weatherState.isSunny
        guard weatherState.isSunny else { return }

        sunNode.path = CGPath(ellipseIn: CGRect(x: size.width - 280, y: -220, width: 520, height: 520), transform: nil)
        sunNode.alpha = 0.7 + 0.2 * sin(CACurrentMediaTime() * 0.6)
    }

    private func screenToScene(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - frameInScreenCoordinates.minX,
            y: -(point.y - frameInScreenCoordinates.minY)
        )
    }
}
