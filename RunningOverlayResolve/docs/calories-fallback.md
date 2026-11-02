# Calories Fallback

Last updated: 2026-11-01

## Purpose

Some devices omit the per-record calorie field (`record` field 33) but still
write activity totals in the session or lap messages. The Resolve FIT parser now
fills record calories from those totals so the Calories widget shows a value,
matching the Mac app's `FitFileParser.recordsWithEstimatedCalories`
(`Sources/RunningOverlay/FitData/FitFileParser.swift`).

## Precedence

1. **Direct record calories** — if any normalized record has a numeric
   `calories`, every record keeps its own value and no fallback runs. Records
   without a direct value stay `null`, exactly as the Mac app behaves.
2. **Lap totals** — when no record has direct calories and at least one FIT lap
   message carries `total_calories` (lap field 11), records are estimated from
   the cumulative lap totals.
3. **Session total** — otherwise, when the session message carries
   `total_calories` (session field 11) and the activity duration is positive,
   records are spread proportionally over elapsed time.
4. **No estimate** — without session or lap totals, records keep
   `calories: null`; the parser never invents a value.

A FIT `0xffff` uint16 sentinel is treated as absent for both session and lap
totals, as for every other uint16 field.

## Formulas

### Lap totals

Lap messages are read in FIT message order. Degenerate laps (elapsed time `<= 0`
and distance `<= 0`) are skipped. For each remaining lap:

- `start` = `max(lapStart − activityStart, 0)`, or the previous lap's end when
  the lap has no start timestamp;
- `end` = `start + lapTotalElapsedTime`;
- `startCalories` = calories accumulated by the previous laps;
- `endCalories` = `startCalories + lapTotalCalories` (`0` when the lap omits the
  field).

A record at elapsed time `t` receives the cumulative calories:

```text
t <= first.start                 -> first.startCalories
first.start < t <= seg.end       -> seg.startCalories
                                    + (seg.endCalories - seg.startCalories)
                                      * clamp((t - seg.start) / (seg.end - seg.start), 0, 1)
t > last.end                     -> last.endCalories
```

This is the Mac `estimatedCalories(at:segments:)` rule. Cumulative values mean
the calories added across each lap equal that lap's total, and the final value
equals the sum of all lap totals. A record between two laps, or after the last
lap, holds the surrounding cumulative total rather than `null`; that is the Mac
behavior and is intentional for parity.

No estimate is produced when no lap has a numeric total, or when the summed lap
calories are `<= 0`; the session rule then applies.

### Session total

```text
calories = sessionCalories * clamp(elapsedUs / durationUs, 0, 1)
```

`durationUs` is the activity duration already computed by the parser:
`max(session elapsed time, last record elapsed time, last timer-event elapsed
time)`. The Mac app uses the session elapsed time when present, otherwise
`max(last record elapsed, 1)`, so a FIT file whose records run past the session
duration can scale slightly differently; the Resolve duration is the one used
for `endUtcUs`, so the estimate stays consistent with the activity timeline.

## Estimated Versus Recorded Values

Estimates are inferred, not recorded. The activity schema has no field that
marks an estimated calorie value, and this change does not add one (schema
changes are out of scope). The renderer therefore cannot distinguish an
estimate from a recorded value, and the widget shows the number unmarked.

The Mac app has the same limitation: `ActivityRecord.calories` is a single
optional value with no provenance flag. This is a known limitation of both
implementations, not a Resolve-only gap.

## Records Outside Laps

Once lap totals exist, every record receives a value — records outside the lap
coverage inherit the nearest cumulative total (see above). Records stay `null`
only when neither record, lap nor session calories are available.

## Tests

```sh
cd RunningOverlayResolve && node --test test/fit-parser.test.js
```

The focused tests cover direct-value precedence, session proportionality and
clamping, cumulative lap interpolation with preserved lap totals, records
between and after laps, lap-over-session precedence, absent totals, and input
immutability.
