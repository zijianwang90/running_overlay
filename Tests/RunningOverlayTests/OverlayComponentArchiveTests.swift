import Compression
import Foundation
import Testing
@testable import RunningOverlay

/// Builds small, exact ZIP archives in memory so the reader is exercised
/// without external tools or binary fixtures.
struct OverlayComponentArchiveTests {
    private struct Entry {
        var name: String
        var data: Data
        var deflated = false
        var flags: UInt16 = 0
        var methodOverride: UInt16?
        var declaredUncompressedSize: Int?
    }

    private func componentJSON(asset: String? = nil) -> Data {
        let node = asset.map {
            #"{ "type": "image", "frame": [0, 0, 100, 100], "asset": "\#($0)" }"#
        } ?? ##"{ "type": "rect", "frame": [0, 0, 10, 10], "fill": "#FF0000" }"##
        return Data("""
        {
          "spec": "ros.component/0.1",
          "id": "community.test.archive",
          "version": "1.0.0",
          "name": "Archive Card",
          "license": "MIT",
          "size": [100, 100],
          "nodes": [\(node)]
        }
        """.utf8)
    }

    @Test func storedArchiveExtractsDefinitionAndAssets() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON(asset: "assets/card.png")),
            Entry(name: "assets/card.png", data: png),
            Entry(name: "__MACOSX/._component.json", data: Data("junk".utf8))
        ])

        let package = try OverlayComponentLoader.load(archive: archive)
        #expect(package.definition.id == "community.test.archive")
        #expect(package.assets == ["assets/card.png"])
        #expect(package.assetData["assets/card.png"] == png)
    }

    @Test func deflatedArchiveExtractsAssets() throws {
        let payload = Data(repeating: 0x41, count: 512)
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON(asset: "assets/card.png"), deflated: true),
            Entry(name: "assets/card.png", data: payload, deflated: true)
        ])

        let package = try OverlayComponentLoader.load(archive: archive)
        #expect(package.assetData["assets/card.png"] == payload)
    }

    @Test func archiveFileImportsThroughLoadReference() throws {
        let png = Data([1, 2, 3, 4])
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON(asset: "assets/card.png")),
            Entry(name: "assets/card.png", data: png)
        ])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rocomponent")
        try archive.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let reference = try OverlayComponentLoader.loadReference(at: url)
        #expect(reference.source == .imported)
        #expect(reference.definition != nil)
        #expect(reference.assets?["assets/card.png"] == png)
    }

    @Test func archiveRejectsPathTraversal() throws {
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON()),
            Entry(name: "../evil.png", data: Data([1]))
        ])
        #expect(throws: OverlayComponentValidationError.self) {
            _ = try OverlayComponentLoader.load(archive: archive)
        }
    }

    @Test func archiveRejectsMissingDefinition() throws {
        let archive = makeZip([
            Entry(name: "assets/card.png", data: Data([1]))
        ])
        #expect(throws: OverlayComponentValidationError.self) {
            _ = try OverlayComponentLoader.load(archive: archive)
        }
    }

    @Test func archiveRejectsEncryptedEntries() throws {
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON(), flags: 0x0001)
        ])
        #expect(throws: OverlayComponentValidationError.self) {
            _ = try OverlayComponentLoader.load(archive: archive)
        }
    }

    @Test func archiveRejectsUnsupportedCompression() throws {
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON(), methodOverride: 12)
        ])
        #expect(throws: OverlayComponentValidationError.self) {
            _ = try OverlayComponentLoader.load(archive: archive)
        }
    }

    @Test func archiveRejectsDuplicateEntries() throws {
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON()),
            Entry(name: "component.json", data: componentJSON())
        ])
        #expect(throws: OverlayComponentValidationError.self) {
            _ = try OverlayComponentLoader.load(archive: archive)
        }
    }

    @Test func archiveRejectsOversizedAsset() throws {
        let archive = makeZip([
            Entry(name: "component.json", data: componentJSON()),
            Entry(
                name: "assets/huge.png",
                data: Data([1]),
                declaredUncompressedSize: 9 * 1024 * 1024
            )
        ])
        #expect(throws: OverlayComponentValidationError.self) {
            _ = try OverlayComponentLoader.load(archive: archive)
        }
    }

    // MARK: - ZIP writer

    private func makeZip(_ entries: [Entry]) -> Data {
        var output = Data()
        var directory = Data()

        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            let method = entry.methodOverride ?? (entry.deflated ? 8 : 0)
            let payload = method == 8 ? deflate(entry.data) : entry.data
            let uncompressedSize = entry.declaredUncompressedSize ?? entry.data.count
            let checksum = crc32(entry.data)
            let localOffset = output.count

            output.appendLE32(0x0403_4B50)
            output.appendLE16(20)
            output.appendLE16(entry.flags)
            output.appendLE16(method)
            output.appendLE16(0)
            output.appendLE16(0)
            output.appendLE32(checksum)
            output.appendLE32(UInt32(payload.count))
            output.appendLE32(UInt32(uncompressedSize))
            output.appendLE16(UInt16(nameBytes.count))
            output.appendLE16(0)
            output.append(nameBytes)
            output.append(payload)

            directory.appendLE32(0x0201_4B50)
            directory.appendLE16(20)
            directory.appendLE16(20)
            directory.appendLE16(entry.flags)
            directory.appendLE16(method)
            directory.appendLE16(0)
            directory.appendLE16(0)
            directory.appendLE32(checksum)
            directory.appendLE32(UInt32(payload.count))
            directory.appendLE32(UInt32(uncompressedSize))
            directory.appendLE16(UInt16(nameBytes.count))
            directory.appendLE16(0)
            directory.appendLE16(0)
            directory.appendLE16(0)
            directory.appendLE16(0)
            directory.appendLE32(0)
            directory.appendLE32(UInt32(localOffset))
            directory.append(nameBytes)
        }

        let directoryOffset = output.count
        output.append(directory)
        output.appendLE32(0x0605_4B50)
        output.appendLE16(0)
        output.appendLE16(0)
        output.appendLE16(UInt16(entries.count))
        output.appendLE16(UInt16(entries.count))
        output.appendLE32(UInt32(directory.count))
        output.appendLE32(UInt32(directoryOffset))
        output.appendLE16(0)
        return output
    }

    private func deflate(_ data: Data) -> Data {
        guard !data.isEmpty else { return Data() }
        var destination = [UInt8](repeating: 0, count: max(data.count * 2, 64))
        let written = data.withUnsafeBytes { source in
            destination.withUnsafeMutableBufferPointer { buffer in
                compression_encode_buffer(
                    buffer.baseAddress!,
                    buffer.count,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        return Data(destination.prefix(written))
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLE16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8(value >> 8))
    }

    mutating func appendLE32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8(value >> 24))
    }
}
