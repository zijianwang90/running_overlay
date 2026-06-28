import AppKit
import Testing
@testable import RunningOverlay

struct OverlayFontResolverTests {
    @Test func digitalWatchPresetUsesAvailableSystemFont() throws {
        let font = try #require(NSFont(name: PresetFontName.digitalWatch, size: 40))
        #expect(font.isFixedPitch)
        #expect(OverlayTextPreset.digitalWatch.recommendedTokens?.fontName == PresetFontName.digitalWatch)
    }

    @Test func resolvesJetBrainsMonoWeightedFacesWhenInstalled() {
        guard NSFontManager.shared.availableMembers(ofFontFamily: "JetBrains Mono") != nil else {
            return
        }

        #expect(OverlayFontResolver.appKitFont(family: "JetBrains Mono", size: 34, weight: .regular).fontName == "JetBrainsMono-Regular")
        #expect(OverlayFontResolver.appKitFont(family: "JetBrains Mono", size: 34, weight: .medium).fontName == "JetBrainsMono-Medium")
        #expect(OverlayFontResolver.appKitFont(family: "JetBrains Mono", size: 34, weight: .semibold).fontName == "JetBrainsMono-SemiBold")
        #expect(OverlayFontResolver.appKitFont(family: "JetBrains Mono", size: 34, weight: .bold).fontName == "JetBrainsMono-Bold")
    }
}
