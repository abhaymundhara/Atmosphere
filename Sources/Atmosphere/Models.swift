import CoreGraphics
import Foundation

enum PrecipitationKind: Equatable {
    case none
    case rain
    case snow

    var displayName: String {
        switch self {
        case .none:
            return "Clear"
        case .rain:
            return "Rain"
        case .snow:
            return "Snow"
        }
    }
}

struct WeatherState: Equatable {
    var precipitation: PrecipitationKind
    var intensity: Double
    var windSpeedMetersPerSecond: Double
    var windDirectionDegrees: Double
    var isSunny: Bool
    var temperatureCelsius: Double?

    var dashboardCondition: String {
        if precipitation != .none {
            return precipitation.displayName
        }

        return isSunny ? "Sunny" : "Cloudy"
    }

    var menuSymbolName: String {
        switch precipitation {
        case .rain:
            return windSpeedMetersPerSecond >= 12 ? "cloud.rain.fill" : "cloud.drizzle.fill"
        case .snow:
            return "snowflake"
        case .none:
            return isSunny ? "sun.max.fill" : "cloud.fill"
        }
    }

    var statusSummary: String {
        let temperature = temperatureCelsius.map { "\(Int($0.rounded())) C" } ?? "--"
        let wind = "\(Int(windSpeedMetersPerSecond.rounded())) m/s"
        return "\(dashboardCondition) | \(temperature) | Wind \(wind)"
    }

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
