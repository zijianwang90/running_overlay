import Foundation

enum GpxFileParserError: LocalizedError, Equatable {
    case malformedXML(String)
    case invalidTrackPoint(String)
    case missingTrackPoints
    case missingTrackPointTimes
    case insufficientActivityTime

    var errorDescription: String? {
        switch self {
        case .malformedXML(let reason):
            "The selected file is not valid GPX XML. \(reason)"
        case .invalidTrackPoint(let reason):
            "The GPX file contains an invalid track point. \(reason)"
        case .missingTrackPoints:
            "The GPX file does not contain any track points."
        case .missingTrackPointTimes:
            "The GPX track points do not contain timestamps."
        case .insufficientActivityTime:
            "The GPX file needs at least two timed track points with different timestamps."
        }
    }
}

struct GpxFileParser {
    static func parse(url: URL) throws -> ActivityTimeline {
        try parse(data: Data(contentsOf: url))
    }

    static func parse(data: Data) throws -> ActivityTimeline {
        let delegate = GpxXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            if let semanticError = delegate.semanticError {
                throw semanticError
            }
            throw GpxFileParserError.malformedXML(
                parser.parserError?.localizedDescription ?? "The XML parser could not read the document."
            )
        }
        if let semanticError = delegate.semanticError {
            throw semanticError
        }

        return try makeActivity(from: delegate.trackPoints)
    }

    private static func makeActivity(from trackPoints: [GpxTrackPoint]) throws -> ActivityTimeline {
        guard !trackPoints.isEmpty else {
            throw GpxFileParserError.missingTrackPoints
        }

        let timedPoints = trackPoints.enumerated()
            .compactMap { index, point -> (index: Int, point: GpxTrackPoint)? in
                guard point.timestamp != nil else { return nil }
                return (index, point)
            }
            .sorted {
                let left = $0.point.timestamp!
                let right = $1.point.timestamp!
                return left == right ? $0.index < $1.index : left < right
            }

        guard !timedPoints.isEmpty else {
            throw GpxFileParserError.missingTrackPointTimes
        }

        let startDate = timedPoints[0].point.timestamp!
        guard let endDate = timedPoints.last?.point.timestamp,
              endDate > startDate else {
            throw GpxFileParserError.insufficientActivityTime
        }

        var records: [ActivityRecord] = []
        var cumulativeDistance = 0.0
        var previous: GpxTrackPoint?

        for entry in timedPoints {
            let point = entry.point
            let timestamp = point.timestamp!
            var segmentDistance = 0.0
            var pace: Double?
            var grade: Double?

            if let previous,
               previous.segmentIndex == point.segmentIndex,
               let previousTimestamp = previous.timestamp {
                segmentDistance = haversineDistance(
                    latitude1: previous.latitude,
                    longitude1: previous.longitude,
                    latitude2: point.latitude,
                    longitude2: point.longitude
                )
                cumulativeDistance += segmentDistance

                let deltaTime = timestamp.timeIntervalSince(previousTimestamp)
                if let speed = point.speedMetersPerSecond, speed > 0 {
                    pace = 1000 / speed
                } else if deltaTime > 0, segmentDistance > 0 {
                    pace = deltaTime / (segmentDistance / 1000)
                }

                if segmentDistance > 0,
                   let previousElevation = previous.elevationMeters,
                   let elevation = point.elevationMeters {
                    grade = (elevation - previousElevation) / segmentDistance * 100
                }
            } else if let speed = point.speedMetersPerSecond, speed > 0 {
                pace = 1000 / speed
            }

            records.append(ActivityRecord(
                elapsedTime: timestamp.timeIntervalSince(startDate),
                timestamp: timestamp,
                distanceMeters: cumulativeDistance,
                heartRate: point.heartRate,
                paceSecondsPerKilometer: pace,
                elevationMeters: point.elevationMeters,
                cadence: point.cadence,
                powerWatts: point.powerWatts,
                calories: nil,
                latitude: point.latitude,
                longitude: point.longitude,
                temperatureCelsius: point.temperatureCelsius,
                gradePercent: grade,
                genericFields: point.genericFields
            ))
            previous = point
        }

        return ActivityTimeline(
            startDate: startDate,
            duration: endDate.timeIntervalSince(startDate),
            distanceMeters: cumulativeDistance,
            records: records,
            laps: [],
            annotatedSegments: [],
            workoutStructure: .normalAuto
        )
    }

    private static func haversineDistance(
        latitude1: Double,
        longitude1: Double,
        latitude2: Double,
        longitude2: Double
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let degreesToRadians = Double.pi / 180
        let latitudeDelta = (latitude2 - latitude1) * degreesToRadians
        let longitudeDelta = (longitude2 - longitude1) * degreesToRadians
        let firstLatitude = latitude1 * degreesToRadians
        let secondLatitude = latitude2 * degreesToRadians
        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(firstLatitude) * cos(secondLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let clampedA = min(max(a, 0), 1)
        return earthRadiusMeters * 2 * atan2(sqrt(clampedA), sqrt(1 - clampedA))
    }
}

private struct GpxTrackPoint {
    var segmentIndex: Int
    var latitude: Double
    var longitude: Double
    var elevationMeters: Double?
    var timestamp: Date?
    var heartRate: Int?
    var cadence: Int?
    var powerWatts: Int?
    var temperatureCelsius: Double?
    var speedMetersPerSecond: Double?
    var genericFields: [String: Double] = [:]
}

private final class GpxXMLDelegate: NSObject, XMLParserDelegate {
    private(set) var trackPoints: [GpxTrackPoint] = []
    private(set) var semanticError: GpxFileParserError?

    private var currentTrackPoint: GpxTrackPoint?
    private var segmentIndex = -1
    private var elementNames: [String] = []
    private var elementText: [String] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = localName(qName ?? elementName)
        elementNames.append(name)
        elementText.append("")

        if name == "trkseg" {
            segmentIndex += 1
            return
        }

        guard name == "trkpt" else { return }
        guard let latitudeText = attributeDict["lat"],
              let longitudeText = attributeDict["lon"],
              let latitude = Double(latitudeText),
              let longitude = Double(longitudeText),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            semanticError = .invalidTrackPoint("Latitude and longitude must be valid decimal coordinates.")
            parser.abortParsing()
            return
        }

        currentTrackPoint = GpxTrackPoint(
            segmentIndex: max(segmentIndex, 0),
            latitude: latitude,
            longitude: longitude
        )
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !elementText.isEmpty else { return }
        elementText[elementText.count - 1].append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = localName(qName ?? elementName)
        let text = elementText.popLast()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isExtensionValue = elementNames.dropLast().contains("extensions")
        _ = elementNames.popLast()

        if name == "trkpt" {
            if let currentTrackPoint {
                trackPoints.append(currentTrackPoint)
            }
            currentTrackPoint = nil
            return
        }

        guard currentTrackPoint != nil, !text.isEmpty else { return }
        switch name {
        case "ele":
            currentTrackPoint?.elevationMeters = Double(text)
        case "time":
            guard let timestamp = Self.parseTimestamp(text) else {
                semanticError = .invalidTrackPoint("Timestamp \"\(text)\" is not valid ISO 8601.")
                parser.abortParsing()
                return
            }
            currentTrackPoint?.timestamp = timestamp
        case "hr" where isExtensionValue, "heartrate" where isExtensionValue:
            currentTrackPoint?.heartRate = Self.parseInteger(text)
        case "cad" where isExtensionValue, "cadence" where isExtensionValue:
            currentTrackPoint?.cadence = Self.parseInteger(text)
        case "power" where isExtensionValue,
             "watts" where isExtensionValue,
             "powerinwatts" where isExtensionValue:
            currentTrackPoint?.powerWatts = Self.parseInteger(text)
        case "atemp" where isExtensionValue,
             "temp" where isExtensionValue,
             "temperature" where isExtensionValue:
            currentTrackPoint?.temperatureCelsius = Double(text)
        case "speed" where isExtensionValue:
            currentTrackPoint?.speedMetersPerSecond = Double(text)
        default:
            if isExtensionValue, let value = Double(text) {
                currentTrackPoint?.genericFields["gpx.\(name)"] = value
            }
        }
    }

    private func localName(_ qualifiedName: String) -> String {
        qualifiedName.split(separator: ":").last.map(String.init)?.lowercased() ?? qualifiedName.lowercased()
    }

    private static func parseInteger(_ text: String) -> Int? {
        Double(text).map { Int($0.rounded()) }
    }

    private static func parseTimestamp(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: text)
    }
}
