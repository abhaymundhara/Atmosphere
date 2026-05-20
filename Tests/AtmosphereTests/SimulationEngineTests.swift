import CoreGraphics
import XCTest
@testable import Atmosphere

final class SimulationEngineTests: XCTestCase {
    func testClassifiesTopEdgeCollision() {
        let engine = SimulationEngine()
        let obstacle = WindowObstacle(
            id: 1,
            ownerName: "Test",
            bounds: CGRect(x: 100, y: 100, width: 400, height: 300),
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        let particle = Particle(kind: .rain, position: CGPoint(x: 200, y: 103), velocity: CGVector(dx: 0, dy: 800), life: 1)

        XCTAssertEqual(engine.classifyCollision(for: particle, obstacles: [obstacle]), .top(obstacle))
    }

    func testClassifiesSideCollision() {
        let engine = SimulationEngine()
        let obstacle = WindowObstacle(
            id: 1,
            ownerName: "Test",
            bounds: CGRect(x: 100, y: 100, width: 400, height: 300),
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        let particle = Particle(kind: .rain, position: CGPoint(x: 101, y: 180), velocity: CGVector(dx: 0, dy: 200), life: 1)

        XCTAssertEqual(engine.classifyCollision(for: particle, obstacles: [obstacle]), .side(obstacle))
    }

    func testNoCollisionOutsideObstacle() {
        let engine = SimulationEngine()
        let obstacle = WindowObstacle(
            id: 1,
            ownerName: "Test",
            bounds: CGRect(x: 100, y: 100, width: 400, height: 300),
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        let particle = Particle(kind: .rain, position: CGPoint(x: 50, y: 50), velocity: CGVector(dx: 0, dy: 200), life: 1)

        XCTAssertEqual(engine.classifyCollision(for: particle, obstacles: [obstacle]), .none)
    }
}
