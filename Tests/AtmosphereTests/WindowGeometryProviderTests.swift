import CoreGraphics
import XCTest
@testable import Atmosphere

final class WindowGeometryProviderTests: XCTestCase {
    func testFiltersNonNormalLayers() {
        let obstacle = CoreGraphicsWindowGeometryProvider.makeObstacle(
            from: dictionary(layer: 25),
            screens: [CGRect(x: 0, y: 0, width: 1440, height: 900)],
            currentProcessIdentifier: 99,
            minimumWindowSize: CGSize(width: 80, height: 60)
        )

        XCTAssertNil(obstacle)
    }

    func testFiltersCurrentProcessWindows() {
        let obstacle = CoreGraphicsWindowGeometryProvider.makeObstacle(
            from: dictionary(ownerPID: 42),
            screens: [CGRect(x: 0, y: 0, width: 1440, height: 900)],
            currentProcessIdentifier: 42,
            minimumWindowSize: CGSize(width: 80, height: 60)
        )

        XCTAssertNil(obstacle)
    }

    func testBuildsObstacleForVisibleAppWindow() throws {
        let obstacle = try XCTUnwrap(CoreGraphicsWindowGeometryProvider.makeObstacle(
            from: dictionary(),
            screens: [CGRect(x: 0, y: 0, width: 1440, height: 900)],
            currentProcessIdentifier: 99,
            minimumWindowSize: CGSize(width: 80, height: 60)
        ))

        XCTAssertEqual(obstacle.id, 12)
        XCTAssertEqual(obstacle.ownerName, "Finder")
        XCTAssertEqual(obstacle.bounds, CGRect(x: 100, y: 120, width: 500, height: 300))
    }

    func testNearestScreenUsesLargestIntersection() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let bounds = CGRect(x: 900, y: 100, width: 300, height: 300)

        XCTAssertEqual(CoreGraphicsWindowGeometryProvider.nearestScreenFrame(for: bounds, screens: [left, right]), right)
    }

    private func dictionary(
        layer: Int = 0,
        ownerPID: pid_t = 42,
        ownerName: String = "Finder"
    ) -> [String: Any] {
        [
            kCGWindowNumber as String: UInt32(12),
            kCGWindowLayer as String: layer,
            kCGWindowOwnerPID as String: ownerPID,
            kCGWindowOwnerName as String: ownerName,
            kCGWindowBounds as String: [
                "X": 100,
                "Y": 120,
                "Width": 500,
                "Height": 300
            ]
        ]
    }
}
