import Testing
@testable import RunningOverlay

struct WeatherIconAssetTests {
    @Test func weatherConditionsResolveBundledImageAssets() {
        for condition in WeatherCondition.allCases {
            #expect(IconAssetResolver.bundledImage(name: condition.bundledImageName) != nil)
        }
    }
}
