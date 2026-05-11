import Testing
@testable import RunningOverlay

struct WeatherIconAssetTests {
    @Test func weatherConditionsResolveBundledSVGAssets() {
        for condition in WeatherCondition.allCases {
            #expect(IconAssetResolver.bundledSVGImage(name: condition.bundledSVGName) != nil)
        }
    }
}
