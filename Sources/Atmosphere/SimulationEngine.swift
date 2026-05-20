import CoreGraphics
import Foundation

struct Particle: Equatable {
    enum Kind {
        case rain
        case snow
        case splash
        case runoff
    }

    var kind: Kind
    var position: CGPoint
    var velocity: CGVector
    var life: TimeInterval
}

enum CollisionResult: Equatable {
    case none
    case top(WindowObstacle)
    case side(WindowObstacle)
}

final class SimulationEngine {
    private(set) var weatherState: WeatherState = .clear
    private(set) var obstacles: [WindowObstacle] = []
    private(set) var particles: [Particle] = []

    func update(weatherState: WeatherState) {
        self.weatherState = weatherState
    }

    func update(obstacles: [WindowObstacle]) {
        self.obstacles = obstacles
    }

    func step(in bounds: CGRect, deltaTime: TimeInterval) {
        spawnParticles(in: bounds, deltaTime: deltaTime)

        particles = particles.flatMap { particle -> [Particle] in
            var particle = particle
            particle.position.x += particle.velocity.dx * deltaTime
            particle.position.y += particle.velocity.dy * deltaTime
            particle.life -= deltaTime

            guard particle.life > 0, bounds.insetBy(dx: -120, dy: -120).contains(particle.position) else {
                return []
            }

            switch classifyCollision(for: particle, obstacles: obstacles) {
            case .none:
                return [particle]
            case .top(let obstacle):
                return collisionParticles(for: particle, obstacle: obstacle)
            case .side:
                particle.velocity.dy = max(50, particle.velocity.dy * 0.35)
                particle.velocity.dx *= 0.25
                particle.kind = .runoff
                return [particle]
            }
        }
    }

    func classifyCollision(for particle: Particle, obstacles: [WindowObstacle]) -> CollisionResult {
        for obstacle in obstacles where obstacle.bounds.insetBy(dx: 0, dy: -4).contains(particle.position) {
            let topBand = CGRect(x: obstacle.bounds.minX, y: obstacle.bounds.minY - 3, width: obstacle.bounds.width, height: 12)
            if topBand.contains(particle.position), particle.velocity.dy > 0 {
                return .top(obstacle)
            }

            let sideBandWidth: CGFloat = 8
            let leftSide = CGRect(x: obstacle.bounds.minX - sideBandWidth, y: obstacle.bounds.minY, width: sideBandWidth * 2, height: obstacle.bounds.height)
            let rightSide = CGRect(x: obstacle.bounds.maxX - sideBandWidth, y: obstacle.bounds.minY, width: sideBandWidth * 2, height: obstacle.bounds.height)
            if leftSide.contains(particle.position) || rightSide.contains(particle.position) {
                return .side(obstacle)
            }
        }

        return .none
    }

    private func spawnParticles(in bounds: CGRect, deltaTime: TimeInterval) {
        let count = Int((weatherState.intensity * 120 * deltaTime).rounded())
        guard count > 0 else { return }

        for _ in 0..<count {
            let x = CGFloat.random(in: bounds.minX...bounds.maxX)
            let wind = CGFloat(weatherState.windSpeedMetersPerSecond)
            switch weatherState.precipitation {
            case .none:
                continue
            case .rain:
                particles.append(Particle(
                    kind: .rain,
                    position: CGPoint(x: x, y: bounds.minY - 12),
                    velocity: CGVector(dx: wind * 24, dy: CGFloat.random(in: 720...980)),
                    life: 5
                ))
            case .snow:
                particles.append(Particle(
                    kind: .snow,
                    position: CGPoint(x: x, y: bounds.minY - 12),
                    velocity: CGVector(dx: wind * 6 + CGFloat.random(in: -22...22), dy: CGFloat.random(in: 70...145)),
                    life: 12
                ))
            }
        }
    }

    private func collisionParticles(for particle: Particle, obstacle: WindowObstacle) -> [Particle] {
        switch particle.kind {
        case .snow:
            return [Particle(
                kind: .snow,
                position: CGPoint(x: particle.position.x, y: obstacle.bounds.minY + 1),
                velocity: .zero,
                life: 8
            )]
        case .rain, .splash, .runoff:
            let splashA = Particle(
                kind: .splash,
                position: particle.position,
                velocity: CGVector(dx: CGFloat.random(in: -110 ... -40), dy: CGFloat.random(in: -100 ... -30)),
                life: 0.35
            )
            let splashB = Particle(
                kind: .splash,
                position: particle.position,
                velocity: CGVector(dx: CGFloat.random(in: 40 ... 110), dy: CGFloat.random(in: -100 ... -30)),
                life: 0.35
            )
            let runoff = Particle(
                kind: .runoff,
                position: CGPoint(x: particle.position.x, y: obstacle.bounds.minY + 4),
                velocity: CGVector(dx: 0, dy: 160),
                life: 1.6
            )
            return [splashA, splashB, runoff]
        }
    }
}
