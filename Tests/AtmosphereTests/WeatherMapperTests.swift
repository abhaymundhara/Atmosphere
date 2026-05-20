import XCTest
@testable import Atmosphere

final class WeatherMapperTests: XCTestCase {
    func testMapsClearWeatherToSunnyNoPrecipitation() {
        let state = WeatherMapper.map(
            weatherCode: 0,
            precipitationMM: 0,
            rainMM: 0,
            snowfallCM: 0,
            windSpeedMetersPerSecond: 1,
            windDirectionDegrees: 20,
            temperatureCelsius: 18
        )

        XCTAssertEqual(state.precipitation, .none)
        XCTAssertEqual(state.intensity, 0)
        XCTAssertTrue(state.isSunny)
    }

    func testMapsRainCodeToRainWithMinimumVisibleIntensity() {
        let state = WeatherMapper.map(
            weatherCode: 61,
            precipitationMM: 0.1,
            rainMM: 0.1,
            snowfallCM: 0,
            windSpeedMetersPerSecond: 7,
            windDirectionDegrees: 120,
            temperatureCelsius: 9
        )

        XCTAssertEqual(state.precipitation, .rain)
        XCTAssertEqual(state.intensity, 0.25)
        XCTAssertFalse(state.isSunny)
    }

    func testMapsSnowfallToSnow() {
        let state = WeatherMapper.map(
            weatherCode: 3,
            precipitationMM: 0,
            rainMM: 0,
            snowfallCM: 2.5,
            windSpeedMetersPerSecond: 2,
            windDirectionDegrees: 80,
            temperatureCelsius: -2
        )

        XCTAssertEqual(state.precipitation, .snow)
        XCTAssertGreaterThan(state.intensity, 0.8)
    }
}
