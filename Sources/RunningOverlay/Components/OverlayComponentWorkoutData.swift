import Foundation

/// Host analysis and text only; components retain ownership of all geometry.
/// Inputs and returned times are activity elapsed seconds.
extension OverlayComponentActivityData {
    func segment(at time: TimeInterval) -> OverlayComponentValue {
        let lap = activity.currentLap(at: time)
        let kind = lap?.kind ?? .unknown
        let start = lap?.startElapsedTime ?? 0
        let end = lap?.endElapsedTime ?? max(activity.duration, 1)
        let duration = max(lap?.totalElapsedTime ?? activity.duration, 0)
        let distance = max(lap?.totalDistanceMeters ?? activity.distanceMeters, 0)
        let elapsed = max(time - start, 0)
        let remaining = max(end - time, 0)
        let traveled = min(max(activity.distance(at: time) - (lap?.startDistanceMeters ?? 0), 0), distance)
        let active = activity.laps.filter { $0.kind == .active }
        let repIndex: Int?
        if active.isEmpty {
            repIndex = nil
        } else if let lap, lap.kind == .active,
                  let index = active.firstIndex(where: { $0.id == lap.id }) {
            repIndex = index + 1
        } else if let lap {
            repIndex = min(active.filter { $0.endElapsedTime <= lap.startElapsedTime }.count + 1, active.count)
        } else {
            repIndex = 1
        }
        let groupColor = intervalColors.color(for: kind)
            ?? OverlayColor(red: 0.25, green: 0.82, blue: 0.38, alpha: 1)
        let zone = heartRateOrPaceZone(at: time).record
        let phaseColor = kind == .active ? (zone?["color"] ?? .color(groupColor)) : .color(groupColor)
        let phaseText: String
        switch kind {
        case .warmup: phaseText = "WU"
        case .active: phaseText = "WORK"
        case .rest: phaseText = "REST"
        case .cooldown: phaseText = "CD"
        case .unknown: phaseText = "LAP"
        }
        return .record([
            "index": lap.map { .number(Double($0.lapIndex)) } ?? .null,
            "startElapsed": .number(start), "endElapsed": .number(end),
            "startDistance": .number(lap?.startDistanceMeters ?? 0),
            "phase": .string(kind.rawValue), "phaseText": .string(phaseText),
            "groupColor": .color(groupColor), "phaseColor": phaseColor,
            "elapsed": .number(elapsed), "duration": .number(duration),
            "remaining": .number(remaining),
            // Native lapProgress returns zero when there is no source lap.
            "timeProgress": .number(activity.lapProgress(at: time, byDistance: false)),
            "distanceProgress": .number(activity.lapProgress(at: time, byDistance: true)),
            "distance": .number(distance), "elapsedDistance": .number(traveled),
            "remainingDistance": .number(max(distance - traveled, 0)),
            "elapsedText": .string(OverlayWorkoutFormatting.duration(elapsed)),
            "remainingText": .string(OverlayWorkoutFormatting.duration(remaining)),
            "elapsedDistanceText": .string(OverlayWorkoutFormatting.distance(traveled)),
            "remainingDistanceText": .string(OverlayWorkoutFormatting.distance(max(distance - traveled, 0))),
            "repIndex": repIndex.map { .number(Double($0)) } ?? .null,
            "repCount": .number(Double(active.count)),
            "repText": .string(repIndex.map { "\($0) / \(active.count)" } ?? "-- / --")
        ])
    }

    func lastWork(at time: TimeInterval) -> OverlayComponentValue {
        guard let lap = activity.lastActiveLap(at: time), var result = Self.lapRecord(lap).record else {
            return .null
        }
        result["completionAge"] = .number(time - lap.endElapsedTime)
        result["groupColor"] = .color(intervalColors.active)
        result["metrics"] = .record([
            "metric": OverlayWorkoutFormatting.summary(lap: lap, imperial: false),
            "imperial": OverlayWorkoutFormatting.summary(lap: lap, imperial: true)
        ])
        return .record(result)
    }

    func recovery(at time: TimeInterval) -> OverlayComponentValue {
        .record([
            "peakHeartRate": activity.recoveryPeakHR(at: time).map { .number(Double($0)) } ?? .null,
            "drop": activity.recoveryDrop(at: time).map { .number(Double($0)) } ?? .null,
            "dropPercent": activity.recoveryDropPercent(at: time).map(OverlayComponentValue.number) ?? .null
        ])
    }

    func heartRateOrPaceZone(at time: TimeInterval) -> OverlayComponentValue {
        guard let snapshot = zoneSnapshot else { return .null }
        if let hr = activity.heartRate(at: time),
           let index = Self.heartRateZoneIndex(heartRate: hr, snapshot: snapshot) {
            return zoneValue(index: index, snapshot: snapshot, isPace: false, value: Double(hr))
        }
        if let pace = activity.pace(at: time), pace > 0,
           let index = Self.paceZoneIndex(pace: pace, snapshot: snapshot) {
            return zoneValue(index: index, snapshot: snapshot, isPace: true, value: pace)
        }
        return .null
    }

    func zoneList(isPace: Bool) -> OverlayComponentValue {
        guard let snapshot = zoneSnapshot else { return .null }
        return .list((0..<max(snapshot.zoneCount, 0)).map { index in
            if index < snapshot.zones.count {
                return Self.zoneRecord(index: index, snapshot: snapshot, isPace: isPace)
            }
            return .record([
                "index": .number(Double(index + 1)), "count": .number(Double(snapshot.zoneCount)),
                "label": .string("Z\(index + 1)"), "color": .color(HRZonePalette.overlayColor(forIndex: index)),
                "lower": .null, "upper": .null
            ])
        })
    }

    func zoneThreshold(isPace: Bool) -> OverlayComponentValue {
        guard let snapshot = zoneSnapshot else { return .null }
        let value = isPace ? snapshot.thresholdPaceSecPerKm : snapshot.thresholdHR
        guard let value, !isPace || value > 0 else { return .null }
        let index = isPace
            ? Self.paceZoneIndex(pace: Double(value), snapshot: snapshot)
            : Self.heartRateZoneIndex(heartRate: value, snapshot: snapshot)
        guard let index else { return .null }
        guard var result = zoneValue(index: index, snapshot: snapshot, isPace: isPace, value: Double(value)).record else {
            return .null
        }
        result["valueText"] = .string("T")
        return .record(result)
    }

    func zoneValue(index: Int, snapshot: HeartRateZoneSnapshot, isPace: Bool, value: Double) -> OverlayComponentValue {
        guard var result = Self.zoneRecord(index: index, snapshot: snapshot, isPace: isPace).record else {
            return .null
        }
        let lower = result["lower"]?.number
        let upper = result["upper"]?.number
        let fraction: Double
        if let lower, let upper, (isPace ? lower != upper : upper > lower) {
            fraction = min(max((value - min(lower, upper)) / abs(upper - lower), 0), 1)
        } else {
            fraction = 0.5
        }
        result["fraction"] = .number(fraction)
        result["value"] = .number(value)
        result["valueText"] = .string(isPace
            ? "\(PaceConversion.format(secondsPerKm: Int(value.rounded()), unit: snapshot.paceUnit)) \(snapshot.paceUnit.label)"
            : "\(Int(value)) bpm")
        return .record(result)
    }
}

/// Mirrors the native interval HUD/countdown/summary text conventions, including
/// rounding before pace-unit conversion and summary-specific missing units.
enum OverlayWorkoutFormatting {
    static func duration(_ duration: Double) -> String {
        let total = max(Int(duration.rounded()), 0)
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func distance(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.2f km", meters / 1000) : "\(Int(meters.rounded())) m"
    }

    static func summary(lap: LapRecord, imperial: Bool) -> OverlayComponentValue {
        var records: [String: OverlayComponentValue] = [:]
        for metric in IntervalWorkSummaryMetric.allCases {
            let value: String
            let unit: String
            switch metric {
            case .lapTime:
                value = duration(lap.totalElapsedTime); unit = ""
            case .lapPace:
                let pace = lap.avgPaceSecondsPerKm ?? (lap.totalDistanceMeters > 0
                    ? lap.totalElapsedTime / (lap.totalDistanceMeters / 1000) : nil)
                if let pace, pace > 0 {
                    let paceUnit: PaceUnit = imperial ? .minPerMile : .minPerKm
                    value = PaceConversion.format(secondsPerKm: Int(pace.rounded()), unit: paceUnit)
                    unit = paceUnit.label
                } else {
                    value = "--:--"; unit = imperial ? "/mi" : "/km"
                }
            case .lapDistance:
                if imperial {
                    value = String(format: "%.2f", lap.totalDistanceMeters / 1609.344); unit = "mi"
                } else if lap.totalDistanceMeters >= 1000 {
                    value = String(format: "%.2f", lap.totalDistanceMeters / 1000); unit = "km"
                } else {
                    value = "\(Int(lap.totalDistanceMeters.rounded()))"; unit = "m"
                }
            case .avgHeartRate: value = lap.avgHeartRate.map(String.init) ?? "--"; unit = "bpm"
            case .maxHeartRate: value = lap.maxHeartRate.map(String.init) ?? "--"; unit = "bpm"
            case .avgPower: value = lap.avgPowerWatts.map(String.init) ?? "--"; unit = "W"
            case .avgCadence: value = lap.avgCadenceSPM.map(String.init) ?? "--"; unit = "spm"
            }
            records[metric.rawValue] = .record([
                "value": .string(value), "unit": .string(unit), "label": .string(metric.shortLabel)
            ])
        }
        return .record(records)
    }
}
