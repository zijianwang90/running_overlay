import Compression
import Foundation

/// Reads the subset of ZIP needed for `.rocomponent` packages.
///
/// Packages are untrusted input, so extraction is defensive:
/// - stored (method 0) and deflate (method 8) entries only;
/// - no encryption, ZIP64, or path traversal (`..`, absolute paths, backslashes);
/// - no symlink entries, duplicate names, or entries outside the package shape;
/// - per-entry and total uncompressed size limits matching the v0.1 spec;
/// - CRC-32 verification before an entry is accepted.
///
/// macOS metadata (`__MACOSX/`, `.DS_Store`) is ignored because Finder and
/// `ditto` add it when users compress a folder.
enum OverlayComponentZipArchive {
    struct Contents: Equatable {
        var definitionData: Data
        var assets: [String: Data]
    }

    static let maximumPackageBytes = 32 * 1024 * 1024
    static let maximumAssetBytes = 8 * 1024 * 1024
    static let maximumDefinitionBytes = 1024 * 1024
    static let maximumEntries = 64

    static func looksLikeZip(_ data: Data) -> Bool {
        data.starts(with: [0x50, 0x4B, 0x03, 0x04])
    }

    static func extract(_ data: Data) throws -> Contents {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else {
            throw failure("archive is too small to be a ZIP file")
        }

        let endOffset = try endOfCentralDirectoryOffset(in: bytes)
        guard endOffset + 22 <= bytes.count else {
            throw failure("truncated ZIP end-of-central-directory record")
        }
        guard u32(bytes, endOffset) == 0x0605_4B50 else {
            throw failure("missing ZIP end-of-central-directory signature")
        }

        let entryCount = Int(u16(bytes, endOffset + 10))
        let directorySize = Int(u32(bytes, endOffset + 12))
        let directoryOffset = Int(u32(bytes, endOffset + 16))
        if entryCount == 0xFFFF || directorySize == 0xFFFF_FFFF || directoryOffset == 0xFFFF_FFFF {
            throw failure("ZIP64 archives are not supported")
        }
        guard entryCount > 0, entryCount <= maximumEntries else {
            throw failure("package must contain between 1 and \(maximumEntries) entries")
        }
        guard directoryOffset >= 0,
              directorySize >= 0,
              directoryOffset + directorySize <= bytes.count else {
            throw failure("ZIP central directory is out of bounds")
        }

        var contents: Contents?
        var cursor = directoryOffset
        var seenNames: Set<String> = []
        var totalBytes = 0

        for _ in 0..<entryCount {
            guard cursor + 46 <= bytes.count, u32(bytes, cursor) == 0x0201_4B50 else {
                throw failure("corrupt ZIP central directory entry")
            }
            let flags = u16(bytes, cursor + 8)
            let method = Int(u16(bytes, cursor + 10))
            let crc = u32(bytes, cursor + 16)
            let compressedSize = Int(u32(bytes, cursor + 20))
            let uncompressedSize = Int(u32(bytes, cursor + 24))
            let nameLength = Int(u16(bytes, cursor + 28))
            let extraLength = Int(u16(bytes, cursor + 30))
            let commentLength = Int(u16(bytes, cursor + 32))
            let externalAttributes = u32(bytes, cursor + 38)
            let localOffset = Int(u32(bytes, cursor + 42))
            let next = cursor + 46 + nameLength + extraLength + commentLength
            guard next <= bytes.count, cursor + 46 + nameLength <= bytes.count else {
                throw failure("corrupt ZIP central directory entry")
            }
            let nameBytes = bytes[(cursor + 46)..<(cursor + 46 + nameLength)]
            guard let name = String(validating: nameBytes, as: UTF8.self) else {
                throw failure("ZIP entry names must be UTF-8")
            }
            cursor = next

            if isMetadata(name) || name.hasSuffix("/") { continue }
            guard seenNames.insert(name).inserted else {
                throw failure("duplicate ZIP entry '\(name)'")
            }
            guard flags & 0x0001 == 0 else {
                throw failure("encrypted ZIP entries are not supported")
            }
            guard !name.contains("\\"), !name.hasPrefix("/") else {
                throw failure("invalid ZIP entry path '\(name)'")
            }
            let components = name.split(separator: "/", omittingEmptySubsequences: false)
            guard !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
                throw failure("invalid ZIP entry path '\(name)'")
            }
            let unixMode = (externalAttributes >> 16) & 0xF000
            guard unixMode != 0xA000 else {
                throw failure("symbolic links are not allowed in packages")
            }
            guard method == 0 || method == 8 else {
                throw failure("unsupported ZIP compression method \(method) for '\(name)'")
            }
            guard compressedSize >= 0, uncompressedSize >= 0 else {
                throw failure("invalid ZIP entry sizes for '\(name)'")
            }
            let limit = entryLimit(for: name)
            guard uncompressedSize <= limit else {
                throw failure("'\(name)' exceeds the \(limit / 1024) KiB limit")
            }
            totalBytes += uncompressedSize
            guard totalBytes <= maximumPackageBytes else {
                throw failure("package exceeds 32 MiB uncompressed")
            }
            guard let raw = entryData(
                bytes,
                localOffset: localOffset,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                method: method
            ) else {
                throw failure("could not read ZIP entry '\(name)'")
            }
            guard crc32(raw) == crc else {
                throw failure("checksum mismatch for '\(name)'")
            }

            if name == "component.json" {
                var updated = contents ?? Contents(definitionData: Data(), assets: [:])
                updated.definitionData = raw
                contents = updated
            } else if name.hasPrefix("assets/") {
                var updated = contents ?? Contents(definitionData: Data(), assets: [:])
                updated.assets[name] = raw
                contents = updated
            } else {
                throw failure("unexpected file '\(name)' in package")
            }
        }

        guard let contents, !contents.definitionData.isEmpty else {
            throw failure("package is missing component.json at the root")
        }
        return contents
    }

    // MARK: - Entry data

    private static func entryLimit(for name: String) -> Int {
        name == "component.json" ? maximumDefinitionBytes : maximumAssetBytes
    }

    private static func isMetadata(_ name: String) -> Bool {
        name.hasPrefix("__MACOSX/") || (name as NSString).lastPathComponent == ".DS_Store"
    }

    private static func entryData(
        _ bytes: [UInt8],
        localOffset: Int,
        compressedSize: Int,
        uncompressedSize: Int,
        method: Int
    ) -> Data? {
        guard localOffset >= 0, localOffset + 30 <= bytes.count,
              u32(bytes, localOffset) == 0x0403_4B50 else {
            return nil
        }
        let nameLength = Int(u16(bytes, localOffset + 26))
        let extraLength = Int(u16(bytes, localOffset + 28))
        let start = localOffset + 30 + nameLength + extraLength
        guard start >= 0, start + compressedSize <= bytes.count else {
            return nil
        }
        let compressed = Array(bytes[start..<(start + compressedSize)])
        if method == 0 {
            guard compressed.count == uncompressedSize else { return nil }
            return Data(compressed)
        }
        return inflate(compressed, expectedSize: uncompressedSize)
    }

    /// ZIP stores raw DEFLATE (RFC 1951). `Compression`'s ZLIB algorithm may
    /// accept or expect the zlib wrapper depending on the platform, so try the
    /// raw stream first and a wrapper-stripped stream second.
    private static func inflate(_ compressed: [UInt8], expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return Data() }
        if let raw = inflateOnce(compressed, expectedSize: expectedSize) {
            return raw
        }
        if compressed.count > 6,
           compressed[0] & 0x0F == 8 {
            let stripped = Array(compressed[2..<(compressed.count - 4)])
            return inflateOnce(stripped, expectedSize: expectedSize)
        }
        return nil
    }

    private static func inflateOnce(_ source: [UInt8], expectedSize: Int) -> Data? {
        var destination = [UInt8](repeating: 0, count: expectedSize)
        let written = source.withUnsafeBufferPointer { sourceBuffer in
            destination.withUnsafeMutableBufferPointer { destinationBuffer in
                guard let sourceBase = sourceBuffer.baseAddress,
                      let destinationBase = destinationBuffer.baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destinationBase,
                    expectedSize,
                    sourceBase,
                    sourceBuffer.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written == expectedSize else { return nil }
        return Data(destination)
    }

    // MARK: - End of central directory

    private static func endOfCentralDirectoryOffset(in bytes: [UInt8]) throws -> Int {
        // The record is at the end unless a comment is present. Scan backwards
        // over the comment (max 65535 bytes) for the signature.
        let minimum = max(0, bytes.count - 22 - 65_535)
        var offset = bytes.count - 22
        while offset >= minimum {
            if u32(bytes, offset) == 0x0605_4B50 {
                let commentLength = Int(u16(bytes, offset + 20))
                if offset + 22 + commentLength == bytes.count {
                    return offset
                }
            }
            offset -= 1
        }
        throw failure("could not locate ZIP end-of-central-directory record")
    }

    // MARK: - Primitives

    private static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        guard offset >= 0, offset + 1 < bytes.count else { return 0 }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset >= 0, offset + 3 < bytes.count else { return 0 }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static func failure(_ message: String) -> OverlayComponentValidationError {
        OverlayComponentValidationError(diagnostics: [
            OverlayComponentDiagnostic(path: "archive", message: message)
        ])
    }
}
