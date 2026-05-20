import Foundation

protocol WeatherProvider {
    func currentWeather(latitude: Double, longitude: Double) async throws -> WeatherState
}

enum WeatherProviderError: Error {
    case malformedResponse
}

final class OpenMeteoWeatherProvider: WeatherProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func currentWeather(latitude: Double, longitude: Double) async throws -> WeatherState {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,precipitation,rain,snowfall,weather_code,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "wind_speed_unit", value: "ms"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw WeatherProviderError.malformedResponse
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return WeatherMapper.map(
            weatherCode: response.current.weatherCode,
            precipitationMM: response.current.precipitation,
            rainMM: response.current.rain,
            snowfallCM: response.current.snowfall,
            windSpeedMetersPerSecond: response.current.windSpeed,
            windDirectionDegrees: response.current.windDirection,
            temperatureCelsius: response.current.temperature
        )
    }
}

struct WeatherMapper {
    static func map(
        weatherCode: Int,
        precipitationMM: Double,
        rainMM: Double,
        snowfallCM: Double,
        windSpeedMetersPerSecond: Double,
        windDirectionDegrees: Double,
        temperatureCelsius: Double?
    ) -> WeatherState {
        let snowCodes: Set<Int> = [71, 73, 75, 77, 85, 86]
        let rainCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
        let clearCodes: Set<Int> = [0, 1]

        let precipitation: PrecipitationKind
        if snowCodes.contains(weatherCode) || snowfallCM > 0 {
            precipitation = .snow
        } else if rainCodes.contains(weatherCode) || rainMM > 0 || precipitationMM > 0 {
            precipitation = .rain
        } else {
            precipitation = .none
        }

        let rawIntensity: Double
        switch precipitation {
        case .none:
            rawIntensity = 0
        case .rain:
            rawIntensity = max(precipitationMM, rainMM) / 4.0
        case .snow:
            rawIntensity = max(snowfallCM, precipitationMM) / 3.0
        }

        return WeatherState(
            precipitation: precipitation,
            intensity: min(max(rawIntensity, precipitation == .none ? 0 : 0.25), 1.0),
            windSpeedMetersPerSecond: windSpeedMetersPerSecond,
            windDirectionDegrees: windDirectionDegrees,
            isSunny: clearCodes.contains(weatherCode),
            temperatureCelsius: temperatureCelsius
        )
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: Current

    struct Current: Decodable {
        let temperature: Double?
        let precipitation: Double
        let rain: Double
        let snowfall: Double
        let weatherCode: Int
        let windSpeed: Double
        let windDirection: Double

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case precipitation
            case rain
            case snowfall
            case weatherCode = "weather_code"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
        }
    }
}
