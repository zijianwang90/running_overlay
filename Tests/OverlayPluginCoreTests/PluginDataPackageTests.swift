import Foundation
import OverlayPluginCore
import Testing

struct PluginDataPackageTests {
    @Test func selfContainedPackageHasDeterministicEncoding() throws {
        let package = fixture()
        let bytes = try PluginDataPackageCodec.encode(package)
        #expect(bytes == (try PluginDataPackageCodec.encode(package)))
        #expect(try PluginDataPackageCodec.decode(bytes) == package)
    }

    @Test func futureVersionFailsBeforePayloadDecoding() {
        #expect(throws: PluginCoreError.unsupportedPackageVersion(99)) {
            try PluginDataPackageCodec.decode(Data(#"{"schemaVersion":99}"#.utf8))
        }
    }

    @Test func changedPayloadCannotReuseItsDigest() throws {
        var json = try #require(JSONSerialization.jsonObject(with: PluginDataPackageCodec.encode(fixture())) as? [String: Any])
        var activity = try #require(json["activity"] as? [String: Any])
        activity["data"] = Data("changed".utf8).base64EncodedString()
        json["activity"] = activity
        #expect(throws: PluginCoreError.contentMismatch) {
            try PluginDataPackageCodec.decode(JSONSerialization.data(withJSONObject: json))
        }
    }

    @Test func duplicateIDsAndInvalidCanvasesAreRejected() {
        let package = fixture()
        let duplicate = PluginDataPackage(rendererVersion: "skia-1", canvasWidth: 1920, canvasHeight: 1080, activity: package.activity, templates: [package.templates[0], package.templates[0]])
        #expect(throws: PluginCoreError.self) { try PluginDataPackageCodec.encode(duplicate) }
        let invalid = PluginDataPackage(rendererVersion: "skia-1", canvasWidth: 0, canvasHeight: 9000, activity: package.activity, templates: package.templates)
        #expect(throws: PluginCoreError.self) { try PluginDataPackageCodec.encode(invalid) }
    }

    @Test func noTemplatesAndEmptyResourceAreRejected() {
        let package = fixture()
        let noTemplates = PluginDataPackage(rendererVersion: "skia-1", canvasWidth: 10, canvasHeight: 10, activity: package.activity, templates: [])
        #expect(throws: PluginCoreError.self) { try PluginDataPackageCodec.encode(noTemplates) }
        let empty = PluginDataPackage(rendererVersion: "skia-1", canvasWidth: 10, canvasHeight: 10, activity: PluginPackageResource(schemaVersion: 1, data: Data()), templates: package.templates)
        #expect(throws: PluginCoreError.self) { try PluginDataPackageCodec.encode(empty) }
    }

    private func fixture() -> PluginDataPackage {
        PluginDataPackage(
            rendererVersion: "skia-1", canvasWidth: 1920, canvasHeight: 1080,
            activity: PluginPackageResource(schemaVersion: 1, data: Data(#"{"duration":10}"#.utf8)),
            templates: [PluginPackageTemplate(id: UUID(), name: "Metrics", resource: PluginPackageResource(schemaVersion: 2, data: Data("{}".utf8)))]
        )
    }
}
