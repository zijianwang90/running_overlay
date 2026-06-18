import AppKit
import Testing
@testable import RunningOverlay

struct OverlayFontResolverTests {
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
