import CoreGraphics
import Foundation

enum PrecipitationKind: Equatable {
    case none
    case rain
    case snow
}

struct WeatherState: Equatable {
    var precipitation: PrecipitationKind
    var intensity: Double
    var windSpeedMetersPerSecond: Double
    var windDirectionDegrees: Double
    var isSunny: Bool
    var temperatureCelsius: Double?

    static let clear = WeatherState(
        precipitation: .none,
        intensity: 0,
        windSpeedMetersPerSecond: 0,
        windDirectionDegrees: 0,
        isSunny: true,
        temperatureCelsius: nil
    )

    static let debugRain = WeatherState(
        precipitation: .rain,
        intensity: 0.7,
        windSpeedMetersPerSecond: 8,
        windDirectionDegrees: 105,
        isSunny: false,
        temperatureCelsius: 9
    )

    static let debugSnow = WeatherState(
        precipitation: .snow,
        intensity: 0.55,
        windSpeedMetersPerSecond: 3,
        windDirectionDegrees: 75,
        isSunny: false,
        temperatureCelsius: -1
    )
}

struct WindowObstacle: Equatable, Identifiable {
    let id: UInt32
    let ownerName: String
    let bounds: CGRect
    let screenFrame: CGRect

    var topEdge: CGRect {
        CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: 6)
    }
}

enum DebugWeatherMode: String, CaseIterable {
    case live
    case clear
    case rain
    case snow
    case wind

    var weatherState: WeatherState? {
        switch self {
        case .live:
            return nil
        case .clear:
            return .clear
        case .rain:
            return .debugRain
        case .snow:
            return .debugSnow
        case .wind:
            return WeatherState(
                precipitation: .rain,
                intensity: 0.35,
                windSpeedMetersPerSecond: 18,
                windDirectionDegrees: 115,
                isSunny: false,
                temperatureCelsius: 12
            )
        }
    }
}
