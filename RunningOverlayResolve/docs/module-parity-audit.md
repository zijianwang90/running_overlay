# Module Parity Audit

Audit of where each Resolve overlay module lives and how it compares with the Mac
app. This complements [Mac App Feature Parity](mac-app-parity.md); it does not
replace its statuses or release gates.

## Baseline

| Item | Value |
|---|---|
| Audited commit | `c4cf97f` |
| Date | 2026-11-01 |
| Working tree | Dirty. Other agents were editing code concurrently. |
| Method | Read-only inspection. No builds, tests, or host runs. |
| Inventory | 34 rows: 21 numeric, 10 featured, 3 decor. |

The audit started with these uncommitted paths:

```text
M  RunningOverlayResolve/fusion/Fuses/RunningOverlayNumeric.fuse
M  RunningOverlayResolve/src/activity/fit-parser.js
M  RunningOverlayResolve/test/fit-parser.test.js
M  RunningOverlayResolve/test/numeric-renderer.test.js
M  RunningOverlayResolve/test/widget-panel.test.js
M  RunningOverlayResolve/workflow-plugin/index.html
M  RunningOverlayResolve/workflow-plugin/main.js
M  RunningOverlayResolve/workflow-plugin/preload.js
M  RunningOverlayResolve/workflow-plugin/renderer.js
M  RunningOverlayResolve/workflow-plugin/styles.css
?? RunningOverlayResolve/docs/calories-fallback.md
?? RunningOverlayResolve/docs/solid-color-border.md
?? RunningOverlayResolve/docs/weather-panel.md
```

`RunningOverlayNumeric.fuse` was 3552 lines during the audit. Line numbers below
were re-checked against that working tree, but concurrent edits can move them.
During the audit, `docs/mac-app-parity.md`, `docs/testing.md` and
`docs/user-guide.zh-CN.md` also changed. Re-run this audit after the batch lands.

Host claims are limited to what [Testing](testing.md) records. "Covered" means
code exists; it does not imply Resolve host validation.

## Shared References

### Numeric baseline

Every numeric row uses the same Mac model, style, formatter, and renderer, plus
the same Resolve Fuse and control plane. The per-row tables add only the
metric-specific branch.

| Layer | Reference |
|---|---|
| Mac element catalog | `Sources/RunningOverlay/Overlay/OverlayElement.swift:34-224` |
| Mac style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:665-1343` |
| Mac formatter | `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift:3-617` |
| Mac activity accessors | `Sources/RunningOverlay/FitData/ActivityTimeline.swift:169-288` |
| Mac SwiftUI renderer | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:1342-2159` |
| Mac export dispatch | `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift:146-229` |
| Resolve Fuse | `RunningOverlayResolve/fusion/Fuses/RunningOverlayNumeric.fuse` |
| Resolve metric IDs | `RunningOverlayNumeric.fuse:806-831` |
| Resolve value formatting | `RunningOverlayNumeric.fuse:542-619` (`metric_text`) |
| Resolve numeric renderer | `RunningOverlayNumeric.fuse:1953-2015` (`render_widget`) |
| Resolve per-slot controls | `RunningOverlayNumeric.fuse:1765-1821` |
| Resolve text options | `RunningOverlayNumeric.fuse:1240-1305` (`text_options`) |
| Resolve activity TSV | `RunningOverlayResolve/src/io/render-data.js:11-29`, `:43-73` |
| Resolve widget catalog | `RunningOverlayResolve/src/domain/widgets.js:5-11` |
| Resolve apply script | `RunningOverlayResolve/src/resolve/fusion-script.js:38-238` |
| Resolve panel widget list | `RunningOverlayResolve/workflow-plugin/renderer.js:19-24`, `:474-506` |

Shared numeric behavior: value, fixed metric label, unit, unit combos, custom
label, show-unit, label/unit attachment position/alignment/spacing/size/font/
style/color, icon enable/glyph/position/alignment/size/spacing/color, layered
shadow, per-slot value size/font/style/color, and top-left anchoring at
`Position` (`RunningOverlayNumeric.fuse:1976-1982`). New slots seed a subset of
template style fields once (`fusion-script.js:140-148`).

Shared numeric gaps, named after the Mac fields:

| Code | Missing Mac field or concept | Mac reference |
|---|---|---|
| N1 | `textPreset`, `OverlayPresetTokens` | `OverlayElement.swift:3222-3460` |
| N2 | `backgroundEnabled`, `backgroundColor`, `backgroundRadius`, `backgroundPaddingX/Y`, `backgroundFadeOutEnabled/Amount`, `backgroundBlurRadius`, `borderEnabled/Color/Opacity/Width`, `glowEnabled/Color/Intensity`, `rotationDegrees`, `textAlignment`, `numericMinWidth/Height` | `OverlayElement.swift:768-817` |
| N3 | `valueColorsFollowHeartRateZones`, `labelColorsFollowHeartRateZones`, `unitColorsFollowHeartRateZones`, `iconColorsFollowHeartRateZones`, `textColorsFollowHeartRateZones` | `OverlayElement.swift:755-767`, `:821` |

## Numeric Overlays

| Element | Mac formatter / timeline | Resolve branch |
|---|---|---|
| Heart Rate | `OverlayValueFormatter.swift:89-95`; `ActivityTimeline.swift:192-194` | `metric_text:544-545` |
| HR Zone | `OverlayValueFormatter.swift:96-115` | `metric_text:600-601`; classifier `:1010-1020` |
| Pace | `OverlayValueFormatter.swift:116-123` | `metric_text:546-548` |
| Avg Pace | `OverlayValueFormatter.swift:124-131` | `metric_text:565-570` |
| Lap Pace | `OverlayValueFormatter.swift:132-139`; `ActivityTimeline.swift:209-216` | `metric_text:602-616` |
| Calories | `OverlayValueFormatter.swift:140-146`; `ActivityTimeline.swift:254-256` | `metric_text:563-564` |
| Elapsed Time | `OverlayValueFormatter.swift:147-153`; `ActivityTimeline.swift:173-179` | `metric_text:552-556` |
| Real Time | `OverlayValueFormatter.swift:154-160`, `:312-317` | `metric_text:593-595` |
| Date | `OverlayValueFormatter.swift:161-167`, `:319-331` | `metric_text:596-597` |
| Distance | `OverlayValueFormatter.swift:168-175`; `ActivityTimeline.swift:188-190` | `metric_text:549-551` |
| Elevation | `OverlayValueFormatter.swift:178-198`; `ActivityTimeline.swift:218-220` | `metric_text:557-558` |
| Cadence | `OverlayValueFormatter.swift:201-207`; `ActivityTimeline.swift:246-248` | `metric_text:559-560` |
| Power | `OverlayValueFormatter.swift:208-214`; `ActivityTimeline.swift:250-252` | `metric_text:561-562` |
| Vertical Oscillation | `OverlayValueFormatter.swift:229-230`; `ActivityTimeline.swift:258-260` | `metric_text:571-574` |
| Ground Contact Time | `OverlayValueFormatter.swift:231-238`; `ActivityTimeline.swift:262-264` | `metric_text:575-576` |
| Stride Length | `OverlayValueFormatter.swift:239-246`; `ActivityTimeline.swift:266-268` | `metric_text:577-578` |
| Vertical Ratio | `OverlayValueFormatter.swift:247-254`; `ActivityTimeline.swift:270-276` | `metric_text:579-581` |
| GCT Balance | `OverlayValueFormatter.swift:255-268`; `ActivityTimeline.swift:278-280` | `metric_text:582-584` |
| Temperature | `OverlayValueFormatter.swift:269-272`; `ActivityTimeline.swift:282-284` | `metric_text:585-590` |
| Grade | `OverlayValueFormatter.swift:273-280`; `ActivityTimeline.swift:286-288` | `metric_text:591-592` |
| Custom Numeric | `OverlayValueFormatter.swift:281-282`, `:333-501`; model `OverlayElement.swift:396-484` | `metric_text:598-599`; `custom_numeric_text:524-541` |

| Element | Covered today | Gaps | Tests |
|---|---|---|---|
| Heart Rate | Integer bpm; `--` when missing; Heart icon. | N1, N2, N3. | `test/numeric-renderer.test.js:22`, `:46`, `:933` |
| HR Zone | `Z1`…`Z6` from per-instance inclusive ranges; `--` when missing. | N1, N2, N3; no Mac global `HeartRateZonePreferences`; zone palette is fixed in the Fuse. | `test/numeric-renderer.test.js:933`, `:947`; host `testing.md:891-900` |
| Pace | min/km, min/mi, min/500m; missing pace `--'--"`. | N1, N2. | `test/numeric-renderer.test.js:22`, `:46` |
| Avg Pace | Real elapsed ÷ distance with pace units. | N1, N2. | `test/numeric-renderer.test.js:198` |
| Lap Pace | Current lap start to sampled record; `--` before a lap or with no lap messages. | N1, N2; depends on device lap messages. | `test/numeric-renderer.test.js:107`; host `testing.md:284-308` |
| Calories | Direct record value; parser now falls back to lap totals then session total (`src/activity/fit-parser.js:469-482`). | N1, N2; no estimate provenance flag, matching the Mac model. | `test/fit-parser.test.js:325-401`; `test/numeric-renderer.test.js:22` |
| Elapsed Time | Pause-subtracted elapsed; hh:mm:ss, mm:ss, seconds. | N1, N2. | `test/numeric-renderer.test.js:22`, `:46` |
| Real Time | 24/12-hour from activity start with per-instance UTC offset; seconds truncated. | N1, N2; per-instance offset instead of Mac device timezone (documented difference). | `test/numeric-renderer.test.js:231`, `:247`; host `testing.md:414-443` |
| Date | Six `en_US_POSIX` patterns with the instance offset. | N1, N2. | `test/numeric-renderer.test.js:1194`; host `testing.md:867-890` |
| Distance | km, mi, m; two decimals except metres. | N1, N2. | `test/numeric-renderer.test.js:22`, `:46` |
| Elevation | Current elevation in m/ft. | N1, N2; `elevationDisplayMode` (`.gain`) missing (`OverlayElement.swift:382-394`). | `test/numeric-renderer.test.js:22`, `:198` |
| Cadence | Integer spm. | N1, N2. | `test/numeric-renderer.test.js:22`, `:198` |
| Power | Integer W. | N1, N2. | `test/numeric-renderer.test.js:22`, `:198` |
| Vertical Oscillation | cm/mm. | N1, N2. | `test/numeric-renderer.test.js:198` |
| Ground Contact Time | Integer ms. | N1, N2. | `test/numeric-renderer.test.js:198` |
| Stride Length | Metres, two decimals. | N1, N2; metres only, as on Mac. | `test/numeric-renderer.test.js:198` |
| Vertical Ratio | Derived from oscillation and stride; `--` at zero stride. | N1, N2. | `test/numeric-renderer.test.js:198` |
| GCT Balance | Right-side encoding normalised to left percent. | N1, N2. | `test/numeric-renderer.test.js:198` |
| Temperature | FIT, FIT-else-manual, manual; °C/°F. | N1, N2. | `test/numeric-renderer.test.js:198` |
| Grade | FIT field; GPX derived within a segment. | N1, N2. | `test/numeric-renderer.test.js:198` |
| Custom Numeric | 19 record sources; number/integer/duration/clock/date/pace/percent/coordinate; precision 0–4; custom unit/label. | N1, N2; missing `heartRateZone`, `lapPace`, `elevationGain`, and `record(String)` sources (`OverlayElement.swift:431-484`). | `test/numeric-renderer.test.js:1194`; host `testing.md:867-890` |

The approved missing-sample difference remains in force: Resolve interpolates
only between adjacent records that both carry a field; it never invents values
across a gap (`mac-app-parity.md:77-82`).

## Featured Overlays

### Distance Timeline

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:2111-2679`; preset `:1345-1381` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:95-222` |
| Mac renderer | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:2552-2999` |
| Resolve controls | `RunningOverlayNumeric.fuse:1308-1426` (`timeline_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:2026-2435` (`render_timeline`) |
| Resolve data/apply | `src/io/render-data.js:43-73`; `src/resolve/fusion-script.js:38-238` |

Covered: label text/font/style/size/color/spacing; four custom values with
metric, label, visibility, gaps, size, color and opacity; marker label placement
and gap; background color/opacity/corner/padding; border color/opacity/width;
four-slot stats bar with placement, inside grouping, width/height, offsets, gap,
divider, corner, background, value/label fonts/sizes/colors/opacity; axis modes,
endpoint and distance-point labels/placement/gaps/fonts; ticks and density;
marker styles Dot/Pill/Triangle, size and color; glow; presets Custom, Minimal,
Dense, Sport, Splits, Glass, Neon, Lower Third and Route; independent elevation
profile; km/mi.

Gaps: `showPercent`; `fadeEnabled`, `fadeEdge`, `fadeAmount`; media-slot asset
fields `mediaSlotEnabled`, `mediaSlotMode`, `mediaSystemImage`, `mediaSlotSize`,
`mediaSlot` (Sport currently draws a deterministic accent tile,
`RunningOverlayNumeric.fuse:2046-2053`); stats metrics `lapPace` and `realTime`;
exact preset typography; GPS route variant. Host evidence covers 1080p only;
preset variants and UHD are Lua-only.

Tests: `test/numeric-renderer.test.js:439`, `:487`, `:652`, `:696`, `:1238`;
host `testing.md:62-113`.

### Elevation Chart

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:1385-1803` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:274-347` |
| Mac renderer | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:3042-3427` |
| Resolve controls | `RunningOverlayNumeric.fuse:1690-1712` (`elevation_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:2819-2891` (`render_elevation`) |
| Resolve profile data | `RunningOverlayNumeric.fuse:199-311`; `src/io/render-data.js:11-29` |

Covered: full-profile smoothed gradient area, line-only when fill is off, cursor,
guide, value label, line/fill/lower colors, fill opacity, chart opacity, size and
padding, fixed 0.85 smoothing, `NO ELEVATION` for a missing profile and cursor
suppression when current elevation is missing.

Gaps: `preset` (`dualArea`, `techGlow`, `minimalWhite`, `bigNumbers`);
`chartStyle` beyond fill on/off; `progressMode` (`progressToCurrent`);
`smoothingAmount`; `dualAreaEnabled`; `gridEnabled`; `axisLineEnabled`;
`axisLabelsEnabled`; `bigNumbersEnabled`, `bigNumberMetric` and big-number font;
`markerLabelEnabled`; `markerPlayheadLineEnabled`; `background*`; `border*`;
`glow*`; `statsBar`; per-role typography.

Tests: `test/numeric-renderer.test.js:1058`, `:1075`, `:1106`; host
`testing.md:352-383`; UHD remains Lua-only (`testing.md:99-113`).

### Running Gauge

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift:9-909`; style `:321-448`; layouts `:194-240`; progress modes `:242-267`; layout engine `:804-909` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:453-506` |
| Mac renderer | `Sources/RunningOverlay/UI/PreviewCanvasView.swift:2161-2303` |
| Resolve controls | `RunningOverlayNumeric.fuse:1549-1582` (`gauge_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:3036-3149` (`render_gauge`) |

Covered: dial, outer ring, ticks with major interval, four fixed regions
(top/middle-left/middle-right/bottom), dividers, distance/time progress ring,
colors, opacities, widths, labels and accent color.

Gaps: `stylePreset`; `layoutPreset` (seven Mac layouts versus four fixed regions);
per-region `RunningGaugeRegionConfig` values, labels, units, typography and
positions; `glassEffectEnabled`; `progressRoundedCaps`; `dividerWidth`;
`monospacedDigits`; `fontName` and font weights; `primaryTextColor` and
`secondaryTextColor`; `glow*`. Progress modes 3–5 (HR Zone, Power Zone, Pace
Intensity) fall back to elapsed time, matching the Mac app's
`computeGaugeProgress` placeholder (`OverlayRenderModel.swift:1778-1786`).
Custom 50% was a real defect: it is combo index 6, but the renderer checked
`mode == 7`, so it rendered elapsed time and index 7 was unreachable
(`RunningOverlayNumeric.fuse:1566-1567`, `:3080-3089`). Fixed in v25; the ring
now uses 0.5 for index 6.

Tests: `test/numeric-renderer.test.js:1009`; host `testing.md:901-913`
(distance/time only).

### Interval HUD Bar

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/IntervalHUDBarModel.swift:3-658`; style `:288-507`; layout `:524-561` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:508-599` |
| Mac renderer | `Sources/RunningOverlay/UI/IntervalHUDBarOverlayView.swift:3-599` |
| Resolve controls | `RunningOverlayNumeric.fuse:1583-1609` (`interval_hud_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:3241-3290` (`render_interval_hud`) |
| Resolve lap/workout data | `src/io/render-data.js:60-71` |

Covered: card size/corner/background/opacity; phase, rep and remaining text;
time/distance detail per work and rest; phase/value/label sizes; bottom bar time
or distance progress; track colors and opacities.

Gaps: `showsZone`, `zoneDisplayMode`, zone segments and markers
(`activeZoneWidthShare`, `activeZoneHeightScale`, `zoneSegmentGap`,
`zoneMarkerEnabled`, `zoneMarkerPosition`, `zoneMarkerShowsValue`,
`thresholdZoneMarkerEnabled`); `metricSlots` plus metric value/unit text;
`hrDropMode`; `remainingPrimary`; `bottomBarMode`; `bottomBarGlowEnabled`;
bottom-bar border fields; per-role text styles (`labelText`,
`primaryValueText`, `phaseText`, `phaseDetailText`, `metricValueText`,
`metricUnitText`); `phaseColorFallback`. The center label is hardcoded `"LEFT"`
in both apps (`RunningOverlayNumeric.fuse:3273`;
`OverlayRenderModel.swift:552`), so it is parity rather than a Resolve defect.

Tests: `test/numeric-renderer.test.js:127`; host `testing.md:255-283`.

### Interval Timeline

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/IntervalTimelineModel.swift:3-435`; style `:77-397`; layout `:398-424` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:809-972` |
| Mac renderer | `Sources/RunningOverlay/UI/IntervalTimelineOverlayView.swift:3-175` |
| Resolve controls | `RunningOverlayNumeric.fuse:1610-1633` (`interval_timeline_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:3291-3359` (`render_interval_timeline`) |

Covered: full-lap proportional segments by time or distance, phase colors,
segment labels, current-segment scale, completed/future opacity, current marker,
background, padding, gap and corner radius.

Gaps: `mode` (centred window), `visibleNeighbors`, `fullSegmentLayoutMode`,
`showsRestSegments`, `showsWarmupSegments`, `showsCooldownSegments`,
`segmentHeight`, `currentSegmentWidthFraction`,
`fullEqualCurrentSegmentWidthFraction`, `minSegmentWidth`, `edgeFadeEnabled`,
`currentProgressEnabled`, `markerLabelEnabled`, `markerLabel`, `markerPosition`,
`repCounterEnabled`, `overflowHintEnabled`, per-kind color fields, label metric
modes and per-role typography.

Tests: `test/numeric-renderer.test.js:127`; host `testing.md:255-283`.

### Interval Countdown

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/IntervalCountdownModel.swift:3-260`; style `:149-231`; layout `:232-260` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:601-686` |
| Mac renderer | `Sources/RunningOverlay/UI/IntervalCountdownOverlayView.swift:3-178` |
| Resolve controls | `RunningOverlayNumeric.fuse:1634-1658` (`interval_countdown_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:3360-3424` (`render_interval_countdown`) |

Covered: ring and track, phase-following or custom color, ring direction, center
time or distance, remaining or elapsed, helper/phase/rep/caption toggles, and
per-role sizes.

Gaps: `roundedLineCap`; `ringGlowEnabled`, `ringGlowIntensity`; per-role
`IntervalCountdownTextStyle` for helper, phase, rep, countdown and caption. The
ring fraction always uses `values.time_progress`, even when `centerMetric` is
distance (`RunningOverlayNumeric.fuse:3379`). The Mac app also drives the ring
from time progress regardless of the center metric
(`OverlayRenderModel.swift:611-621`), so this is parity rather than a defect.

Tests: `test/numeric-renderer.test.js:127`; host `testing.md:255-283`.

### Interval Work Summary

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/IntervalWorkSummaryModel.swift:3-284`; style `:159-250`; layout `:259-284` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:688-758` |
| Mac renderer | `Sources/RunningOverlay/UI/IntervalWorkSummaryOverlayView.swift:3-186` |
| Resolve controls | `RunningOverlayNumeric.fuse:1659-1689` (`interval_summary_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:3453-3499` (`render_interval_summary`) |

Covered: last completed active lap; display window; primary metric plus three
secondary metrics; summary label; metric/imperial units; divider; accent
following phase or custom; sizes; background.

Max HR is now carried from FIT lap field 16 through lap row field 13 into the
summary renderer (v25). Remaining gaps: custom secondary labels and visibility
(`IntervalWorkSummarySlot`); component-label
alignment; divider color and width; per-role text styles.

Tests: `test/numeric-renderer.test.js:127`; host `testing.md:255-283`.

### Zone Edge Bar

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/ZoneEdgeBarModel.swift:3-131`; style `:63-112`; layout `:113-131` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:760-807` |
| Mac renderer | `Sources/RunningOverlay/UI/ZoneEdgeBarOverlayView.swift:3-335` |
| Resolve controls | `RunningOverlayNumeric.fuse:1488-1524` (`zone_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:2724-2818` (`render_zone`) |

Covered: five or six editable HR ranges; bottom/top/left/right/free placement;
orientation; length, thickness, inset, gap and corner; active width share and
height scale; inactive opacity; current-HR marker and value; threshold marker;
labels; border; glow; fixed zone palette.

Gaps: `metric` `.pace` (only HR is classified); marker text style fields
(font, size, color); the Mac app's global `HeartRateZonePreferences` instead of
per-instance ranges; no pace-zone classification.

Tests: `test/numeric-renderer.test.js:1028`; host `testing.md:352-383`.

### Route Map

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:668-707`; enums `:2698-3196` |
| Mac layout/renderer | `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift:9-448`; `OverlayRenderModel.swift:1790-2033`; `PreviewCanvasView.swift:959-1340` |
| Resolve controls | `RunningOverlayNumeric.fuse:1427-1487` (`route_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:2440-2723` (`render_route`) |
| Resolve map fetch | `src/map/mapbox.js:11-167` |
| Resolve panel | `workflow-plugin/renderer.js:706-717`, `:723-737` |
| Resolve bundle | `src/io/render-data.js:182-233`; `src/resolve/fusion-script.js:189-215` |

Covered: FIT/GPX trace, offline Mercator geometry, time-driven cursor, endpoints,
cached Mapbox snapshot and four detail tiles, follow camera, 1–8× zoom,
course-up, direction arrow, attribution, card shapes, edge feather, all four
container presets, four-slot stats bar and its styling.

Gaps: MapKit provider; `backgroundStyle` dark/light/terrain/satellite (only a
Mapbox snapshot); marker styles `pin` and `flag`; `legendMode`; `colorMode`
beyond the single route colour; stats metrics `lapPace` and `realTime`; live
tiles; per-role stats typography. Host evidence is 1080p only.

Tests: `test/numeric-renderer.test.js:529`, `:552`, `:582`, `:609`, `:750`,
`:807`, `:874`; `test/mapbox.test.js`; host `testing.md:3-61`.

### Weather Widget

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:3685-4402` |
| Mac layout | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:2608-2767` |
| Mac renderer | `Sources/RunningOverlay/UI/WeatherWidgetViews.swift:23-764` |
| Resolve controls | `RunningOverlayNumeric.fuse:1713-1747` (`weather_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:2892-2988` (`render_weather`) |
| Resolve weather library | `src/weather/weather.js:75-283` |
| Resolve panel/IPC | `workflow-plugin/renderer.js:571-693`; `main.js:99-110`; `preload.js:8-9` |
| Resolve bundle | `src/io/render-data.js:43-73`, `:182-233` |

Covered: SimpleCard layout; condition, original condition icon, location,
weekday and humidity; °C/°F; FIT temperature override; card gradient, opacity,
corner, border and divider; text colour and sizes; offline cached snapshot;
sunny/`--` placeholder; panel location search and 7-day forecast preview.

Gaps: `preset` (`compactStrip`, `forecastTile`, `minimalText`, `dashboardBar`);
`palette`; `showHighLow`, `showWind`, `showFeelsLike`; `metricSlots`;
`manualCondition`, `manualTemperatureCelsius`, `manualHumidity`, `manualHigh`,
`manualLow`, `manualWind`, `manualFeelsLike`; `conditionLabelOverride`;
`dataSource`; per-role `WeatherTextStyle`; slot backgrounds. Panel forecasts are
preview-only and are not saved (`weather-panel.md`).

Tests: `test/numeric-renderer.test.js:1116`, `:1164`; `test/weather.test.js`;
`test/widget-panel.test.js`; host `testing.md:309-331` (archive card).

## Decor Overlays

### Solid Color

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:3557-3637` |
| Mac layout/renderer | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:2197-2260`; `UI/DecorOverlayViews.swift:22-60` |
| Resolve controls | `RunningOverlayNumeric.fuse:1525-1548` (`decor_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:2989-3011` (`render_decor`) |

Covered: rectangle, rounded rectangle and circle; width/height/corner radius;
fill RGBA; border width/colour/opacity.

Gaps: `DecorShape.capsule`; `glowEnabled`, `glowColor`, `glowIntensity` and the
shadow fields applied by `DecorSolidColorOverlayView.swift:40-57`. Border host
rendering has not been checked (`testing.md:1-25`).

Tests: `test/numeric-renderer.test.js:962`, `:982`; host `testing.md:914-930`
(pre-border); border has Node coverage only.

### Icon

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:3588-3637` (`iconAsset`, `iconTint`, `iconPreserveSVGColors`, `iconContentMode`) |
| Mac layout/renderer | `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift:2197-2260`; `UI/DecorOverlayViews.swift:121-176` |
| Resolve controls | `RunningOverlayNumeric.fuse:1533-1537` (`decor_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:3012-3018`; glyph table `:771-805` |

Covered: 17 project-owned vector glyphs; size and tint.

Gaps: `iconAsset` (SVG/PNG), `iconPreserveSVGColors`, `iconContentMode`. These
are intentionally unsupported for licensing and asset-pipeline reasons
(`mac-app-parity.md:74`).

Tests: `test/numeric-renderer.test.js:380`, `:412`, `:962`; host
`testing.md:914-930`.

### Text

| Layer | Reference |
|---|---|
| Mac model/style | `Sources/RunningOverlay/Overlay/OverlayElement.swift:3588-3637` (`textFont`, `textLineHeight`, `textLetterSpacing`, `textFillMode`, `textStrokeWidth`, `textStrokeColor`, `textAutoFit`) |
| Mac renderer | `Sources/RunningOverlay/UI/DecorOverlayViews.swift:189-278` |
| Resolve controls | `RunningOverlayNumeric.fuse:1540-1544` (`decor_options`) |
| Resolve renderer | `RunningOverlayNumeric.fuse:3019-3031` |

Covered: single-line text, size, colour, left/centre/right alignment; newlines
are collapsed to spaces.

Gaps: `textFont`; multiline and `textLineHeight`; `textLetterSpacing`;
`textFillMode` gradient fill; `textStrokeWidth` and `textStrokeColor`;
`textAutoFit`. The Mac text element is itself a placeholder
(`mac-app-parity.md:75`).

Tests: `test/numeric-renderer.test.js:962`; host `testing.md:914-930`.

## Cross-Cutting Gaps

| Area | Evidence | Gap |
|---|---|---|
| Units and formatting | Metric branches in `RunningOverlayNumeric.fuse:542-619`; unit combos `:1244-1253`; formatter tests `test/numeric-renderer.test.js:22`, `:198`, `:231`. | `elevationDisplayMode` gain; Custom Numeric sources `heartRateZone`, `lapPace`, `elevationGain`, `record(String)`; stats bars omit `lapPace` and `realTime` (`RunningOverlayNumeric.fuse:813-815` versus `OverlayElement.swift:2895-2993`). |
| Templates and style propagation | Built-in templates and saved library `src/domain/templates.js:16-124`; Mac import positions only `src/domain/user-templates.js:63-70`; one-time style seeding `src/resolve/fusion-script.js:140-148`. | No Mac style conversion or asset provenance; `.rotemplate` import sets `stylesImported: false`; style changes are refused on split overlays (`src/workflow/service.js:171`, `src/resolve/managed-overlay.js:12`, `:64`). |
| Project persistence | Per-context JSON store `src/workflow/configuration.js:106-126`; immutable bundle plus manifest `src/io/render-data.js:182-233`; user settings separate `src/workflow/settings.js:25-63`. | No relink or missing-bundle diagnostics; cross-machine handoff and reopen are recorded only for the local project (`testing.md:729-761`). |
| Preview/export matrix | Same Fuse feeds viewer and Deliver; export evidence `testing.md:532-553`, `:703-771`. | Host evidence is a short 1080p ProRes 4444 alpha composite; UHD, non-16:9 and presets are Lua-only (`testing.md:99-113`); no color-management, full-length, or rational-frame-rate matrix. |
| Install and upgrade | `scripts/assemble.mjs:26-30`; manual install and restart `README.md:57-73`; legacy token migration `src/workflow/service.js:45`; slot adoption `src/resolve/fusion-script.js:72-73`, `:115`. | No version compatibility check, signed installation, upgrade recovery or licensing documentation; `package.json` stays at `0.1.0`. |
| Undo | Fusion transactions for data update `src/resolve/fusion-script.js:79`, `:235` and time offset `:262-264`; Inspector edits use Fusion's own undo. | No recorded host undo acceptance; discrete versus continuous gesture contract is not verified (`testing.md:762-771`). |
