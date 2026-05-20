import AppKit
import CoreGraphics
import Foundation

protocol WindowGeometryProvider {
    func currentObstacles() -> [WindowObstacle]
}

struct CoreGraphicsWindowGeometryProvider: WindowGeometryProvider {
    var currentProcessIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier
    var minimumWindowSize = CGSize(width: 80, height: 60)

    func currentObstacles() -> [WindowObstacle] {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let screens = NSScreen.screens.map(\.frame)
        return windowInfo.compactMap { dictionary in
            Self.makeObstacle(
                from: dictionary,
                screens: screens,
                currentProcessIdentifier: currentProcessIdentifier,
                minimumWindowSize: minimumWindowSize
            )
        }
    }

    static func makeObstacle(
        from dictionary: [String: Any],
        screens: [CGRect],
        currentProcessIdentifier: pid_t,
        minimumWindowSize: CGSize
    ) -> WindowObstacle? {
        guard
            let windowID = dictionary[kCGWindowNumber as String] as? UInt32,
            let layer = dictionary[kCGWindowLayer as String] as? Int,
            let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t,
            let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
            let boundsDictionary = dictionary[kCGWindowBounds as String] as? [String: Any],
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
        else {
            return nil
        }

        guard layer == 0 else { return nil }
        guard ownerPID != currentProcessIdentifier else { return nil }
        guard bounds.width >= minimumWindowSize.width, bounds.height >= minimumWindowSize.height else { return nil }
        guard !ownerName.localizedCaseInsensitiveContains("Dock") else { return nil }
        guard let screenFrame = nearestScreenFrame(for: bounds, screens: screens) else { return nil }

        return WindowObstacle(
            id: windowID,
            ownerName: ownerName,
            bounds: bounds,
            screenFrame: screenFrame
        )
    }

    static func nearestScreenFrame(for bounds: CGRect, screens: [CGRect]) -> CGRect? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let containing = screens.first(where: { $0.contains(center) }) {
            return containing
        }

        return screens.max { lhs, rhs in
            lhs.intersection(bounds).area < rhs.intersection(bounds).area
        }
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
