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
    private var rawLaps: [RawLap] = []
    private var sessionStartDate: Date?
    private var sessionElapsedTime: TimeInterval?
    private var sessionDistanceMeters: Double?
    private var sessionCalories: Double?

    private struct RawLap {
        var startTimestamp: Date?
        var totalElapsedTime: TimeInterval
        var totalDistanceMeters: Double
        var avgSpeedMS: Double?
        var avgHeartRate: Int?
        var maxHeartRate: Int?
        var avgCadenceStrides: Int?   // strides/min from FIT field 17
        var avgPowerWatts: Int?
        var totalAscent: Int?
    }

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
            let lapRecords = buildLapRecords(startDate: startDate, totalLaps: rawLaps.count)
            return ActivityTimeline(
                startDate: startDate,
                duration: duration,
                distanceMeters: distance,
                records: normalizedRecords,
                laps: lapRecords
            )
        }

        if let startDate = sessionStartDate, let elapsed = sessionElapsedTime {
            return ActivityTimeline(
                startDate: startDate,
                duration: elapsed,
                distanceMeters: sessionDistanceMeters ?? 0,
                records: [],
                laps: []
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
        case 19:
            if let lap = makeLap(from: fieldValues, architecture: definition.architecture) {
                rawLaps.append(lap)
            }
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
        let verticalOscillation = uint16(fields[39], architecture: architecture).flatMap(validUInt16).map { Double($0) / 10.0 }
        let groundContactTime = uint16(fields[41], architecture: architecture).flatMap(validUInt16).map { Double($0) / 10.0 }
        let strideLength = uint16(fields[84], architecture: architecture).flatMap(validUInt16).map { Double($0) / 10_000.0 }
        let groundContactBalance = parseGroundContactBalance(fields[30])
        let temperature = int8(fields[13]).flatMap(validInt8).map(Double.init)
        let grade = int16(fields[9], architecture: architecture).flatMap(validInt16).map { Double($0) / 100.0 }

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
            longitude: longitude,
            verticalOscillationMM: verticalOscillation,
            groundContactTimeMS: groundContactTime,
            strideLengthM: strideLength,
            groundContactBalance: groundContactBalance,
            temperatureCelsius: temperature,
            gradePercent: grade
        )
    }

    private func makeLap(from fields: [UInt8: Data], architecture: FitArchitecture) -> RawLap? {
        guard let elapsed = uint32(fields[7], architecture: architecture).flatMap(validUInt32) else { return nil }
        let startRaw = uint32(fields[2], architecture: architecture).flatMap(validUInt32)
        let dist = uint32(fields[9], architecture: architecture).flatMap(validUInt32).map { Double($0) / 100 } ?? 0
        let avgSpeed = uint16(fields[13], architecture: architecture).flatMap(validUInt16).map { Double($0) / 1000 }
        let avgHR = fields[15].flatMap(uint8).flatMap(validUInt8).map(Int.init)
        let maxHR = fields[16].flatMap(uint8).flatMap(validUInt8).map(Int.init)
        let cadence = fields[17].flatMap(uint8).flatMap(validUInt8).map { Int($0) * 2 }  // strides→spm
        let power = uint16(fields[19], architecture: architecture).flatMap(validUInt16).flatMap { $0 == 0 ? nil : Int($0) }
        let ascent = uint16(fields[21], architecture: architecture).flatMap(validUInt16).map(Int.init)
        return RawLap(
            startTimestamp: startRaw.map(fitDate),
            totalElapsedTime: Double(elapsed) / 1000,
            totalDistanceMeters: dist,
            avgSpeedMS: avgSpeed,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            avgCadenceStrides: cadence,
            avgPowerWatts: power,
            totalAscent: ascent
        )
    }

    private func buildLapRecords(startDate: Date, totalLaps: Int) -> [LapRecord] {
        guard !rawLaps.isEmpty else { return [] }
        var result: [LapRecord] = []
        var cumulativeDistance = 0.0
        var cumulativeTime = 0.0

        for (index, raw) in rawLaps.enumerated() {
            let startElapsed: TimeInterval
            if let ts = raw.startTimestamp {
                startElapsed = max(ts.timeIntervalSince(startDate), 0)
            } else {
                startElapsed = cumulativeTime
            }
            let endElapsed = startElapsed + raw.totalElapsedTime
            let pace = raw.avgSpeedMS.map { $0 > 0 ? 1000 / $0 : 0 }
            let kind = lapKind(index: index, total: rawLaps.count, avgSpeedMS: raw.avgSpeedMS)
            result.append(LapRecord(
                lapIndex: index,
                startElapsedTime: startElapsed,
                endElapsedTime: endElapsed,
                startDistanceMeters: cumulativeDistance,
                totalDistanceMeters: raw.totalDistanceMeters,
                totalElapsedTime: raw.totalElapsedTime,
                avgPaceSecondsPerKm: pace,
                avgHeartRate: raw.avgHeartRate,
                maxHeartRate: raw.maxHeartRate,
                avgCadenceSPM: raw.avgCadenceStrides,
                avgPowerWatts: raw.avgPowerWatts,
                totalAscent: raw.totalAscent,
                kind: kind
            ))
            cumulativeDistance += raw.totalDistanceMeters
            cumulativeTime = endElapsed
        }
        return result
    }

    private func lapKind(index: Int, total: Int, avgSpeedMS: Double?) -> LapKind {
        let speed = avgSpeedMS ?? 0
        // First and last laps are warmup/cooldown if they are slow jogs
        if index == 0, speed < 3.5 { return .warmup }
        if index == total - 1, speed < 3.5 { return .cooldown }
        return speed >= 3.5 ? .active : .rest
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

    private func int8(_ data: Data?) -> Int8? {
        guard let data, data.count >= 1 else { return nil }
        return Int8(bitPattern: data[data.startIndex])
    }

    private func int16(_ data: Data?, architecture: FitArchitecture) -> Int16? {
        uint16(data, architecture: architecture).map { Int16(bitPattern: $0) }
    }

    private func validInt8(_ value: Int8) -> Int8? {
        value == Int8.max ? nil : value
    }

    private func validInt16(_ value: Int16) -> Int16? {
        value == Int16.max ? nil : value
    }

    private func parseGroundContactBalance(_ data: Data?) -> Double? {
        guard let raw = data.flatMap(uint8), raw != UInt8.max else { return nil }
        let pct = Double(raw & 0x7F)
        // bit 7 set → stored percentage is for right side; otherwise for left side
        return raw & 0x80 != 0 ? 100.0 - pct : pct
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
