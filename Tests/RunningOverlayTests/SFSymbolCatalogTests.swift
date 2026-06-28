import Testing
@testable import RunningOverlay

@MainActor
struct SFSymbolCatalogTests {
    @Test func bundledCatalogLoadsFullSymbolNameList() {
        #expect(SFSymbolCatalog.allNames.count > 8_000)
        #expect(SFSymbolCatalog.allNames.contains("apple.logo"))
        #expect(SFSymbolCatalog.allNames.contains("square.and.arrow.up"))
    }

    @Test func catalogSearchIsCaseInsensitive() {
        let lower = SFSymbolCatalog.search("heart")
        let upper = SFSymbolCatalog.search("HEART")

        #expect(lower.contains("heart"))
        #expect(upper.contains("heart"))
        #expect(lower.contains("heart.fill"))
        #expect(upper.contains("heart.fill"))
    }

    @Test func emptySearchStartsWithSportRelevantSymbols() {
        let topDefaults = SFSymbolCatalog.search("", limit: 16)
        let defaults = SFSymbolCatalog.search("", limit: 32)

        #expect(topDefaults.first == "figure.run")
        #expect(topDefaults.contains("heart"))
        #expect(topDefaults.contains("speedometer"))
        #expect(defaults.contains("heart"))
        #expect(defaults.contains("figure.outdoor.cycle"))
    }

    @Test func searchStillUsesFullCatalog() {
        let results = SFSymbolCatalog.search("apple.logo", limit: 10)

        #expect(results.contains("apple.logo"))
    }

    @Test func searchReturnsRenderableSymbolsOnly() {
        let results = SFSymbolCatalog.search("figure", limit: 20)

        #expect(results.isEmpty == false)
        #expect(results.allSatisfy(SFSymbolCatalog.isRenderable))
    }

    @Test func numericDefaultsAreIncludedInCatalog() {
        let missing = OverlayElementType.allCases
            .filter(\.isNumericOverlay)
            .map(\.defaultNumericIconSystemName)
            .filter { SFSymbolCatalog.allNames.contains($0) == false }

        #expect(missing.isEmpty, "Missing numeric default SF Symbols: \(missing.joined(separator: ", "))")
    }
}
