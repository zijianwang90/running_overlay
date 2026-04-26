import Foundation

enum FitFileParserError: LocalizedError {
    case invalidHeader(String)
    case malformedData(offset: Int, reason: String)
    case undefinedLocalMessage(type: UInt8, offset: Int)
    case missingActivityTime

    var errorDescription: String? {
        switch self {
        case .invalidHeader(let reason):
            "The selected file is not a valid FIT file. \(reason)"
        case .malformedData(let offset, let reason):
            "FIT parsing failed at byte \(offset): \(reason)"
        case .undefinedLocalMessage(let type, let offset):
            "FIT parsing failed at byte \(offset): local message \(type) has no definition."
        case .missingActivityTime:
            "The FIT file did not contain enough timing data to build an activity timeline."
        }
    }
}

struct FitFileParser {
    private let data: Data
    private var offset = 0
    private var definitions: [UInt8: FitDefinitionMessage] = [:]
    private var records: [ActivityRecord] = []
    private var sessionStartDate: Date?
    private var sessionElapsedTime: TimeInterval?
    private var sessionDistanceMeters: Double?
    private var sessionCalories: Double?

    init(data: Data) {
        self.data = data
    }

    static func parse(url: URL) throws -> ActivityTimeline {
        let data = try Data(contentsOf: url)
        var parser = FitFileParser(data: data)
        return try parser.parse()
    }

    mutating func parse() throws -> ActivityTimeline {
        let dataRange = try readHeader()
        offset = dataRange.lowerBound

        while offset < dataRange.upperBound {
            try readMessage(dataEnd: dataRange.upperBound)
        }

        if let firstRecordDate = records.map(\.timestamp).min() {
            let startDate = sessionStartDate ?? firstRecordDate
            let normalizedRecords = records
                .map { record in
                    var normalized = record
                    normalized.elapsedTime = max(record.timestamp.timeIntervalSince(startDate), 0)
                    return normalized
                }
                .sorted { $0.elapsedTime < $1.elapsedTime }
            let duration = sessionElapsedTime ?? max(normalizedRecords.map(\.elapsedTime).max() ?? 0, 1)
            let distance = sessionDistanceMeters ?? records.compactMap(\.distanceMeters).max() ?? 0
            return ActivityTimeline(
                startDate: startDate,
                duration: duration,
                distanceMeters: distance,
                records: normalizedRecords
            )
        }

        if let startDate = sessionStartDate, let elapsed = sessionElapsedTime {
            return ActivityTimeline(
                startDate: startDate,
                duration: elapsed,
                distanceMeters: sessionDistanceMeters ?? 0,
                records: []
            )
        }

        throw FitFileParserError.missingActivityTime
    }

    private mutating func readHeader() throws -> Range<Int> {
        guard data.count >= 14 else {
            throw FitFileParserError.invalidHeader("File is shorter than the minimum FIT header.")
        }

        let headerSize = Int(data[0])
        guard headerSize == 12 || headerSize == 14, data.count >= headerSize else {
            throw FitFileParserError.invalidHeader("Unsupported header size \(headerSize).")
        }

        let signature = String(bytes: data[8..<12], encoding: .ascii)
        guard signature == ".FIT" else {
            throw FitFileParserError.invalidHeader("Missing .FIT signature.")
        }

        let dataSize = Int(readUInt32(at: 4, architecture: .littleEndian))
        let dataStart = headerSize
        let dataEnd = dataStart + dataSize
        guard dataEnd <= data.count else {
            throw FitFileParserError.invalidHeader("Declared data size exceeds file length.")
        }

        return dataStart..<dataEnd
    }

    private mutating func readMessage(dataEnd: Int) throws {
        let header = try readUInt8(dataEnd: dataEnd)

        if header & 0x80 != 0 {
            let localMessageType = (header >> 5) & 0x03
            try readDataMessage(localMessageType: localMessageType, dataEnd: dataEnd)
            return
        }

        let localMessageType = header & 0x0F
        if header & 0x40 != 0 {
            try readDefinitionMessage(
                localMessageType: localMessageType,
                hasDeveloperFields: header & 0x20 != 0,
                dataEnd: dataEnd
            )
        } else {
            try readDataMessage(localMessageType: localMessageType, dataEnd: dataEnd)
        }
    }

    private mutating func readDefinitionMessage(
        localMessageType: UInt8,
        hasDeveloperFields: Bool,
        dataEnd: Int
    ) throws {
        _ = try readUInt8(dataEnd: dataEnd)
        let architectureByte = try readUInt8(dataEnd: dataEnd)
        let architecture: FitArchitecture = architectureByte == 0 ? .littleEndian : .bigEndian
        let globalMessageNumber = try readUInt16(dataEnd: dataEnd, architecture: architecture)
        let fieldCount = Int(try readUInt8(dataEnd: dataEnd))

        var fields: [FitFieldDefinition] = []
        for _ in 0..<fieldCount {
            fields.append(FitFieldDefinition(
                number: try readUInt8(dataEnd: dataEnd),
                size: Int(try readUInt8(dataEnd: dataEnd)),
                baseType: try readUInt8(dataEnd: dataEnd)
            ))
        }

        var developerFields: [FitDeveloperFieldDefinition] = []
        if hasDeveloperFields {
            let developerFieldCount = Int(try readUInt8(dataEnd: dataEnd))
            for _ in 0..<developerFieldCount {
                developerFields.append(FitDeveloperFieldDefinition(
                    number: try readUInt8(dataEnd: dataEnd),
                    size: Int(try readUInt8(dataEnd: dataEnd)),
                    developerDataIndex: try readUInt8(dataEnd: dataEnd)
                ))
            }
        }

        definitions[localMessageType] = FitDefinitionMessage(
            architecture: architecture,
            globalMessageNumber: globalMessageNumber,
            fields: fields,
            developerFields: developerFields
        )
    }

    private mutating func readDataMessage(localMessageType: UInt8, dataEnd: Int) throws {
        guard let definition = definitions[localMessageType] else {
            throw FitFileParserError.undefinedLocalMessage(type: localMessageType, offset: offset)
        }

        var fieldValues: [UInt8: Data] = [:]
        for field in definition.fields {
            guard offset + field.size <= dataEnd else {
                throw FitFileParserError.malformedData(offset: offset, reason: "Field \(field.number) exceeds FIT data section.")
            }
            fieldValues[field.number] = data[offset..<offset + field.size]
            offset += field.size
        }

        for field in definition.developerFields {
            guard offset + field.size <= dataEnd else {
                throw FitFileParserError.malformedData(offset: offset, reason: "Developer field \(field.number) exceeds FIT data section.")
            }
            offset += field.size
        }

        switch definition.globalMessageNumber {
        case 20:
            if let record = makeActivityRecord(from: fieldValues, architecture: definition.architecture) {
                records.append(record)
            }
        case 18:
            readSession(from: fieldValues, architecture: definition.architecture)
        default:
            break
        }
    }

    private mutating func readSession(from fields: [UInt8: Data], architecture: FitArchitecture) {
        if let rawStart = uint32(fields[2], architecture: architecture), rawStart != UInt32.max {
            sessionStartDate = fitDate(rawStart)
        }
        if let elapsedRaw = uint32(fields[7], architecture: architecture), elapsedRaw != UInt32.max {
            sessionElapsedTime = Double(elapsedRaw) / 1000
        }
        if let distanceRaw = uint32(fields[9], architecture: architecture), distanceRaw != UInt32.max {
            sessionDistanceMeters = Double(distanceRaw) / 100
        }
        if let caloriesRaw = uint16(fields[11], architecture: architecture), caloriesRaw != UInt16.max {
            sessionCalories = Double(caloriesRaw)
        }
    }

    private func makeActivityRecord(from fields: [UInt8: Data], architecture: FitArchitecture) -> ActivityRecord? {
        guard let rawTimestamp = uint32(fields[253], architecture: architecture), rawTimestamp != UInt32.max else {
            return nil
        }

        let timestamp = fitDate(rawTimestamp)
        let startDate = sessionStartDate ?? timestamp
        let distance = uint32(fields[5], architecture: architecture).flatMap(validUInt32).map { Double($0) / 100 }
        let speed = uint16(fields[6], architecture: architecture).flatMap(validUInt16).map { Double($0) / 1000 }
        let heartRate = fields[3].flatMap(uint8).flatMap(validUInt8).map(Int.init)
        let cadence = fields[4].flatMap(uint8).flatMap(validUInt8).map(Int.init)
        let altitude = uint16(fields[2], architecture: architecture).flatMap(validUInt16).map { Double($0) / 5 - 500 }
        let power = uint16(fields[7], architecture: architecture).flatMap(validUInt16).map(Int.init)
        let calories = uint16(fields[33], architecture: architecture).flatMap(validUInt16).map(Double.init) ?? sessionCalories
        let latitude = int32(fields[0], architecture: architecture).flatMap(validInt32).map(semicirclesToDegrees)
        let longitude = int32(fields[1], architecture: architecture).flatMap(validInt32).map(semicirclesToDegrees)

        return ActivityRecord(
            elapsedTime: max(timestamp.timeIntervalSince(startDate), 0),
            timestamp: timestamp,
            distanceMeters: distance,
            heartRate: heartRate,
            paceSecondsPerKilometer: speed.map { $0 > 0 ? 1000 / $0 : 0 },
            elevationMeters: altitude,
            cadence: cadence,
            powerWatts: power,
            calories: calories,
            latitude: latitude,
            longitude: longitude
        )
    }

    private func fitDate(_ timestamp: UInt32) -> Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) + 631_065_600)
    }

    private mutating func readUInt8(dataEnd: Int) throws -> UInt8 {
        guard offset < dataEnd else {
            throw FitFileParserError.malformedData(offset: offset, reason: "Unexpected end of FIT data.")
        }
        defer { offset += 1 }
        return data[offset]
    }

    private mutating func readUInt16(dataEnd: Int, architecture: FitArchitecture) throws -> UInt16 {
        guard offset + 2 <= dataEnd else {
            throw FitFileParserError.malformedData(offset: offset, reason: "Unexpected end of FIT data while reading UInt16.")
        }
        defer { offset += 2 }
        return readUInt16(at: offset, architecture: architecture)
    }

    private func readUInt16(at index: Int, architecture: FitArchitecture) -> UInt16 {
        let bytes = data[index..<index + 2]
        switch architecture {
        case .littleEndian:
            return UInt16(bytes[bytes.startIndex]) | UInt16(bytes[bytes.startIndex + 1]) << 8
        case .bigEndian:
            return UInt16(bytes[bytes.startIndex]) << 8 | UInt16(bytes[bytes.startIndex + 1])
        }
    }

    private func readUInt32(at index: Int, architecture: FitArchitecture) -> UInt32 {
        let bytes = data[index..<index + 4]
        switch architecture {
        case .littleEndian:
            return UInt32(bytes[bytes.startIndex])
                | UInt32(bytes[bytes.startIndex + 1]) << 8
                | UInt32(bytes[bytes.startIndex + 2]) << 16
                | UInt32(bytes[bytes.startIndex + 3]) << 24
        case .bigEndian:
            return UInt32(bytes[bytes.startIndex]) << 24
                | UInt32(bytes[bytes.startIndex + 1]) << 16
                | UInt32(bytes[bytes.startIndex + 2]) << 8
                | UInt32(bytes[bytes.startIndex + 3])
        }
    }

    private func uint8(_ data: Data) -> UInt8? {
        guard data.count >= 1 else { return nil }
        return data[data.startIndex]
    }

    private func uint16(_ data: Data?, architecture: FitArchitecture) -> UInt16? {
        guard let data, data.count >= 2 else { return nil }
        let bytes = Array(data.prefix(2))
        switch architecture {
        case .littleEndian:
            return UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        case .bigEndian:
            return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        }
    }

    private func uint32(_ data: Data?, architecture: FitArchitecture) -> UInt32? {
        guard let data, data.count >= 4 else { return nil }
        let bytes = Array(data.prefix(4))
        switch architecture {
        case .littleEndian:
            return UInt32(bytes[0])
                | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16
                | UInt32(bytes[3]) << 24
        case .bigEndian:
            return UInt32(bytes[0]) << 24
                | UInt32(bytes[1]) << 16
                | UInt32(bytes[2]) << 8
                | UInt32(bytes[3])
        }
    }

    private func int32(_ data: Data?, architecture: FitArchitecture) -> Int32? {
        uint32(data, architecture: architecture).map { Int32(bitPattern: $0) }
    }

    private func validUInt8(_ value: UInt8) -> UInt8? {
        value == UInt8.max ? nil : value
    }

    private func validUInt16(_ value: UInt16) -> UInt16? {
        value == UInt16.max ? nil : value
    }

    private func validUInt32(_ value: UInt32) -> UInt32? {
        value == UInt32.max ? nil : value
    }

    private func validInt32(_ value: Int32) -> Int32? {
        value == Int32.max ? nil : value
    }

    private func semicirclesToDegrees(_ value: Int32) -> Double {
        Double(value) * 180 / 2_147_483_648
    }
}

private struct FitDefinitionMessage {
    var architecture: FitArchitecture
    var globalMessageNumber: UInt16
    var fields: [FitFieldDefinition]
    var developerFields: [FitDeveloperFieldDefinition]
}

private struct FitFieldDefinition {
    var number: UInt8
    var size: Int
    var baseType: UInt8
}

private struct FitDeveloperFieldDefinition {
    var number: UInt8
    var size: Int
    var developerDataIndex: UInt8
}

private enum FitArchitecture {
    case littleEndian
    case bigEndian
}
