# Running Overlay Project Log

## 2026-06-16

### Interval Timeline Neighbor Label Off

- Added `Off` to the Interval Timeline `Neighbor` label control so non-current segments can render without any text while current segment labels remain independently configurable.
- Updated interval timeline docs/spec and render-model coverage for hidden neighbor labels.
- Limited the Interval Timeline rep counter to active laps only, so warmup, rest, cooldown, and unknown current segments no longer display `Rep n / total`.

### Easy Run Default Template

- Replaced the bundled `EasyRun.rotemplate` resource with the current local user template named `Template`, so the Built-in Templates `Easy Run` row applies that authored layout.
- Renamed the bundled Easy Run template payload from `Template` to `Easy Run` and normalized its font references to the default Font Library families: `PT Mono` and `Monaco`.
- Updated the fresh-install Font Library default set to `PT Mono`, `Monaco`, `Menlo`, and `Andale Mono`, with `PT Mono` as the default family.
- Verification: `swift test --filter OverlayTemplateTests`, `swift test --filter ProjectSettingsTests`.

## 2026-06-15

### Weather Widget Initial API Data

- Changed newly added Weather Widget overlays to start in Open-Meteo mode with no built-in sample city text or sample weather values.
- Adding a Weather Widget now automatically requests historical weather for the current FIT activity's first GPS route point when a route is available.
- Preview/export render `--` placeholders for Open-Meteo weather fields until a cached payload is available, instead of falling back to demo values such as Osaka/13°C.
- Manual Inspector fetches still create undo history, while the automatic initial fetch updates the new widget without adding a separate undo step.
- Added coverage for the new placeholder state and default Weather Widget add behavior.
- Verification: `swift test`.

### SwiftUI Preview SF Pro Weight Logging

- Fixed repeated SwiftUI console diagnostics from overlay preview text when the configured font family is `SF Pro` or `SF Pro Display` and a weight such as medium/semibold/bold is applied.
- Added a shared SwiftUI overlay font helper that treats macOS system UI font family aliases as `Font.system(size:weight:)`, while keeping custom font families on `Font.custom(...).weight(...)`.
- Routed Weather Widget, Interval HUD Bar, Interval Timeline, Preview Canvas numeric/stat labels, Distance Timeline, Running Gauge, Route Map, and Elevation Chart preview text through the helper so system UI fonts no longer trigger `Unable to update Font Descriptor's weight` logs during redraw.
- Documented that custom font weight controls depend on the selected font family providing matching weight faces; single-weight families such as Monaco may not visibly change for every weight option.
- Verification: `swift test`.

### Shared SF Symbol Picker

- Added a shared `SFSymbolPicker` for Numeric Overlay icons and Decor Icon SF Symbol assets, replacing fixed preset/common symbol lists with direct text entry plus a searchable popover grid.
- Added `SFSymbolCatalog`, backed by a bundled `Resources/SFSymbols/symbols.json` name catalog generated from public CoreGlyphs symbol order data. Picker results filter through current macOS renderability while preserving manual entry for newer SF Symbols.
- Default picker browsing now starts with sport-relevant symbols, while typed search still scans the full catalog. Renderability checks are cached so repeated searches do not recreate `NSImage` probes for the same symbol names.
- Added catalog tests for full resource loading, sport-first default browsing, full-catalog search, case-insensitive search, renderable picker results, and numeric metric default icon coverage.

### Interval Timeline explicit modes and segment filters

- Removed the user-facing `Max Full` threshold behavior: Centered and Full are now explicit modes, and Full no longer auto-falls back to a centered window for high lap counts.
- Added Full mode segment layout selection with `Equal` as the default and `Duration` preserving the previous duration-proportional geometry; current segment emphasis still affects current height in either Full layout.
- Added independent Timeline toggles for WU, Rest, and CD segments. Filtering is applied before layout, and hidden current segments no longer receive current emphasis while the marker falls back to the nearest visible segment.
- Kept old `maxFullSegments` project data decode-compatible without writing it back in new encoded styles.
- Simplified Centered overflow rendering to ellipsis-only edge hints. Removed WU/CD ghost endpoint labels and `xN` count boxes from preview/export, renamed the Inspector control to `Overflow Hint`, and kept old `overflowPillsEnabled` project data decode-compatible.
- Added `Full + Equal` current width control: the Current `Width` slider starts at `Equal` and can enlarge the current segment's target share while preserving equal-width behavior at the minimum.
- Replaced the old Interval Timeline label mode with direct label controls. Current segments now independently support distance and time rows set to Off, Live, or Remain, while non-current neighbor labels can show either distance or time. Old `primaryLabelMode` and `durationLabelsEnabled` project data remains decode-compatible but is not written back.

### Templates Pool Empty Apply Confirmation

- Applying a built-in or user template from an empty overlay layout now skips the replacement confirmation dialog and applies immediately.
- Existing overlay layouts still show the destructive replacement confirmation before being cleared.
- Files: `Sources/RunningOverlay/UI/TemplatePoolView.swift`, `docs/development.md`, `docs/design/panels/media-pool/media-pool-ui.md`.
- Verification: `swift test --filter OverlayTemplateTests`.

## 2026-05-21

### Route Map MapKit Appearance Lock

- Fixed MapKit snapshot appearance from Route Map background style so map backgrounds no longer switch tone when macOS changes between light and dark appearance.
- `dark` background style now always requests a dark MapKit snapshot; `light`, `terrain`, and `satellite` keep a stable light snapshot appearance.

### Route Map Marker Control Split

- Route Line `Color Mode` now owns the rendered line paint even under the Gradient route style, so Solid color swatches update the line instead of only affecting a preview marker.
- Removed the Route Map inspector's `All Markers` control and split Start, End, and Moving marker style controls; Start and End now have separate persisted color fields while Moving keeps its own color swatches and gains marker style selection.
- Updated preview/export marker rendering plus Route Map module and UI design docs to match the independent marker controls.

### Numeric Overlay Unit Wrapping and Minimum Size

- Kept `TextPresetOverlayView.metricCoreContent` unit text on one line so inline units expand a numeric overlay instead of splitting short unit strings inside a narrow unit column.
- Added `OverlayStyle.numericMinWidth` / `numericMinHeight`, scaled them through `OverlayTextRenderLayout`, and exposed `Min Width` / `Min Height` in the Numeric Overlay Layout inspector. Zero preserves legacy text-driven sizing; the minimal preset background and generic overlay frame honor reserved space.
- Added render-model coverage for numeric minimum-size scaling and updated the numeric overlay design spec plus project requirements.

### Inspector Detail Footer Unification

- Centralized Reset / Done footer background, top separator, horizontal padding, one-third/two-thirds button layout, and fixed height in `InspectorDetailFooterBar`; the footer height now matches the adjacent Preview playback row through a shared theme token.
- Migrated Elevation Chart from its local text footer to the shared footer and removed duplicate per-panel footer divider/padding wrappers from overlay detail views.
- Removed the extra top separator from Elevation Chart custom section headers so collapsed section boundaries stay one thin rule.

### Inspector Section Separator Consistency

- Removed the extra top separator from Weather Widget collapsed section headers so adjacent section boundaries render as a single thin rule.
- Removed the extra top separator from the shared `CollapsibleStatsBarInspectorSection` header so Stats Bar no longer shows a thicker rule than neighboring collapsed Inspector sections.

### Font Library Restore Defaults

- Added a `Restore Defaults` action to Font Library that restores the built-in favorite list and current default font, then clears the active font search so the restored rows are visible.
- Updated the fallback favorite set for new and reset Font Library state to macOS-provided monospaced families: `Menlo` as default, followed by `PT Mono`, `Monaco`, and `Andale Mono` for steadier overlay metrics and time values.

## 2026-05-19

### Weather Widget: typography + slot styling

- New `WeatherTextStyle` struct (`fontName`, `fontSize`, `fontWeight`, `color`) on `WeatherWidgetStyle` for each rendered text element: `locationTextStyle`, `conditionTextStyle`, `temperatureTextStyle`, `slotTitleTextStyle`, `slotLabelTextStyle`. Each preset seeds defaults matching the previous hard-coded font/foreground; design-time sizes scale by `rect.width / style.width` at render time. `applyWeatherWidgetPreset` preserves these across preset switches; decoder uses `decodeIfPresent` against preset defaults so existing projects open unchanged.
- Dashboard Bar slots: added `slotBackgroundColor`, `slotBackgroundOpacity`, `slotSpacing` (the chip pill no longer derives its color from the palette token; spacing between chips is user-controlled).
- Compact Strip and Dashboard Bar now apply `.frame(maxWidth: .infinity, maxHeight: .infinity)` before `weatherCardBackground`, so adjusting overlay height grows the card background instead of leaving a strip floating inside an empty selection rect.
- Inspector: new `Typography` section in `WeatherWidgetOverlayDetailView` exposes Font / Size / Weight / Color (+ Alpha) for each of the five text elements; slot Color/Opacity/Spacing rows live under Appearance and are visible when `preset == .dashboardBar`. Uses existing `InspectorDense*` primitives directly.
- Files: `Sources/RunningOverlay/Overlay/OverlayElement.swift`, `Sources/RunningOverlay/UI/WeatherWidgetViews.swift`, `Sources/RunningOverlay/UI/WeatherWidgetOverlayDetailView.swift`, `Sources/RunningOverlay/Project/ProjectDocument.swift`.

## 2026-05-16

### Overlay Pool: collapse categories to Metrics / Visuals

- `OverlayCategory` reduced from `metrics | charts | route | weather | decor` to `metrics | visuals | decor`. The four-way picker (with Route/Weather each holding a single tile) was visually unbalanced; two segments fit the actual content shape.
- `OverlayTileInfo.all` remapped: former `.charts`, `.route`, and `.weather` tiles now use `.visuals` (Distance Timeline, Elevation Chart, Running Gauge, Interval HUD Bar, Interval Timeline, Route Map, Weather Widget). Array order reorganized so Metrics → Visuals → Decor blocks are contiguous (Distance Timeline / Elevation Chart no longer interleaved between Distance and Elevation metrics).
- Picker filter (`$0 != .decor`) and `tiles(for:)` unchanged; Decor remains hidden. No runtime types touched — `OverlayElementType`, `OverlayPasteCategory`, style presets, and templates are unaffected.
- File: `Sources/RunningOverlay/UI/OverlayPoolView.swift`.

### Numeric Overlay: Avg Pace and Lap Pace

- Added `OverlayElementType.avgPace` and `.lapPace` (Overlay Pool → Metrics, after Pace): same numeric overlay Inspector, typography, and unit options as `pace`; values from `ActivityTimeline.avgPace(at:)` (cumulative elapsed ÷ distance) and `lapPace(at:)` (in-lap running average).
- `OverlayValueFormatter` shares `paceOverlayComponents` for all three pace types. Interval HUD metric slots and export batching include the new types.
- Tests: `OverlayValueFormatterTests.avgPaceUsesCumulativeSessionAverage`, `lapPaceUsesRunningAverageWithinCurrentLap`.

## 2026-05-15

### Overlay Pool: HR Zone numeric overlay

- Added `OverlayElementType.heartRateZone` (Overlay Pool → Metrics): same numeric overlay Inspector as other metrics, value is current zone label `Z1`…`Zn` from Project Settings heart-rate zones (or `--` when HR or zone bounds don’t resolve).
- New style flag `OverlayStyle.textColorsFollowHeartRateZones` with Inspector toggle **Zone colors → Match zone colors for text**. When on, preview (`TextPresetOverlayView`) and export (`OverlayFrameRenderer` preset path + minimal path) tint value/label/unit/accent/foreground swatches from `HRZonePalette` for the active zone; when off, colors follow the normal per-role swatches.
- `OverlayTextRenderLayout.unifiedTextBaseColor` is computed in `OverlayRenderModel.textLayout` so preview/export share one source of truth. `OverlayValueFormatter` formats the standalone metric; HUD bar metric enum remains separate (unit test excludes `heartRateZone` overlay type from HUD slot parity).
- Docs: `docs/design/overlays/numeric/numeric-overlay-ui.md`.

### Cursor: Project hooks for `docs/project-log.md`

- Added `.cursor/hooks.json` with `sessionStart` and `postToolUse` (matcher `Write|StrReplace`) running `.cursor/hooks/project-log-reminder.py`.
- **sessionStart** injects `additional_context` with the standing convention (EN + 中文) to append dated sections to `docs/project-log.md` after substantive edits.
- **postToolUse** injects a short nudge when writes touch `Sources/`, `Tests/`, `docs/` (except `docs/project-log.md`), `CLAUDE.md`, or `Package.swift`; skips `.cursor/hooks/` to avoid noise while editing the hook itself.
- Scripts use `hook_event_name` from the common hook payload; `python3` only (no `jq`). Restart Cursor or save `hooks.json` if hooks do not load.

### Numeric Overlay: Unit Align Independent of Value / Label (Minimal + Inspector)

- Clarified product intent after a misread: **unit** alignment should not follow value or label controls — not a second pass on typography value-align semantics beyond what the model already exposes.
- **`PreviewCanvasView` (`TextPresetOverlayView.metricCoreContent`)**:
  - Middle row no longer applies `valueStackFrameAlignment` to the whole `HStack` (that slid inline units horizontally whenever value align changed). The value sits in its own `frame(maxWidth: .infinity, alignment: valueStackFrameAlignment)` slot; the row expands with a neutral `.leading` cluster frame.
  - When the unit is **left or right** of the value, the value+unit group is built as an inner `HStack(alignment: verticalAlignment(unitTextAlignment))`. If a **side label** is present, that cluster is wrapped in an outer `HStack(alignment: labelVAlignment)` for label↔block vertical anchor only. Previously a single `HStack(alignment: labelVAlignment)` held label, unit, and value, so changing the label’s side-anchor also moved the unit vertically.
- **`NumericOverlayDetailView`**: Unit section Align row uses the same position-aware row title and SF Symbols as the Label section (`alignRowLabel` / `alignSystemImage` keyed on `unitPosition`) so Left/Right positions read as **Anchor** (top/middle/bottom) instead of horizontal text-align icons.
- **`OverlayStyle.unitTextAlignment`** comment in `OverlayElement.swift` and **`docs/design/overlays/numeric/numeric-overlay-ui.md`** updated to describe top/bottom vs left/right interpretation.

## 2026-05-14

### Interval Timeline: Scale Centered Segments to Fit

- Fixed segments overflowing the background when `visibleNeighbors` is large. Previously each segment was clamped at `minSegmentWidth`, so once `count * minWidth + gaps > availableWidth` the row spilled past the right edge. Now in `centeredWindow`, after applying `minSegmentWidth` as a preference, if the total exceeds the usable width we scale `currentWidth` and `othersWidth` proportionally so the segments always fit. Tradeoff: very large neighbor counts produce sub-minWidth segments rather than visual overflow.
- Applied the same scale-to-fit to the `fullSchedule` (duration-proportional) branch: dropped the post-scale `max($0 * factor, min(minWidth, usableWidth/count))` floor that could re-overflow after scaling. Widths now scale freely so they always fit, with `minSegmentWidth` acting as a preferred floor that yields when over capacity.
- Widened the pill-to-segment gap from 8pt → 12pt so the last visible segment doesn't visually touch the right `xN` pill at modest scales.

### Interval Timeline: Revert Progress Source, Marker Font, Segment Radius

- Reverted the in-segment progress fill back to lap progress (`activity.lapProgress(at:byDistance: false)`). Overall workout position is already conveyed by *which* segment is highlighted plus the `Rep N / total` text; using overall progress for the fill made it advance only a few percent per rep, which was unreadable. The marker (when `liveProgress`) and the fill now both sweep across the current segment as that lap runs.
- Added `markerFontName: String` to `IntervalTimelineStyle` (empty string = inherit the overlay's font). Wired the SwiftUI marker view and `OverlayFrameRenderer` marker text to consume it, and added a "Marker Font" menu in the Current inspector section (using `NumericOverlayDetailView.fontPresets`) so the marker label can be styled independently from the rest of the overlay.
- Added `segmentCornerRadius: Double` (default 6) to `IntervalTimelineStyle`. The fill, progress highlight, and current stroke in both the SwiftUI preview and the CoreGraphics export now read this value. Added a "Radius" slider (0–20) at the bottom of the Timeline inspector section.

### Interval Timeline: Remove Rail

- Dropped the rail entirely (dots + connecting capsule line) — visually redundant alongside the segment row and `NOW` marker. Removed `railEnabled`, `railSpacing`, `railDotSize`, `railColor`, `railOpacity`, `railLineColor`, `railLineWidth` from `IntervalTimelineStyle`; removed `railY`, `railDots` from `IntervalTimelineRenderLayout`. Older project JSON containing those keys still decodes — the unknown keys are silently ignored by `decodeIfPresent` since the corresponding CodingKeys are gone.
- Removed the Rail section from the Inspector, the `railView` from the SwiftUI overlay, and the rail draw block from `OverlayFrameRenderer`.
- Marker now stacks directly below the current segment (`markerTopY = currentBottom + markerGap`). The "marker visibility does not change geometry" invariant still holds. Updated `intervalTimelineMarkerLaneKeepsMarkerInsideBackground` to assert against the current segment's bottom instead of the rail. Deleted `intervalTimelineRailSpacingExpandsBackgroundAndKeepsRailInside`.

### Interval Timeline: Tight Cluster, Tight Bottom Padding, Fixed Current Width

- Tightened the overflow cluster (`WU/CD` ghost + `···` + `xN` pill) and moved its geometry into the layout (`overflowGhostInset`, `overflowEllipsisInset`, `overflowPillInset`, `overflowPillSize`). Previously the view positioned pills with `* element.scale` while the layout reserved width in canvas-scaled units, so at non-unit canvas scales the pill could overlap adjacent segments. The cluster now reserves ~72pt from `contentRect.minX/maxX` (down from 116pt), and the view consumes layout-provided positions so preview and export stay aligned.
- Recomputed the overlay background height from the actual stacked content (`segmentMidY → currentBottom → marker → bottomPadding`) instead of additively reserving a rail lane that the rail never occupied. This removes the oversized empty band below the marker label.
- Current segment width is no longer derived from lap duration. In `centeredWindow`, the current lap is drawn at a fixed fraction (`currentSegmentWidthFraction`, default `0.28`, exposed as a Width slider in the Current inspector section, range 15–50%). Remaining visible laps share the leftover width evenly. The progress fill inside the current segment is now overall workout progress (`elapsedTime / activity.duration`) — the Interval Timeline communicates schedule position, not the lap's internal progress (Interval HUD Bar already covers that).
- Updated `intervalTimelineOverflowPillClustersDoNotOverlapSegments` and `intervalTimelineReservesEdgeContextWhenOverflowPillsAreHidden` to reflect the new cluster widths.

### Interval HUD Bar: Bottom Bar Border + Zone Geometry Fix

- Fixed HR/Pace zone bottom-bar geometry so zone segment gaps are calculated from display order instead of the real zone index. This removes the large blank track area on the left and keeps Z1-Z6 segments inside the bar in both preview and export.
- Fixed the SwiftUI preview zone-strip alignment by pinning the zone drawing stack to the top-leading edge after sizing it to the bar width. This keeps the first segment anchored to the left edge instead of centering the segment stack inside the bar.
- Added independent Bottom Bar Border controls for Interval HUD Bar: enable, color, width, and opacity. The border applies only to the bottom strip and is separate from the shared outer HUD container border.
- Moved Bottom Bar Corner Radius into the shared Bottom Bar controls so it applies consistently to `Lap Progress`, `HR Zones`, and `Pace Zones`.

### Interval HUD Bar: Threshold Markers

- Added a small bottom-bar threshold marker for zone modes. `HR Zones` reads the global `Threshold HR`; `Pace Zones` reads the global `Threshold Pace`. When the threshold falls inside a configured zone, the marker renders below the bar with a `T` label and the matched zone color.
- Added an independent Threshold Marker toggle and refined its visual treatment to a subtle vertical tick on the bar with a small `T` label below it instead of a triangle marker.
- Suppressed the current-value pace marker when live pace is `0` or invalid, avoiding misleading `0:00 min/km` markers while paused or stopped.
- Extended `HeartRateZoneSnapshot` to include threshold HR/pace so preview and export can resolve threshold marker positions without reaching back into UI state.

### Project Settings: Centralized Interval Kind Colors

- Added an **Interval Colors** section to Project Settings with a `Configure…` button that opens a new `IntervalKindColorsView` sheet. The sheet exposes four `ColorPicker` rows — Warm Up (热身), Active (训练), Rest (休息), Cool Down (冷身) — and a Reset button to restore defaults.
- New `IntervalKindColorPreferences` (singleton, `@MainActor @Observable`) persists the four colors in `UserDefaults` under `intervalKindColors.palette.v1`. Defaults match the FIT track colors on the timeline canvas (`0x3AA6A3`, `0xE77A3C`, `0x4F82C7`, `0x7A6AD8`) so existing projects look identical until users opt to change them. A `nonisolated currentSnapshot()` helper gives the export path a thread-safe read.
- Re-routed consumers to a single source of truth:
  - `TimelineView.lapKindColor(_:)` (AppKit FIT lap drawing on the timeline canvas).
  - `OverlayRenderModel.intervalTimelineLayout(for:in:)` overrides the four kind colors on the working `IntervalTimelineStyle` so the Interval Timeline overlay's segment colors and ghost WU/CD edge labels follow the project setting.
  - `OverlayRenderModel.lapKindColor(_:activeZoneIndex:)` (Interval HUD Bar phase color) now reads from the preferences snapshot, with the HR-zone override for `.active` laps still applied first.
- The `unknownColor` slot on `IntervalTimelineStyle` is unchanged; only the four user-facing kinds are configurable, matching the request for "热身 / 休息 / 冷身 / 训练".

### Interval Timeline: Marker Lane Containment

- Fixed `NOW` marker overlap by adding a reserved marker lane to `IntervalTimelineRenderLayout`. The triangle and label now stay inside the background and border instead of being drawn below the overlay.
- Shared the marker geometry (`markerTopY`, triangle height, label height) between SwiftUI preview and CoreGraphics export so both render paths agree.
- Marker visibility still does not move the segment row or rail because the marker lane is reserved regardless of whether the marker is currently shown.

## 2026-05-13

### Interval HUD Bar: Zone Bottom Bar Emphasis + Marker

- Added Interval HUD Bar Bottom Bar zone controls for `HR Zones` and `Pace Zones`: Active Zone Width (`Equal` to `50%`), Zone Marker visibility, Marker Position (`Above` / `Below`), and optional Marker Value display.
- Added zone segment gap, active zone height, and bottom bar corner radius controls so users can separate HR/Pace zones, make the active zone taller, or use square progress-bar ends.
- Added Bottom Bar Spacing so users can tune the vertical gap between the HUD cells and the bar; preview and export use the same style value.
- Wired shared Background Padding into Interval HUD Bar layout. X padding now moves cells and bottom bar inward; Y padding increases top and bottom interior space in both preview and export.
- Zone bottom bars now use a shared segment-frame calculation for preview and export. Equal mode preserves the existing evenly divided Z1-Z5/Z6 strip; emphasized mode lets the active zone occupy up to half the bar while inactive zones split the remainder.
- Added a single solid triangle marker for the current HR/pace position inside the active zone. It can be hidden completely; when visible, its color and optional value label follow the active zone color.
- Added an Inactive Opacity slider for HR/Pace zone bottom bars so users can tune non-active segment strength instead of using a fixed opacity.
- Added per-slot unit options for Interval HUD Bar Metrics so pace, distance, elevation, temperature, and other Numeric Overlay-backed metrics can use imperial or alternate units inside the HUD.
- Added the zone marker design reference at `docs/design/overlays/interval-hud-bar/interval-hud-bar-zone-marker.png`.

### Playback Drift Without Video: Wall-Clock Delta Instead of Fixed Step

- User reported that with only a FIT file imported (no video clips), 1x timeline playback ran noticeably slower than wall-clock — displayed elapsed time fell behind real time.
- Root cause: `MainEditorView` drove playback via `Timer.publish(every: 1/30)` and unconditionally called `project.advancePlayback(by: 1.0/30.0)` on every tick. SwiftUI/RunLoop timers do not guarantee that cadence — overlay re-rendering and main-thread stalls drop ticks, and each dropped tick silently lost 1/30 s. With a video clip present this path is bypassed (AVPlayer's `periodicTimeObserver` drives the playhead via `setPlayheadFromPlayback()`), so the bug only surfaced in the FIT-only case.
- Fix in `MainEditorView.swift`:
  - Switched to wall-clock delta using `CACurrentMediaTime()`. The tick computes `now - lastTickTime` and feeds that into `advancePlayback`, which already multiplies by `playbackRate`. Dropped/late ticks now self-correct.
  - Tightened the tick interval to 1/60 s so playhead updates feel smooth on 60 Hz panels (the cost is bounded because we no longer do real work unless playback is actually active).
  - Gate on `project.isPlaying`; reset `lastPlaybackTickTime` to `nil` whenever the driver is inactive so the first tick after play/seek doesn't apply a stale delta.
  - Capped per-tick delta at `0.25 s` to avoid flinging the playhead forward after a long stall (e.g. app backgrounded, modal sheet).

### Timeline Zoom: Shift+Z Fit Toggle (DaVinci-style)

- Added a `Shift+Z` keyboard shortcut (menu: **Timeline → Toggle Fit Zoom**) that snaps the timeline between Fit and the user's last working zoom, mirroring DaVinci Resolve's behavior.
- Logic in `ProjectDocument.toggleTimelineFitZoom()`:
  - Non-fit → `.fit`.
  - `.fit` → restore `lastNonFitPixelsPerSecond` if known; otherwise fall back to `fitPixelsPerSecond * 5` (clamped to `[fit, 200]`).
- `lastNonFitPixelsPerSecond` is maintained via a `didSet` on `timeline` (`rememberNonFitZoom`) so every path that ends in a non-fit zoom — slider drag, Cmd±, undo/redo, project load — refreshes the memory. The key UX requirement was "always remember the most recent zoom value, regardless of how the user got there," which a single chokepoint (`didSet`) satisfies without sprinkling bookkeeping through every mutation path.
- Shortcut chosen as `Shift+Z` (no Cmd) because `Cmd+Z` / `Cmd+Shift+Z` are already bound to undo/redo and DaVinci's muscle memory is bare `Shift+Z`.

### Timeline Zoom: Fit Is the Minimum

- User reported the zoom slider's left half (slider values that mapped to pixels-per-second below the Fit value, e.g. `0.5`) produced a layout *shorter* than Fit — clips appeared squeezed and the px/s readout dropped below `1`. Intended behavior: the slider's leftmost position should be Fit, and any movement only zooms in.
- Root cause: the slider mapped its raw range `0.25…200 px/s` regardless of the viewport's actual Fit value, and `TimelineZoom.zoomedIn()` from `.fit` produced a fixed `0.5 px/s` — both could land below Fit. The Fit px/s is viewport-dependent and was never known to `ProjectDocument`.
- Fix:
  - Added `ProjectDocument.fitPixelsPerSecond` (runtime cache, not persisted). `TimelineCanvasNSView.update` writes the freshly computed Fit value each render and clamps the rendered px/s to `≥ fit` as defense against stale state.
  - Rewrote `zoomTimelineIn` / `zoomTimelineOut` and the slider mapping (`pixelsPerSecond(forSliderValue:fit:)` / `sliderValue(forPixelsPerSecond:fit:)`) to use `fitPixelsPerSecond` as the lower bound instead of the static `0.25`. Slider 0 = Fit; the px/s curve interpolates from Fit up to `200`.
  - `timelineZoomSliderValue` now snaps any persisted px/s `≤ fit` back to the leftmost (Fit), so projects saved at an old sub-Fit zoom display correctly on reopen.
- `TimelineZoom.zoomedIn/zoomedOut` are no longer reached (ProjectDocument owns the stepping math now). Left in place because the enum is `Codable` and used by tests/snapshots — removing them is unrelated cleanup.

### Numeric Overlay: Unit Alignment in Inline Presets + Universal Value Alpha

- User reported the new Unit Align control had no visible effect on the `splitLabel` preset (the same gap existed in `racingStripe` / `editorial`). Root cause: those presets rendered `value` and `unit` inside one `HStack(alignment: .lastTextBaseline)`, so there was only a single frame anchor (`valueStackFrameAlignment`) for the pair — the unit always tracked the value's horizontal placement.
- Fix: split value and unit into separate rows in `splitLabelView`, `racingStripeView`, `editorialView`. Each row now applies its own `frame(maxWidth: .infinity, alignment:)` — value uses `valueStackFrameAlignment`, unit uses `unitStackFrameAlignment`. Inline-with-value unit positions (`.leading`/`.trailing` in `metricCoreContent`) still keep the unit glued to the value baseline by design — independent alignment doesn't make geometric sense on a shared baseline.
- Trade-off: in those three presets the unit is no longer baselined inline with the value (it sits on its own row immediately below). This is the cost of giving the Unit Align segmented control real effect on these presets — accept the small visual change in exchange for the decoupling the user explicitly asked for.
- Universal value alpha: user reported the Value `Alpha` slider had no effect on several presets. Root cause: most preset views read value text color from `Color(element.style.foregroundColor)` directly, bypassing `valueColor` / `valueOpacity`. Only `metricCoreContent` and `bigNumberView` used the `valueTextColor` helper that applies both. Routed every value-text `foregroundStyle(...)` through `valueTextColor`, with two carve-outs that preserve preset intent:
  - Stylized opacity multipliers stay (`inlineGhost`'s `0.88`, `serifEditorial`'s `0.92`) but now multiply against `valueOpacity` instead of foreground: `Color(valueColor).opacity(valueOpacity * <multiplier>)`.
  - Accent-tinted values (`digitalWatch`) use `accent.opacity(valueOpacity)` so user alpha rides on top of the LCD tint instead of replacing the color.
- `valueText` (the `Text` helper used by `sportWatch`) now sets `.foregroundColor(valueTextColor)` so the watch dial respects value alpha. Same `unitTextColor` treatment applied to unit text in the now-split `splitLabel`/`racingStripe`/`editorial`.
- Known gap, intentionally not addressed in this pass: `OverlayFrameRenderer` (the CG export path) still defaults to `foregroundColor` for value text via `textAttributes`. Bringing it to parity needs per-element-type color routing (label/unit drawText calls today inconsistently rely on the default), which is a larger change parked for a follow-up. Filed in this entry so the next person picking it up knows the preview/export gap.

### Preview Header: Drop Duplicate Menu Chevron

- The preview zoom (`Fit`) and playback rate (`1x`) menus in `PreviewCanvasView.swift` were rendering two chevrons: SwiftUI's auto menu indicator on the left of the label plus the explicit trailing `chevron.down` in the custom label. Added `.menuIndicator(.hidden)` to both `Menu`s so only the intentional right-side chevron remains.

### Preview Header: Canvas Background Color Picker

- Added an inline `ColorPicker` to the preview header, immediately to the left of the Fit/Fill menu, so the user can change the canvas backdrop color (most useful when there is no video clip under the playhead and the canvas would otherwise be blank).
- Backed by a new `@Published var previewCanvasBackground: Color = EditorTheme.appBackground` on `ProjectDocument` (session-only, alongside `previewFitMode`). The preview's backdrop `Rectangle` now fills with this value instead of the hardcoded `EditorTheme.appBackground`.
- `supportsOpacity: false` — the picker is for the visible backdrop, not for export (exports remain transparent MOV); allowing alpha here would just confuse intent.
- `VideoPreviewNSView` previously hardcoded its host `CALayer.backgroundColor = NSColor.black`, which sat on top of the canvas `Rectangle` and showed as black letterbox/pillarbox bars whenever the video's aspect didn't match the project canvas — defeating the new color picker for the most common case (Fit + mismatched aspect). Changed to `NSColor.clear` so the canvas `Rectangle` behind the player layer becomes the visible letterbox color.

### Preview Fit Mode: Fit / Fill

- Wired the previously inert preview zoom menu to actually switch between two modes. New `PreviewFitMode` enum (`fit`, `fill`) in `PreviewCanvasView.swift`; new `@Published var previewFitMode: PreviewFitMode = .fit` on `ProjectDocument` (session-only, sits alongside `showPreviewGuides`).
- **Semantics**: the canvas (black backdrop) always keeps the project's export aspect ratio — Fit/Fill controls how the underlying **video clip** sits inside that canvas, not how the canvas sits inside the preview area. So `fittedCanvasSize` is unchanged; instead the mode is plumbed into `VideoPreviewPlayerView` and toggles `AVPlayerLayer.videoGravity` between `.resizeAspect` (Fit — letterbox when video aspect ≠ project aspect) and `.resizeAspectFill` (Fill — crop video to fill the canvas).
- (Initial implementation incorrectly scaled the whole canvas in Fill mode, expanding the black backdrop past the project aspect — corrected based on user feedback. AVPlayerLayer already auto-clips at its bounds, so no extra `.clipped()` is needed.)
- Stretch (non-uniform scaling) intentionally **not** offered: any non-uniform scale would mislead the user about export geometry since overlays sit at canvas-relative coordinates.
- Menu contents updated to two `Button`s with a checkmark for the active mode; the header label now reflects `project.previewFitMode.label` instead of a hardcoded "Fit".

### Numeric Overlay: Independent Unit Alignment Control

- Added `OverlayStyle.unitTextAlignment` (`OverlayTextAlignment`, default `.leading`). Plumbed through `OverlayTextRenderLayout.unitTextAlignment`, a new `ProjectDocument.setOverlayUnitTextAlignment(_:alignment:)` mutator, and a new "Align" row in the Inspector Unit section (segmented left/center/right). Backward-compat decoder uses `decodeIfPresent ?? Self.default.unitTextAlignment`.
- User reported that the unit row was tracking other rows: when the unit sits on its own line (`unitPosition == .bottom` in stacked metric layouts, or always in the `bigNumber` preset) it was inheriting the value's frame alignment, so adjusting label/value align would visually drag the unit along. Fix: the unit row now applies its own `frame(maxWidth: .infinity, alignment: unitStackFrameAlignment)`.
  - `bigNumberView` restructured: flattened the nested `VStack { value; unit }` into the outer `.leading`-anchored stack so value and unit each get an independent per-row frame anchor; same flattening applied in the side-label HStack branch.
  - `metricCoreContent` bottom-unit branch now uses `unitStackFrameAlignment`.
- Inline unit positions (`.leading`/`.trailing` of the value) stay glued to the value baseline by design — alignment doesn't make sense for those modes, so the new control is documented to apply only to standalone-row layouts.
- Export parity: `OverlayFrameRenderer.bigNumber` now passes `nsTextAlignment(renderLayout.unitTextAlignment)` to the unit `drawText` call instead of hardcoded `.center`. Build clean, 111/111 tests pass.

## 2026-05-12

### Interval HUD Bar Overlay Implementation

- Added `OverlayElementType.intervalHUDBar`, `IntervalHUDBarStyle`, bottom bar modes, progress modes, HR Drop display modes, and metric slot configuration.
- Added `OverlayElementType.intervalTimeline` as a companion schedule overlay for Interval HUD Bar. It renders the interval plan horizontally, keeps the current lap centered and enlarged, shows live current-lap progress with a `NOW` marker, and summarizes hidden repetitions for high-count workouts.
- Added `IntervalTimelineStyle`, `OverlayRenderModel.intervalTimelineLayout(for:in:)`, SwiftUI preview/export support, legacy PNG renderer support, Overlay Pool Charts entry, dedicated Inspector, and render model tests for centered-window overflow plus full-schedule behavior.
- Revised Interval Timeline visual implementation to match the approved overlay treatment: removed the design-board title/badge from runtime rendering, made the overlay a compact pure timeline rail, added rail dots and WU/CD ghost edge labels, and flipped the `NOW` marker triangle upward toward the current segment.
- Refined Interval Timeline overflow and Inspector behavior: hidden counts now render as square bordered `xN` boxes in `WU ··· [xN]` / `[xN] ··· CD` order, the rail exposes dedicated style controls, the `NOW` marker floats outside layout without moving rail geometry, and the Inspector `Reset` / `Done` footer is fixed at the bottom.
- Tightened Interval Timeline overflow spacing and restored the rail to the previous line-and-dot style. Rail `Spacing` now controls the vertical gap below segments, with separate dot size/color/alpha and line width/color controls.
- Reserved WU/CD endpoint space independently of Overflow Pills, made rail spacing expand the rendered background height so the rail stays inside the container, moved the floating `NOW` marker closer to the rail, and added marker color/size/weight controls.
- Made Interval Timeline overflow clusters symmetric and tighter while reserving a fixed no-overlap width for `WU ··· [xN]` / `[xN] ··· CD`.
- Implemented `OverlayRenderModel.intervalHUDBarLayout(for:in:)` using `ActivityTimeline.laps`, current lap progress, live HR/pace/power, REST recovery drop helpers, and shared HR zone preferences.
- Extracted shared overlay HR zone colors through `HRZonePalette.overlayColors` and added a nonisolated `HeartRateZonePreferences.currentSnapshot()` reader for render/export paths.
- Added `IntervalHUDBarOverlayView`, `OverlaySharedIntervalHUDBarView`, Overlay Pool Charts tile, dedicated Inspector, SwiftUI exporter support, and legacy PNG renderer support.
- Updated the built-in `Interval Workout` template to include Interval HUD Bar.
- Added render model test coverage for WORK/REST phase layout, rep text, HR zone matching, zone bar segments, and HR Drop percentage mode.
- Wired shared Effects shadow into the Interval HUD Bar container so preview and export both honor shadow color, opacity, radius, offset, and thickness when the HUD background is enabled.
- Corrected Interval HUD Bar bottom bar spacing so larger values increase the visible gap, and moved below-positioned zone markers down so the bar no longer covers the triangle.
- Clamped Interval HUD Bar effective bottom-bar spacing against available container height, preserving top/bottom padding, marker space, and a minimum data-row height so HUD content stays inside the background.
- Revised the Interval HUD Bar vertical allocator to preserve requested bottom-bar spacing first, compress top/bottom padding on short HUDs, and only cap spacing as a last resort.
- Converted Interval HUD Bar Zone Marker into a floating overlay that no longer reserves vertical layout space or changes data row, bottom bar, spacing, or background geometry.
- Moved the Interval HUD Bar Bottom Bar enable switch into the Bottom Bar section header before the disclosure chevron and removed the duplicate body row.
- Updated Interval HUD Bar Effects shadow so it applies to the full content group when both Background and Border are disabled, while preserving container shadow when Background is enabled.

Files added:

- `Sources/RunningOverlay/Overlay/IntervalHUDBarModel.swift`
- `Sources/RunningOverlay/UI/IntervalHUDBarOverlayView.swift`
- `Sources/RunningOverlay/UI/IntervalHUDBarOverlayDetailView.swift`

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/OverlaySharedViews.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/OverlayPoolView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Project/HeartRateZonePreferences.swift`
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/design/overlays/interval-hud-bar/interval-hud-bar-overlay-ui.md`
- `docs/overlay-modules/interval-hud-bar-overlay.md`
- `docs/project-log.md`

### Retired Early Lap Overlay Prototypes

- Removed the original `Lap List`, `Lap Card`, and `Lap Live` overlay components from the active app surface before implementing the replacement Interval HUD Bar.
- Removed their element types, paste categories, style models, render layouts, SwiftUI preview/export views, exporter dispatch, inspector panels, Overlay Pool tiles, template references, and bundled template style payloads.
- Deleted the old module note and added `docs/overlay-modules/retired-lap-overlays.md` with the retirement rationale, affected files, and git recovery commands.
- Updated current architecture, roadmap, media-pool design, module, and interval HUD docs so they no longer describe the retired overlays as available features.

Files removed:

- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `docs/overlay-modules/lap-list-overlay.md`

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/OverlaySharedViews.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/OverlayPoolView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate`
- `docs/architecture.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/design/overlays/interval-hud-bar/interval-hud-bar-overlay-ui.md`
- `docs/overlay-modules/README.md`
- `docs/overlay-modules/interval-hud-bar-overlay.md`
- `docs/overlay-modules/retired-lap-overlays.md`

### Project Settings: Heart Rate Zones

- Added a new "Physiology" section to Project Settings with a single row "Heart Rate Zones → Configure…". Sits peer-to-peer with the existing Typography / Font Library row per user request, opens a dedicated sheet.
- Sheet (`HeartRateZonesView`) lets the user pick 5 or 6 zones, choose a pace unit (min/km or min/mile), and enter optional HR range (bpm) and/or pace range (m:ss) per zone. Each row carries a fixed-palette colored dot (blue → cyan → green → yellow → orange → red) keyed to zone index.
- Stored globally in `UserDefaults` via a new `HeartRateZonePreferences` `@Observable` singleton (mirrors `FontLibraryManager`). HR zones are a user trait — they should persist across projects rather than ride inside `.roov`. Pace values are normalized to seconds-per-km on disk; the UI re-renders via `PaceConversion` when the unit toggle flips, so switching units never loses data.
- Persistence keeps a full 6-slot array even when the user is in 5-zone mode, so toggling 5 ↔ 6 preserves whatever the user typed into Z6. The footer "Reset" button only clears the currently-visible zones.
- Added a "Threshold" subsection above the zone list with `Threshold HR` (bpm) and `Threshold Pace` (formatted per active unit) inputs, persisted in `UserDefaults`. Gives users an anchor metric for deriving zones.
- Layout fix: widened the sheet (700 × 680) and applied `.fixedSize()` to all inline captions (HR, Pace, bpm, threshold labels). Earlier the row overflowed the 560pt sheet and SwiftUI compressed "Pace" into a vertical letter stack. Dropped the redundant trailing unit suffix on each zone row — unit already shows in the segmented control above.
- Spec-compliance refactor against `docs/design/panels/project-settings/project-settings-ui.{md,spec.json}` and the `heart-rate-zones.png` mockup: moved `HR Range` / `Pace Range` out of each row and into a table-style column header row above the zones grouped box. Removed the inline `HR` / `Pace` captions per row. Wrapped the Z label in a small dark rounded pill next to the colored dot. Reused `SettingsGroupBox` + `SettingsSectionHeader` (instead of one-off rounded-rect chrome) so the sheet shares the macOS-utility design language used by Project Settings and Font Library. Subtitle updated to "Configure HR and pace ranges for each zone." and the Physiology row caption in `ProjectSettingsView` updated to "Configure HR and pace ranges for overlays." per spec. Sheet sized 720 × 660 with shared column-width constants so the header row aligns pixel-for-pixel with the data rows below.
- This change wires only the *configuration layer*. `RunningGaugeProgressMode.heartRateZone` still falls back to elapsed-time progression; consuming the configured zones inside the gauge render path is a follow-up task.
- Endpoint-row UX refinement: first zone (Z1) and last visible zone (Z5 or Z6) now show a single input field prefixed with a comparator instead of a two-field range. Entering a range for the open-ended endpoints isn't intuitive — the user only thinks of one threshold. HR uses `<` for Z1 and `>` for the last zone. Pace is inverted (lower sec/km = faster), so Z1 (slowest) uses `>` and the last zone (fastest) uses `<`. Bindings match the visible direction: Z1 HR writes `maxHR`; last-zone HR writes `minHR`; Z1 pace writes `minPaceSecPerKm`; last-zone pace writes `maxPaceSecPerKm`. The unused side of each endpoint range is cleared on write. Comparator occupies the dash slot's width and a transparent filler occupies one field's width, so the endpoint cluster's total width matches middle-row range clusters and column alignment is preserved.

Files added:

- `Sources/RunningOverlay/Project/HeartRateZonePreferences.swift`
- `Sources/RunningOverlay/UI/HeartRateZonesView.swift`

Files changed:

- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`

### Heart Rate Zones Sheet Design Spec

- Added the simplified Heart Rate Zones sheet mockup to `docs/design/panels/project-settings/heart-rate-zones.png`.
- Updated the Project Settings design spec to cover the Physiology row and the Heart Rate Zones sheet.
- Locked the design scope to existing controls only: zone count, pace unit, threshold HR, threshold pace, zone HR/pace ranges, Reset, and Done.
- Documented excluded future controls so implementation does not add import, preview, auto-fill, purpose/category, timeline preview, or profile management before the model supports them.
- Updated the structured spec and design README to reference the new mockup and layout rules.

Files changed:

- `docs/design/panels/project-settings/heart-rate-zones.png`
- `docs/design/panels/project-settings/project-settings-ui.md`
- `docs/design/panels/project-settings/project-settings-ui.spec.json`
- `docs/design/README.md`

### Interval HUD Bar Overlay Design Spec

- Added the Interval HUD Bar visual mockup to `docs/design/overlays/interval-hud-bar/interval-hud-bar.png`.
- Added implementation-facing design docs for a horizontal interval HUD overlay showing rep, phase, remaining time/distance, HR zone, HR, pace, power, and REST-specific HR Drop.
- Documented bottom bar modes: none, lap progress, HR zones, and pace zones.
- Documented REST HR Drop display modes: `bpm` and `%`.
- Specified that HR zone colors should be extracted into a shared palette used by Project Settings, Interval HUD Bar, and future physiology-aware overlays.
- Added a module note under `docs/overlay-modules/` and linked the new overlay from design/module indexes.

Files added:

- `docs/design/overlays/interval-hud-bar/interval-hud-bar.png`
- `docs/design/overlays/interval-hud-bar/interval-hud-bar-overlay-ui.md`
- `docs/design/overlays/interval-hud-bar/interval-hud-bar-overlay-ui.spec.json`
- `docs/overlay-modules/interval-hud-bar-overlay.md`

Files changed:

- `docs/design/README.md`
- `docs/overlay-modules/README.md`

### Numeric Overlay: Independent Value Alignment Control

- Surfaced `OverlayStyle.textAlignment` as the per-overlay **value alignment** in the Typography inspector section (an `Align` segmented row under Weight). Field already existed in the model and on every preset's tokens, but no Inspector control was reading it and the value was never applied at render time — so the only way to align the value was implicitly through the preset.
- Fixed coupling between label and value alignment introduced in the previous change: the SwiftUI views used `VStack(alignment: labelHAlignment)`, which made the value row shift when the user changed the label alignment. Rewrote `metricCoreContent`, `bigNumberView`, `splitLabelView`, `racingStripeView`, and `editorialView` so that the outer `VStack(alignment: .leading)` is fixed, each row applies its own `.frame(maxWidth: .infinity, alignment:)` (label uses `labelStackFrameAlignment`, value/divider rows use `valueStackFrameAlignment`), and the parent uses `.fixedSize(horizontal: true, vertical: false)` to keep the overlay's intrinsic size from expanding to fill the canvas.
- Export renderer (`OverlayFrameRenderer`) propagates `valueTextAlignment` into the layout and uses it for the `bigNumber` value draw; helper `nsTextAlignment(_:)` maps `OverlayTextAlignment → NSTextAlignment` for reuse.

### Numeric Overlay: User-Editable Divider + Label Alignment, Big Number Label Fix

- Added four user-controllable divider style fields to `OverlayStyle`: `dividerEnabled / dividerColor / dividerThickness / dividerOpacity` (project-wide divider quad convention). These drive the decorative line that lives between value and label in the presets that draw one — `pillBadge` (vertical separator), `splitLabel` (horizontal accent line), `racingStripe` (left vertical stripe), `editorial` (bottom accent rule), `sportWatch` (upper + lower rules). Position/orientation stays preset-owned; users only adjust color/thickness/opacity/visibility.
- Added `labelTextAlignment: OverlayTextAlignment` on `OverlayStyle`. Reinterpreted by context: when `labelPosition` is top/bottom the field controls horizontal alignment (left/center/right); when leading/trailing it controls vertical anchor (top/middle/bottom). Applied in `metricCoreContent`, `splitLabelView`, `racingStripeView`, `editorialView`, `pillView`, and the new `bigNumberView`.
- Inspector: removed the standalone "Color" section (its only remaining control was the Accent swatch, now superseded by `dividerColor`). Replaced it with a "Divider" section (color swatch + thickness slider + alpha slider + enabled toggle in header). Added an "Align/Anchor" row under the Label section's Position row that swaps its system icons depending on whether the label is stacked or side-attached. Inspector controls grey out for presets that don't render a divider (`presetSupportsDivider`).
- `OverlayPresetTokens` gained an optional `DividerTokens` triple so `applyOverlayTextPreset` writes per-preset divider defaults — switching to a divider-bearing preset snaps to that preset's intended visual, switching to a non-divider preset turns the divider off.
- Fix: the `bigNumber` preset render path silently dropped `style.showLabel` and never rendered the label component (both in `PreviewCanvasView` SwiftUI path and `OverlayFrameRenderer` CG export path). Now honors `showLabel`, `labelPosition`, and `labelTextAlignment`. `OverlayPresetTokens` for Big Number still defaults `showLabel = false` per spec, so existing projects are visually unchanged unless the user enables the label.
- Export renderer (`OverlayFrameRenderer`) updated to read the same divider fields and renders bigNumber's label so MOV export matches preview.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`

## 2026-05-11

### Fix Cadence Unit (strides → spm) + Honor `fractional_cadence`

- FIT `record.cadence` (field 4) and `lap.avg_cadence` (field 17) are single-foot rpm by spec. The lap parser already doubled to spm, but the per-record parser stored the raw value and rendered it as "spm" — overlays showed ~90 instead of ~180.
- Multiplied the record-level value by 2 at parse time so all downstream sampling (`activity.cadence(at:)`, gauges, formatters) is in spm without per-call-site conversions.
- Also folded in `fractional_cadence` (record field 53, lap field 58; UINT8 scale=128 rpm) before doubling and rounding. Without this the displayed spm could only land on even numbers (178, 180, 182…); with it we recover odd-valued spm like 181.

Files changed:

- `Sources/RunningOverlay/FitData/FitFileParser.swift`

### Export Performance Branch: Profiling Files, Frame Reuse, Project Snapshots

- Started the `codex/export-performance` branch in a dedicated worktree at `/Users/codywang/Documents/Projects/running_overlay_export_perf`.
- Added Export dialog actions for saving and restoring a JSON project snapshot. The snapshot preserves exportable state for same-machine benchmark repeats and clears runtime-only state on restore.
- Added task-level export profiling artifacts: each completed export writes JSON and CSV files with whole-export totals plus per-segment timing and frame-reuse metrics.
- Added same-sample frame reuse in `SwiftUIOverlayVideoExporter`: adjacent frames with the same quantized Layer Data sample reuse the previous rendered `CGImage` while still appending every output frame.
- Added focused tests for snapshot round-trip, profiling artifact structure, and sampling reuse decisions.
- Restored missing SVG/Lottie fixture files required by the existing icon rendering smoke tests in fresh worktrees.

### Export Performance Branch: Layered Dynamic-Region Rendering

- Added `ExportRenderPlan` to classify conservative static decor overlays separately from dynamic data overlays.
- MOV export now renders the static decor layer once, then renders dynamic overlays into a padded union rect per unique Layer Data sample, falling back to full-frame dynamic rendering when the dynamic area is too large.
- Extended profiling schema to v2 with static/dynamic render and draw timings, dynamic render area ratio, static layer cache hits, and dynamic render counts.
- Added tests for render-plan classification, dynamic union padding, full-frame fallback, and profiling field output.

### Export Performance Branch: Full-Frame Fallback Guardrail

- Split MOV export into explicit `fullFrameSingleLayer` and `layeredRegion` render paths.
- Full-frame fallback now renders all visible overlays into one image and clears/draws the pixel buffer once per frame, avoiding the layered draw overhead seen in the second benchmark round.
- Extended profiling schema to v3 with render path, dynamic render rect, overlay counts, and full-frame fallback count.
- Added tests for full-frame fallback diagnostics and profiling schema v3 output.

### Export Performance Branch: Frame-Level Outlier Profiling

- Extended profiling schema to v4 with render/draw/frame p50, p95, max, slow-frame threshold, and slow-frame counts.
- JSON segment profiles now include the 10 slowest frames with frame index, clip time, sample time, render reuse flag, and render/draw/frame durations.
- CSV profiles include distribution columns for spreadsheet comparison while keeping detailed slow-frame samples in JSON.
- Added tests for schema v4 fields and slow-frame JSON round-trip.

### Export Performance Branch: Full-Frame Renderer Jitter Reduction

- Test4 showed segment 4 and 9 returned to normal while segment 3 had sustained slow full-frame render samples.
- Full-frame fallback now renders `SwiftUIOverlayFrameView` directly instead of using the cropped layer wrapper.
- Wrapped `ImageRenderer` and pixel-buffer CGContext work in autorelease boundaries to reduce temporary object buildup across long exports.
- Kept profiling schema at v4 so the next benchmark can use existing p50/p95/max and slow-frame fields.

### Export Performance Branch: Per-Overlay Full-Frame-Union Rendering

- Added `renderPath=perOverlay` for full-frame-union exports where every dynamic overlay has a reliable padded rect and the sum of those rects is below 85% of the canvas.
- Per-overlay export renders each dynamic overlay into its own local `CGImage`, reuses the previous overlay image set for identical Layer Data sample times, and composites all overlay images into the pixel buffer with one context.
- Kept the v5 `fullFrameSingleLayer` path for large single overlays, static-decor cases, or any plan without complete overlay rect coverage.
- Extended profiling schema to v5 with per-overlay path enablement, total per-overlay area ratio, overlay render/draw counts, and JSON-only per-overlay timing/rect profiles.
- Added tests for schema v5 fields, conservative large-overlay fallback, and per-overlay path eligibility when far-apart overlays force a full-frame dynamic union.

### Export Performance Branch: Route Map Static Cache Candidate

- Test7 showed per-overlay rendering reduced total export time to 478s and moved the remaining bottleneck to Route Map `ImageRenderer` cost.
- Added a conservative Route Map static cache within the per-overlay path: route-map base content renders once per export task and the current marker renders per unique Layer Data sample.
- Kept route maps with visible stats bars on the normal per-overlay path because stats values are elapsed-time dependent.
- Added route-map shared-view flags so export can render base-only or marker-only route-map layers while the default preview/export call sites remain unchanged.
- Added tests for Route Map static-cache eligibility.
- Test8 improved total export time to 402s, but visual review showed route-map
  layer position drift. The root issue was per-overlay compositing using
  SwiftUI top-left render rects directly in the pixel-buffer CGContext. The
  compositor now converts top-left rects into pixel-buffer draw rects before
  drawing, and Route Map static caching is enabled again for another visual
  benchmark pass.

### Export Performance Branch: Automated Benchmark Export

- Added `--benchmark-export <snapshot.json>` so `swift run RunningOverlay` can
  restore a project snapshot and export all timeline clips without editor
  interaction.
- The benchmark command writes outputs into
  `running_overlay_benchmark_<timestamp>` under the current working directory
  by default, or into `--benchmark-output <directory>` when provided.
- The runner uses the same `SwiftUIOverlayVideoExporter` path as the UI,
  prints segment progress to stdout, writes MOV plus profiling JSON/CSV files,
  and exits non-zero on failure.
- Added parser tests for benchmark command arguments.

Files changed:

- `Sources/RunningOverlay/App/ExportBenchmarkCommand.swift`
- `Sources/RunningOverlay/App/RunningOverlayApp.swift`

### Export Performance Branch: Numeric Batch and 5 FPS Default

- Added numeric overlay batching in the per-overlay path so heart rate, pace,
  cadence, elapsed time, and real time can render as one local SwiftUI image
  when their padded union stays compact.
- Test12 reduced the fixed snapshot from Test9's 428.517s to 408.537s, with
  overlay render count dropping from 44058 to 18882.
- A 5 fps Layer Data benchmark reduced the same snapshot to 183.341s total and
  134.333s image render time by cutting rendered sample frames from 6294 to
  3149.
- New projects now default Layer Data FPS to 5 fps while keeping the output
  video frame rate independent.
- Added a 2 fps Layer Data preset for lower-cadence 4K HEVC benchmark testing.
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Export/OverlayExportModels.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/export-performance.md`
- `Tests/RunningOverlayTests/ExportPerformanceTests.swift`

## 2026-05-10

### Media Pool Empty-Area Context Menu + Fix Root → Folder Drag (second attempt)

- The first attempt at adding a right-click menu to the empty Media Pool area attached `.contextMenu` to a `Color.clear.contentShape(Rectangle())` background view, which on macOS SwiftUI does not actually respond to right-clicks even when the same view does respond to `.onTapGesture`. Moved `.contextMenu { emptyAreaContextMenu }` up to the `ScrollView` level instead — folder/media rows have their own `.contextMenu` modifiers which take precedence at their hit points, so empty-area right-clicks fall through to the scroll view's menu (Import Media… / New Folder).
- The first attempt at fixing root-→-folder drag (switching the UTI from `UTType.text` to `UTType.plainText` in a unified `MediaPoolDropDelegate`) still didn't reliably deliver move drops. Replaced the delegate entirely with closure-form `.onDrop(of: [.plainText, .fileURL], isTargeted:) { providers in ... }` on the scroll background and every folder row. A new `handleDrop(providers:targetFolderID:)` helper inspects the providers — if any conform to `public.file-url` it routes to `importDroppedVideoFiles` (with the target folder), otherwise it loads the first provider as `NSString`, parses the UUID, and dispatches to `performDrop` on the main actor. Removed the now-unused `MediaPoolDropDelegate` struct.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`

### Media Pool Empty-Area Context Menu + Fix Root → Folder Drag

- Added a right-click context menu on the empty area of the Media Pool list (the `Color.clear` background behind `LazyVStack`). Two items: **Import Media…** (opens the standard import panel via `project.importVideos()`) and **New Folder** (creates a folder at root and enters inline rename — same behaviour as the header `folder.badge.plus` button).
- Fixed: root media items couldn't be dragged onto folder rows. Root cause: `onDrag` registers the media UUID via `NSItemProvider(object: NSString)` which advertises `public.utf8-plain-text`. Drop side queried `UTType.text.identifier` (`public.text`) — that's a valid ancestor but SwiftUI's `info.itemProviders(for:)` did not surface the provider reliably. Switched both `validateDrop` / `itemProviders(for:)` queries and the `.onDrop(of:)` UTI lists to `UTType.plainText.identifier` (`public.plain-text`), which is a direct parent of `public.utf8-plain-text` and matches consistently.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`

### Overlap Skip Warning — NSAlert with One-Click "Match to New Layer"

- Status-bar messaging alone wasn't visible enough for batch matches — users were missing the "skipped N due to overlap" notice. Added an `NSAlert` that fires after `matchMediaItems` finishes if any item was skipped because of overlap. The alert lists up to 5 skipped names (with an "…and K more" suffix), states the count matched vs. skipped, and offers two buttons: **Match to New Layer** (immediately re-runs `matchMediaItemsToNewLayer` on the skipped IDs) and **Cancel**. The alert is dispatched via `DispatchQueue.main.async` so the partial-match state has a chance to render behind it.
- Status message is kept as the persistent breadcrumb; the alert is the loud foreground notification.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`

### Timeline Overlap Rejection on Media Placement

- Added `TimelineModel.wouldClipOverlap(mediaItemID:trackName:startTime:duration:)` — a non-mutating overlap probe that compares the prospective placement window against existing clips on the same track, excluding any clip belonging to the same media item (so a re-placement / move of the same item never reports against itself).
- `ProjectDocument.placeMediaItem` now consults the probe before `registerUndoPoint()`. On overlap it refuses outright with a status message that names the clip and suggests `Match to New Layer`, leaving the timeline (and undo stack) untouched.
- `matchMediaItems` (the shared backend behind `Auto Match to Current Layer` / `Match to New Layer`, for both individual selection and folder context-menu actions) now skips overlapping items per-item instead of overwriting them, reporting both the number matched and the number skipped, and pointing the user at `Match to New Layer` when anything was skipped.
- Added two tests in `ProjectDocumentUndoTests`:
  - `placeMediaItemRejectsOverlap` — confirms a second 10s clip placed inside an existing 10s clip's range is refused and the status message mentions the suggested remediation; placing it past the existing clip succeeds.
  - `matchMediaItemsSkipsOverlappingItems` — confirms batch match keeps the non-overlapping item, skips the overlapping one, and surfaces the skip count + suggestion in the status message.

Files changed:

- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`

### Media Pool Folder Rename UX, Folder-Targeted Finder Drops, Folder Auto-Match

- Removed the double-click-to-rename gesture on folder rows. Renaming is now only reachable via the right-click `Rename Folder` action (less accidental). The rename text field is styled as an obvious input: a filled control background and a 1.5pt accent-blue border, and it auto-focuses on appear. (The earlier `Renaming:` caption inside the field was dropped — the bordered input is self-evident.)
- Replaced the separate `MediaItemDropDelegate` with a unified `MediaPoolDropDelegate` that accepts both `UTType.text` (move existing media between folder/root) and `UTType.fileURL` (import new files from Finder) on the same drop target. The previous fix that stacked two `.onDrop` modifiers wasn't reliable because the row hit-region swallowed file URL drops before they could bubble to the outer handler.
- Wired the unified delegate into folder rows, media rows, and the empty-list background, so dragging files from Finder works whether they land on root area, on a folder row (imports straight into that folder), or on a media row (imports to root).
- `ProjectDocument.importVideoURLs(_:replacingExisting:intoFolder:)` gained an optional `intoFolder:` parameter; imported items get stamped with the supplied folder ID inside the import task, and the status message includes the destination folder name.
- Folder context menu gained `Auto Match to Current Layer` and `Match to New Layer`, which feed the folder's full member set into the existing `matchMediaItemsToCurrentLayer` / `matchMediaItemsToNewLayer` paths so a whole folder of clips can be placed onto the timeline at once. Both entries auto-disable when the folder is empty.

### Media Pool Folder Refinements + Restore Finder Drag-Import

- Collapsing a folder now also deselects any of its child media items (and clears the selection anchor if it pointed at a collapsed child). This prevents the surprise where pressing "New Folder" while a folder was collapsed would yank items out of their existing folder.
- Creating a folder via the header `folder.badge.plus` button or the `Add to Folder → New Folder from Selection` context action now only includes selected items that are **currently at the root** (`folderID == nil`). Items already inside another folder stay put even if they were selected — moving items between folders requires an explicit context-menu action or drag/drop.
- Restored dragging video files from Finder into the Media Pool. The new media-item move drop handlers I added in the prior change (declared only `UTType.text`) prevented the outer `.onDrop(of: [.fileURL])` from receiving file imports reliably; added a sibling `.onDrop(of: [.fileURL])` directly on the scroll list's background that routes to `importDroppedVideoFiles` so finder drops work whether they land on empty list area or are intercepted by the inner drop target.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`

### FIT Pause Segment Coloring

- Parsed FIT timer start/stop events into `ActivityAnnotatedSegment` pause spans without changing real elapsed-time video alignment.
- Drew timer-paused spans as muted gray overlays on the `FIT` timeline layer.
- Added hover help for pause spans using the label `Timer Paused`, with elapsed range and duration.
- Clipped collapsed-mode FIT blocks to the actual activity range so video-only spans outside FIT data no longer show a green bar.
- Updated the timeline, architecture, requirements, and development docs for annotation-driven FIT axis coloring.

Files changed:

- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/EditorTheme.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`

### Media Pool Click Responsiveness

- Fixed perceived lag when selecting media rows in `MediaBrowserView`.
- Root cause: stacked `.onTapGesture(count: 2)` + `.onTapGesture` forced SwiftUI to wait for the double-click resolution window before firing the single-tap selection.
- Replaced both gestures with a single tap handler that inspects `NSApp.currentEvent?.clickCount` — single click selects immediately, second click triggers preview.

### Media Pool Folders (replaces color tags)

- Removed the `MediaTag` color label system entirely (`MediaTag` enum, `MediaItem.tag`, `setMediaTag` API, `MediaTagDot` / `MediaTagFilterMenuLabel` UI, the filter-by-mark menu, and the related Mark context-menu submenu). No project file migration needed because the project document is not persisted across launches.
- Added a single-level folder system as the replacement organization mechanism:
  - New `MediaFolder` model (id + name) and a new `mediaItems[i].folderID: MediaFolder.ID?` field.
  - `ProjectDocument` adds `mediaFolders: [MediaFolder]`, with undo-tracked APIs: `createMediaFolder(name:containing:)`, `renameMediaFolder(_:to:)`, `deleteMediaFolder(_:)` (contained items return to the root, never deleted), and `moveMediaItems(_:toFolder:)`.
  - `ProjectSnapshot` includes `mediaFolders` so all folder operations participate in undo/redo.
- `MediaBrowserView` rewritten around a flat-tree row model that mixes expand/collapse folder rows with media rows (folders first, root items after). Active filters (search + Ready/Aligned) force-expand folders and hide empty folders so matches are always visible.
- Multi-select behavior:
  - Plain click: select only the clicked item; sets the selection anchor.
  - `Cmd+Click`: toggle the clicked item in the current selection; updates the anchor.
  - `Shift+Click`: select an inclusive range from the anchor to the clicked item across the flat visible order (works across folder boundaries).
  - Double-click on a media row still triggers preview.
- Folder interactions:
  - Header gained a `folder.badge.plus` button — creates a new folder, includes the current selection if any, and enters inline rename.
  - Folder row: single click toggles expansion; double-click renames inline; right-click → Rename / Delete.
  - Drag a media row onto a folder row to move it; if the dragged item is part of the current selection, all selected items move together. Dropping onto empty list area moves the dragged set back to the root.
  - Media row context menu gained "Add to Folder ▶ (New Folder from Selection / existing folders…)" and "Move to Root".

Files changed:

- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift` (renamed `mediaTagsAndDeletionAreUndoable` → `mediaFoldersAndDeletionAreUndoable`, exercises create/move/delete folder + delete media undo paths)

Verification:

- `swift build` clean.
- `swift test` — all 87 tests pass.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`

## 2026-05-07

### Weather Widget Phase 1 Visual Pass

- Reworked Weather Widget SwiftUI preset rendering to better match the approved weather-app-plugin design direction.
- Added a shared custom SwiftUI weather icon family for all 10 conditions, replacing mixed SF Symbol silhouettes in the main SwiftUI preview/export path.
- Updated the five preset treatments: blue Simple Card, light Compact Strip, dark Forecast Tile, transparent Minimal Text, and graphite Dashboard Bar.
- Seeded preset defaults with realistic sample weather-app content such as `大阪, 日本`, `雨`, `13°C`, and `87% RH`.
- Fixed weather temperature formatting to include explicit units (`°C` / `°F`).
- Fixed render-model source precedence so cached Open-Meteo data is used only when `.openMeteo` is selected, and cached optional metrics still respect show/hide toggles.
- Updated Weather Widget design and module docs to record the implemented first visual pass and remaining API/export-parity work.

### Weather Widget Inspector Pass

- Added `ProjectDocument.applyWeatherWidgetPreset`, centralizing preset switching so visual defaults update while content fields and cached weather are preserved.
- Added Weather Widget style fields for condition label override, humidity suffix, Dashboard metric chip labels, and palette selection, with backward-compatible decode defaults for older project files.
- Expanded the Weather Widget Inspector with quick preset buttons, editable label/suffix/chip fields, and a Palette menu.
- Added tests for FIT/manual/Open-Meteo source precedence, cached metric visibility toggles, condition label override, Fahrenheit formatting, style round-trip, legacy weather style decode, and preset application behavior.

### Weather Widget API Fetch Entry Points

- Added `WeatherFetcher` for Open-Meteo historical archive requests using the current hourly field names: `temperature_2m`, `relative_humidity_2m`, `apparent_temperature`, `weather_code`, and `wind_speed_10m`.
- Added two explicit weather fetch paths in `ProjectDocument`: by first FIT activity GPS point and by current device location through CoreLocation.
- Successful fetches now switch the widget to Open-Meteo, cache the payload in `WeatherWidgetStyle.cachedWeather`, record the fetch location mode, and update visible location text from reverse geocoding.
- Added Weather Widget Inspector buttons for activity-location and current-location fetches; the activity button is disabled when no GPS route exists.
- Updated Weather Widget design and module docs to reflect the API fetch behavior and the decision to ignore legacy Core Graphics PNG parity.
- Added WeatherFetcher tests for request URL construction, hourly payload parsing, and activity route coordinate selection.
- Verification: `swift test` passed with 85 tests; a live Open-Meteo archive request for Osaka returned the expected hourly fields.

### Weather Widget Inspector 1.0 Scope

- Removed shared Background, Border, and Effects modules from the Weather Widget Inspector because those generic overlay controls do not affect the custom SwiftUI weather preset renderer.
- Kept Weather Widget's own supported styling controls inside the widget renderer rather than exposing shared Background, Border, and Effects controls.
- Updated the Weather Widget design spec, structured UI spec, and module docs to define the narrower 1.0 customization surface.
- Removed the duplicate text-only Preset menu; Weather Widget 1.0 now switches presets only through the compact Styles icon buttons.
- Reordered the Weather Widget Inspector setup flow to Layout, Preset, Appearance, Location, then content/temperature/metrics/icon details.
- Combined the former Content, Temperature, Metrics, and Icon sections into one Weather section.
- Added `WeatherWidgetStyle.showIcon` and wired it through SwiftUI preview/export rendering; Icon Size remains preset-owned and is no longer exposed in the Inspector.
- In Open-Meteo mode, Weather hides manual condition, temperature, and metric value inputs because those values come from the cached API payload; unit and display toggles remain editable.
- Replaced the old independent Humidity / High-Low / Wind / Feels Like render toggles with `WeatherMetricSlotValue` and `WeatherWidgetStyle.metricSlots`. Slot count is now driven by Style: Simple Card 1, Forecast Tile 3, Dashboard Bar 3, Compact Strip and Minimal Text 0.
- Weather metric rendering now reads slot assignments, so each visible slot can choose any of the four supported values instead of some metrics only working in specific Styles.
- Added 10 production `64 x 64` bundled SVG weather icons under `Sources/RunningOverlay/Resources/Icons/`, mapped via `WeatherCondition.bundledSVGName`, and switched `WeatherConditionIconView` to render those assets through `IconView`.
- Added `WeatherIconAssetTests` to verify every weather condition resolves its bundled SVG.

### Weather Widget Divider and Slot Refinement

- Removed the ineffective Card Color control from Weather Widget Appearance; card surfaces are palette-owned in the 1.0 UI.
- Added Appearance controls for divider color, width, and opacity, and wired those settings into SwiftUI weather preset rendering.
- Added a Show Divider toggle that removes preset divider lines while preserving divider color, width, and opacity settings.
- Tightened Simple Card's left block so the vertical divider sits closer to the icon group.
- Added horizontal and vertical divider rendering to Forecast Tile.
- Increased Dashboard Bar's default size to `560 x 112` and enlarged metric chips so labels and values remain readable.
- Added the `-` metric slot option; selected empty slots render no metric content and do not show manual metric input rows.
- Updated inline Feels Like metric rendering so Card/Tile rows show text such as `Feels 12°C`, while Dashboard Bar keeps label and value separated in the chip.
- Updated Weather Widget design, structured spec, and module docs to reflect the current 1.0 customization surface.

## 2026-04-30 (continued)

### Weather Widget Implementation Plan

- Added a detailed implementation plan to `docs/overlay-modules/weather-widget-overlay.md`, covering all 11 steps from data model through tests.
- Decided: `cachedWeather: WeatherPayload?` lives inside `WeatherWidgetStyle` (not on `ProjectDocument`) so the cached API result round-trips through the Codable project snapshot and export remains offline-deterministic after a fetch.
- Decided: Phase 2 weather API will use Open-Meteo historical archive (free, no key required) keyed on the activity GPS start point and start timestamp, with hourly resolution.
- Decided: add a dedicated `OverlayCategory.weather` in the Overlay Pool rather than folding the widget into the metrics category.

## 2026-05-01

### Weather Widget Design Spec

- Added the Weather Widget Overlay design spec under `docs/design/overlays/weather-widget/`.
- Captured the approved five-preset weather app plugin direction in `weather-widget-presets.png`: Simple Card, Compact Strip, Forecast Tile, Minimal Text, and Dashboard Bar.
- Captured the unified weather condition icon family in `weather-icon-set.png`, including Sunny, Clear Night, Partly Cloudy, Cloudy, Rain, Heavy Rain, Thunder, Snow, Fog, and Wind.
- Added a structured UI spec and module note documenting the first-pass data strategy: FIT temperature/manual fields first, weather API later with cached deterministic export data.
- Updated the design and overlay module indexes.

### Elevation Chart Gradient Inspector Layout

- Updated the Elevation Chart `Line & Fill` inspector so the fill gradient color controls are stacked as `From` and `To` rows instead of two full swatch strips on one row.
- Kept the existing start/end fill color bindings intact; this is a layout-only change to prevent the gradient editor from widening the edit panel.
- Updated the Elevation Chart module docs and UI design spec to document the stacked `From` / `To` gradient editor.

## 2026-04-30

### Distance Timeline Axis Labels And Marker Label

- **Start / Finish** and **More Points** are independent toggles again (`showAxisLabels`, `showDistancePoints`), each with its own **Below / Above** placement and offset (`distancePointOffset` for endpoints, `midpointAxisLabelOffset` for midpoints; legacy JSON without `midpointAxisLabelOffset` inherits the stored `distancePointOffset` value).
- **Marker Label** (`markerDistanceLabelEnabled`) shows current distance at the playhead (`markerDistanceText` on `OverlayDistanceTimelineRenderLayout`), with `markerDistanceLabelPlacement` and `markerDistanceLabelOffset`; typography follows the Axis font settings.
- **Marker Size** (`currentMarkerSizeMultiplier`) scales marker rendering in preview and export.
- Fixed SwiftUI axis label typography by removing the extra `.font` that applied the main overlay font on top of the axis font.
- Updated Distance Timeline UI spec, module note, `development.md`, and implementation.

### Project Settings And Font Library Design Spec

- Added the formal Project Settings and Font Library UI spec under `docs/design/panels/project-settings/`.
- Captured the approved mockup in `project-settings-font-library.png`.
- Documented the shared macOS dark modal language: centered titles, grouped bordered sections, stable rows, footer dividers, and blue primary actions.
- Specified the Project Settings structure using only current settings: `Video`, `Encoding`, and `Typography`.
- Specified Font Library rows with checkbox selection, font-family rendering, and right-aligned numeric running previews such as `5'42"/km` and `10.24 km`.
- Updated the Font Library implementation plan and design README to point at the new spec and mockup.
- Added `font-library-default-inline.png` and documented the inline default-font interaction: the current default shows a blue `Default` pill after the font name, while other favorite rows reveal a gray `Default` button in that position on hover.

### Borderless Status Bar Settings Button

- Updated `MainEditorView` status bar `gearshape` button to a borderless icon-only style (`.buttonStyle(.plain)`), so it no longer visually touches the top/bottom edges of the 34 px bar.
- Kept the bottom area height unchanged; only the button presentation changed.
- Added a design-system note in `docs/design/system/app-ui.md` clarifying that compact app-chrome utility actions may use a borderless icon-button variant.

### Replace FIT Button in Media Pool

- Added `ProjectDocument.fitSourceName` (`@Published var`) to track the filename of the currently loaded FIT file.
- `importFitFile()` sets `fitSourceName` to `url.lastPathComponent` on successful import.
- `MediaBrowserView`: added a "Replace FIT" underlined text button directly below the step indicator in `videoImportPlaceholder` (shown when FIT is loaded but no videos yet).
- `MediaBrowserView`: added a FIT status row (green dot + filename + "Replace" link) at the bottom of the filter strip, shown only when media items exist and a FIT is loaded. The bottom border is now owned by the outer `VStack` wrapping both the count/filter row and the FIT row.

### Layout Opacity Applies To Whole Overlay

- Added element-level `OverlayElement.opacity` with `ProjectDocument.setOverlayOpacity`.
- Updated `OverlayLayoutInspectorRows` so the shared Layout `Opacity` row controls the whole overlay instead of binding to background opacity.
- Applied element opacity at both render entry points: `PreviewCanvasView` for live preview and `OverlayFrameRenderer` for export.
- Persisted template opacity through `OverlayTemplateElement`, with a default of `1` for existing templates.

## 2026-04-29

Note:

- Historical entries below may reference `OverlayVideoExporter` as part of the migration timeline. That exporter is now retired; active export runtime uses `SwiftUIOverlayVideoExporter` only.

### Decor Overlay Category — Phase C1 (SVG smoke-test gate)

Spike that gates the IconRendering design before Phase C2 builds it. The previous DistanceTimeline Lower Third icon attempt failed because some SVGs that render fine in WebKit/preview do not render via the path the exporter uses; this test proves macOS-native SVG works in **both** paths so we can keep the design dependency-light.

Result: all three fixture SVGs (simple, `<style>`-block, multicolor) load via `NSImage(contentsOf:)` *and* rasterize successfully into an offscreen `CGContext` with non-trivial pixel coverage. **Gate passed — staying on macOS-native SVG. No SVGKit dependency needed for Phase C2.**

Lottie is intentionally not exercised here; the C6 step will add `lottie-spm` and a separate animation smoke test.

Summary:

- New `Tests/RunningOverlayTests/IconRenderingSmokeTests.swift` — three `@Test` cases covering simple / styled / multicolor SVGs. Each loads as `NSImage`, then draws into a 128×128 RGBA `CGContext` and asserts more than 100 non-transparent pixels.
- New fixtures under `Tests/RunningOverlayTests/Fixtures/Icons/` — `simple-circle.svg`, `styled-square.svg` (uses `<style>` + classes), `multicolor-flag.svg`.
- `Package.swift` — test target gains `resources: [.copy("Fixtures")]` so the SVG files are bundled and resolvable via `Bundle.module`.

Files changed:

- `Package.swift`
- `Tests/RunningOverlayTests/IconRenderingSmokeTests.swift` *(new)*
- `Tests/RunningOverlayTests/Fixtures/Icons/simple-circle.svg` *(new)*
- `Tests/RunningOverlayTests/Fixtures/Icons/styled-square.svg` *(new)*
- `Tests/RunningOverlayTests/Fixtures/Icons/multicolor-flag.svg` *(new)*
- `docs/project-log.md`

Verification:

- `swift build` clean.
- `swift test --filter IconRenderingSmokeTests` — 3/3 pass.
- `swift test` full suite — 61/61 pass (was 58; +3 from this spike).

Plan reference: step **C1** of `~/.claude/plans/overlay-pool-solid-color-layout-bg-effe-shiny-pudding.md`. Next up: **C2** (`IconAsset` enum + Codable round-trip test).

### Decor Overlay Category — Phase A + Phase B (Solid Color end-to-end)

Adds the full **Decor** overlay category to the Pool with the first usable subtype — **Solid Color** — wired end-to-end through model, mutators, live preview, SwiftUI export, and inspector. Decor elements are activity-data-independent visual primitives; Phase B ships the rectangle / rounded rectangle / circle / capsule shape with fill, layout, border, and effects. Icon (Phase D) and Text (Phase F) are scaffolded with placeholder inspectors only.

Note: this work was previously partially landed in a worktree branch that was deleted before commit; this entry consolidates A1→B6 onto develop in a single pass.

Summary:

- **Model (A1, B1)**: `OverlayElementType` gains `decorSolidColor`, `decorIcon`, `decorText` plus `isDecorOverlay` helper. Exhaustive switches in `OverlayValueFormatter`, `NumericOverlayDetailView.numericIcon`, `OverlayUnitOption.options(for:)`, and `OverlayElementType.supportsTextPresets` updated. New `DecorShape` enum (`rectangle | roundedRectangle | circle | capsule`) and `DecorStyle` sub-struct (`shape`, `fillColor`, `width`, `height`, `cornerRadius`) live at the bottom of `OverlayElement.swift`. Wired `var decor: DecorStyle` into `OverlayStyle`'s declaration, default, init, and decoder via `decodeIfPresent ?? .default` so older project files round-trip.
- **Pool (A2)**: `OverlayCategory` gains `.decor`; three tiles (`decorSolidColor` / `decorIcon` / `decorText`) appended to `OverlayTileInfo.all`. Segmented Pool tab picks them up automatically.
- **Inspector dispatch (A3)**: `ParameterPanelView` routes `isDecorOverlay` elements to the new `DecorOverlayDetailView`. Inspector switches on subtype internally — Solid Color shows full sections, Icon/Text show placeholder until later phases.
- **Mutators (B2)**: `ProjectDocument` gains `setDecorShape`, `setDecorFillColor`, `setDecorSize(width:height:)`, `setDecorCornerRadius`, plus generic `mutateDecorStyle` / `mutateDecorStyleContinuous` helpers. Discrete edits use `registerUndoPoint()`, drags use `registerContinuousUndoPoint()`. Switching to `.circle` collapses width/height to the shorter side (mirrors `setOverlayRouteMapShape`).
- **Layout helper (B3 prep)**: New `OverlayRenderModel.decorSolidColorLayout(for:in:)` returns `DecorSolidColorRenderLayout` (shape, pixel size, fill color, scaled corner radius) — same canvas-DPR / element-scale convention as the other overlays.
- **Preview + export (B3, B4)**: New `Sources/RunningOverlay/UI/DecorOverlayViews.swift` defines `OverlaySharedDecorSolidColorView` + `DecorSolidColorOverlayView`. The shared view honors the existing `OverlayStyle` border / shadow / glow flags so the standard inspector modules apply unchanged. Dispatch arms added to both `PreviewCanvasView` and `SwiftUIOverlayVideoExporter` so live preview and exported MOV are pixel-identical.
- **Inspector (B5)**: `DecorOverlayDetailView` composes existing primitives directly — `InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseSegmented`, `InspectorDenseSwatchStrip`, `OverlayLayoutInspectorRows` (Position / Scale / Width / Height / Opacity), plus the shared `OverlayBorderInspectorModule` and `OverlayEffectsInspectorModule`. No wrapping, no second-pass redesign of those primitives. Sections: Layout, Shape (segmented + corner-radius slider), Fill (color swatches), Border, Effects.
- **Default preset (B6)**: `defaultOverlayStyle(for:)` seeds `decorSolidColor` with a 240×80 white rounded rectangle and turns off `backgroundEnabled` (the shape *is* the background) so the new element is immediately visible on the canvas.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/OverlayPoolView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/DecorOverlayDetailView.swift` *(new)*
- `Sources/RunningOverlay/UI/DecorOverlayViews.swift` *(new)*
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `docs/project-log.md`

Verification:

- `swift build` clean.
- `swift test` — all 58 tests pass; legacy template round-trip preserved by `decodeIfPresent ?? .default`.

Plan reference: phases **A1 → B6** of `~/.claude/plans/overlay-pool-solid-color-layout-bg-effe-shiny-pudding.md`. Next up: Phase **C** (Icon subsystem foundation — `IconAsset` / `IconRendering` smoke test gate).

### Extract Dense Inspector Components

Summary:

- Moved the shared dense Inspector primitives out of `NumericOverlayDetailView.swift` and into `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`.
- Kept existing type names and APIs unchanged (`InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseAxisField`, `InspectorDenseSegmented`, `InspectorDenseMenuLabel`, `InspectorDenseSwatchStrip`, `InspectorAnchorGrid`, `InspectorDetailFooterBar`, and `NumericTokens`) so existing overlay detail views continue to use the same components without call-site churn.
- Updated design documentation to point at the shared component file instead of treating these primitives as Numeric Overlay internals.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/project-log.md`

### Group Inspector Row Files

Summary:

- Moved the four shared inspector row files into `Sources/RunningOverlay/UI/InspectorRows/` so reusable row components are easier to find.
- Renamed `StatsBarInspectorRows.swift` and its view type to `OverlayStatsBarInspectorRows` to match the `Overlay...InspectorRows` naming convention used by the background, border, and effects row files.
- Updated overlay detail views and inspector documentation to reference the new component name and path.

### Extract Shared Layout Inspector Rows

Summary:

- Moved the shared Layout inspector rows out of `NumericOverlayDetailView.swift` and into `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift`.
- Renamed `OverlayLayoutRows` to `OverlayLayoutInspectorRows` so the Layout component follows the same `Overlay...InspectorRows` naming convention as the other shared inspector row files.
- Kept `CollapsibleLayoutInspectorSection` beside the Layout rows so all overlay detail views use one shared Layout section chrome plus one shared body row component.
- Updated all overlay detail views and design docs to reference `OverlayLayoutInspectorRows`.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayBackgroundInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayBorderInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayEffectsInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayStatsBarInspectorRows.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/ElevationChartOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `docs/development.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.spec.json`
- `docs/design/overlays/elevation-chart/elevation-chart-overlay-ui.md`
- `docs/design/overlays/elevation-chart/elevation-chart-overlay-ui.spec.json`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/inspector/inspector-ui.spec.json`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/overlay-modules/elevation-chart-overlay.md`
- `docs/overlay-modules/route-map-overlay.md`
- `docs/project-log.md`

### Finalize Shared-Component SwiftUI Export Path

Summary:

- Removed residual per-overlay experimental view implementations from `SwiftUIOverlayVideoExporter`; export now keeps only the shared component route used by preview (`OverlaySharedTextPresetView`, `OverlaySharedDistanceTimelineView`, `OverlaySharedRouteMapView`).
- Updated SwiftUI export filtering to render all visible overlays through the shared-component path, so coverage now matches the full current control set.
- Extended shared-component SwiftUI export coverage to all current overlay controls by adding shared wrappers and exporter dispatch for Elevation Chart, Running Gauge, Lap List, Lap Card, and Lap Live.
- Updated SwiftUI exporter overlay filtering from partial-type checks to `isVisible` so all visible overlays render through the shared-component path.
- Updated `docs/requirements.md` and `docs/development.md` with explicit next-step export optimization directions (layer caching, dirty-region redraw, adaptive quality knobs, and structured performance telemetry).
- Retired legacy export-mode code after parity verification: removed `OverlayVideoExporter` usage and mode-toggle UI, and switched `Export` / `Export Full Activity` / `Export Test Clip` / `Export Test Frame` to the unified SwiftUI shared-component pipeline.

Files changed:

- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

### Unify Preview And SwiftUI Export Call Sites

Summary:

- Updated `PreviewCanvasView` to call shared overlay wrappers for text preset, distance timeline, and route map rendering.
- Updated `SwiftUIOverlayVideoExporter` to call the same shared wrappers with `isInteractive: false`, so export disables selection affordances while keeping component visuals aligned with preview call sites.
- This completes the second step after shared entry-point extraction: both preview and export now invoke the same overlay view entry points.
- Removed an extra horizontal flip transform in SwiftUI experimental video frame drawing to fix mirrored output in `Export SwiftUI Test Clip`.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `docs/project-log.md`

### Extract Shared Overlay View Entry Points

Summary:

- Added a new shared UI file `OverlaySharedViews.swift` with reusable entry-point wrappers for text preset, distance timeline, and route map overlays.
- Exposed `TextPresetOverlayView`, `DistanceTimelineOverlayView`, and `RouteMapOverlayView` at module scope so shared wrappers can reference the same component implementations.
- This sets up the follow-up step where Preview and SwiftUI export both call the same shared view entry points while passing different interactivity flags.

Files changed:

- `Sources/RunningOverlay/UI/OverlaySharedViews.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/project-log.md`

### SwiftUI Per-Frame Export Experiment (Scheme A)

Summary:

- Added a new experimental export pipeline `SwiftUIOverlayVideoExporter` that rasterizes SwiftUI overlay content with `ImageRenderer` per frame and writes transparent MOV via `AVAssetWriter`.
- Added `ProjectDocument.exportSwiftUITestClip(to:)` and `runSwiftUIExport(...)` so this path has independent progress/cancellation handling without changing the existing `OverlayVideoExporter` path.
- Added an `Export SwiftUI Test Clip` action in `ExportDialogView` to trigger the experiment.
- Expanded experiment scope: now renders visible numeric overlays, Distance Timeline, and Route Map through SwiftUI per-frame rasterization for Scheme-A feasibility/performance comparison.
- Added `Export SwiftUI Test Frame` to write one PNG through the same Scheme-A rasterization path at the current playhead.
- Added `Export Overlay JSON` to save the current `OverlayLayout` to `overlay_configuration.json`.
- Split export actions into two button rows in `ExportDialogView` to avoid cramped controls.

Files changed:

- `Sources/RunningOverlay/Export/SwiftUIOverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

### Numeric Overlay Preview Uses Export Renderer

Summary:

- Started the shared-renderer migration on a narrow slice: numeric overlays now render their Preview visual content through `OverlayFrameRenderer`.
- Added `OverlayFrameRenderer.renderNumericPreviewImage(...)`, which renders a single numeric element into the fitted preview canvas, flips the bitmap into display orientation, crops it to the element bounds, and returns an `NSImage` for SwiftUI.
- Added `NumericOverlayRenderedPreviewView` in `PreviewCanvasView`; SwiftUI still owns selection outlines, dragging, snapping, and fallback rendering, while numeric text/background/effects come from the export renderer path.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/project-log.md`
### Fix Test Export Orientation/Timing/Accent Parity

Summary:

- Fixed `Export Test Frame` vertical inversion by adding optional post-render row flipping to PNG export and enabling it for test frame export.
- Fixed test clip/frame sampling mismatch by converting playhead project time to activity elapsed time before clamping/quantization.
- Fixed text preset export accent mismatch by using `element.style.accentColor` instead of system accent color in export text preset colors.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

### Rename Test Export API In ProjectDocument

Summary:

- Renamed `ProjectDocument` test export APIs from calibration-oriented names to test-oriented names so method semantics match current behavior.
- `exportCalibrationOverlay(to:)` is now `exportTestClip(to:)`.
- `exportCalibrationFrame(to:)` is now `exportTestFrame(to:)`.
- Updated `ExportDialogView` button actions to call the renamed methods.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/project-log.md`

### Route Map: Runner Position Dot Color

Added a dedicated color picker for the runner's current-position dot in the Route Map overlay inspector (Markers section, "Position Color" row).

Previously the dot always used the route line's foreground color. Now it has its own `routeMapRunnerDotColor` property, defaulting to `foregroundColor` on decode so existing projects look identical.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift` — added `routeMapRunnerDotColor: OverlayColor` to `OverlayStyle`; decoded after `foregroundColor` so the fallback is available
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift` — runner dot now uses `NSColor(element.style.routeMapRunnerDotColor)` instead of `accent`
- `Sources/RunningOverlay/Project/ProjectDocument.swift` — added `setOverlayRouteMapRunnerDotColor`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift` — added "Position Color" swatch row in `markersSection`

### Fix Split Label and Racing Stripe label/line color roles

Summary:

- **Split Label**: the horizontal rule under the label was using `NSColor.controlAccentColor` (macOS system accent) instead of the element's user-configured `accentColor`. Fixed to use `NSColor(element.style.accentColor)`.
- **Racing Stripe**: the label text was rendered in the element's `accentColor`, conflating the stripe color role with the label text role. Fixed to use `colors.foreground` (`element.style.foregroundColor`) so label color is controlled by the same "Color" picker as the rest of the text, while the vertical stripe continues to use `accentColor`.

Color responsibility is now consistent across both presets: label text color → foreground/text color; line/stripe color → accent color.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/project-log.md`

### Preview Canvas Overlay Snapping

Summary:

- Added drag-time snapping for Preview overlays using measured rendered overlay frames in fitted-canvas coordinates.
- When safe guides are enabled, overlay left/right/top/bottom edges snap to the 90% and 80% safe-frame guide lines, and overlay center axes snap to the canvas center crosshair.
- Visible overlays can snap to each other's left/center/right and top/center/bottom alignment lines, so neighboring components can be bottom-aligned, top-aligned, left-aligned, right-aligned, or center-aligned while dragging.
- Added temporary non-interactive snap lines during active drag to show which alignment target is being used.
- Fixed the initial frame-measurement placement so dragging uses the overlay's own rendered bounds instead of the whole canvas bounds.
- Updated Preview design and development documentation for snapping behavior.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/development.md`
- `docs/design/panels/preview/preview-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.

### Preview Canvas Drag Performance Optimization

Summary:

- Eliminated per-frame `@Published` mutations during overlay element drag by keeping a local `@State var liveDragPosition` in `PreviewCanvasView`. The position is written to `ProjectDocument` exactly once on drag end, rather than 60+ times per second. This prevents all ProjectDocument observers (Inspector, Timeline, Pool panels) from re-rendering during drag.
- Extracted overlay element rendering into a private `OverlayElementContent` struct conforming to `@preconcurrency Equatable`. With `.equatable()`, SwiftUI skips `body` execution for non-dragged elements when only `liveDragPosition` changes, avoiding redundant `OverlayRenderModel.*Layout()` computations (gauge, map, chart, text) for elements that have not changed.
- Moved selection update (`project.selectOverlay`) and undo checkpoint registration (implicit in `moveOverlay`) from per-frame to once per gesture, removing two sources of per-frame document mutation.
- The `Equatable` comparison covers `element`, `canvasSize`, `sampleTime`, and `isSelected`; `activity` is intentionally excluded because comparing large FIT sample arrays each frame is expensive and `sampleTime` guards layout freshness in practice.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`

Verification:

- Ran `swift build`.
- Ran `swift test` — all tests pass except the pre-existing `runningGaugeLayoutCarriesCoreMetricsAndProgress` time-format assertion failure in `OverlayRenderModelTests`.

### Templates Pool Implementation

Summary:

- Added `Templates` as the third top-toolbar Pool mode.
- Added `TemplatePoolView` with compact name-only rows for built-in and user templates.
- Added built-in templates: `Easy Run`, `Interval Workout`, and `Race`.
- Added confirmation dialogs before built-in or user templates clear and replace the current overlay layout.
- Added user-template context menu actions for rename, duplicate, export, and delete.
- Added footer actions with a small icon-only import button and a primary `Save Current as Template` button.
- Removed the Overlay Templates management section from Project Settings.
- Added ProjectDocument APIs for generated-name saves, built-in template application, rename, and duplicate.
- Added template tests for generated-name save, rename, duplicate, and built-in replacement undo.
- Refined Templates Pool rows to use explicit horizontal separators, removed the accidental center divider, and removed the blank-area import context menu from built-in template space.
- Replaced the placeholder `Easy Run` built-in with the bundled `EasyRun.rotemplate` resource supplied from `/Users/codywang/Desktop/running_overlay/Test 2/Template.rotemplate`.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Resources/Templates/EasyRun.rotemplate`
- `Sources/RunningOverlay/UI/PoolPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/TemplatePoolView.swift`
- `Tests/RunningOverlayTests/OverlayTemplateTests.swift`
- `docs/development.md`
- `docs/project-log.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`

Verification:

- Ran `swift build`.
- Ran `swift test --filter OverlayTemplateTests`.
- Full `swift test` still has the pre-existing Running Gauge time-format assertion failure in `OverlayRenderModelTests`.

### Templates Pool Design Direction

Summary:

- Expanded the left Pool design from two modes to three: `Media Pool`, `Overlay Pool`, and `Templates`.
- Documented Templates Pool as the single template-management surface, replacing Project Settings template controls.
- Defined a compact name-only row treatment for built-in and user templates: no leading icons, no trailing buttons, and no visible ellipsis controls.
- Defined first-pass built-in templates: `Easy Run`, `Interval Workout`, and `Race`.
- Specified that applying any template clears and replaces current overlays only after confirmation.
- Specified user-template right-click actions: rename, duplicate, export, and delete.
- Specified the footer layout: a small square import button on the left and a long `Save Current as Template` primary button on the right.

Files changed:

- `CLAUDE.md`
- `docs/architecture.md`
- `docs/design/README.md`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/design/system/app-ui.md`
- `docs/development.md`
- `docs/project-log.md`
- `docs/requirements.md`
- `docs/roadmap.md`

Verification:

- Validated updated JSON specs.

### Left Pool Split And Overlay Pool

Summary:

- Added a top-toolbar `Media Pool` / `Overlay Pool` switch backed by `MainEditorView` state, with `PoolPanelView` rendering the selected left-pane content.
- Moved the add-overlay catalog out of the Inspector and into `OverlayPoolView`, preserving the Metrics, Charts, and Route categories.
- Removed global toolbar FIT/Videos import buttons; Media Pool now owns the import workflow.
- Updated the no-media state to be FIT-first: `Import FIT` before activity data exists, then `Import Videos` after FIT import.
- Changed Inspector outer state to show only `Added Overlays`; detail inspectors and row management actions remain unchanged.
- Updated design, requirements, architecture, and development docs for the new left Pool/Inspector responsibility split.

Files changed:

- `Sources/RunningOverlay/UI/PoolPanelView.swift`
- `Sources/RunningOverlay/UI/OverlayPoolView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/inspector/inspector-ui.spec.json`
- `docs/design/system/app-ui.md`
- `docs/design/README.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Media Pool Status Dot Cleanup

Summary:

- Removed the long right-side alignment status text from media rows.
- Added compact alignment-status dots with hover help text containing the full status label, such as `Aligned by timestamp`.
- Removed the trailing ellipsis icon because row actions are already available through the context menu and the icon did not open a visible menu.
- Added hover help for media mark dots.
- Updated the Media Pool design docs, structured UI spec, and development notes to reflect the current row behavior.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/design/panels/media-pool/media-pool-ui.md`
- `docs/design/panels/media-pool/media-pool-ui.spec.json`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

## 2026-04-28

### Shared Stats Bar + Shared Layout Final Unification

Summary:

- Finalized shared Stats Bar inspector behavior across Distance Timeline and Route Map using one component pair: `CollapsibleStatsBarInspectorSection` + `OverlayStatsBarInspectorRows`.
- Unified the full Stats Bar control surface to the original Distance Timeline set: Placement, Inside, Layout, Size, Width, Offset, Item Gap, Background, Dividers, Radius, and Slot 1-4.
- Moved the Stats Bar Enabled toggle to the section header (left of chevron) and standardized the icon to `tablecells`.
- Added Route Map inside-mode behavior updates: inside bars reserve map-content padding (do not cover route lines), inside bar background merges with container clipping/radius, and left/right placements force vertical stack with Item Gap applied as vertical spacing.
- Unified Stats Bar rendering: Route Map and Distance Timeline now use one shared Preview renderer (`SharedStatsBarContentView`) and one shared Export renderer path (`drawSharedStatsBar`), using Distance Timeline visual logic as baseline.
- Finalized shared Layout inspector behavior across overlay detail panels with one component pair: `CollapsibleLayoutInspectorSection` + `OverlayLayoutInspectorRows`.
- Standardized shared Layout row set to Position, Scale, Width, Height, Opacity (no Rotation), and applied section-ordering rule consistently across detail views.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayStatsBarInspectorRows.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/overlay-modules/route-map-overlay.md`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build` multiple times after each integration step — Build complete, no errors.

### Shared OverlayLayoutInspectorRows Component + Section Ordering

Summary:

- Extracted the Position/Scale/Width/Height controls used in every overlay detail view into a single shared `OverlayLayoutInspectorRows` struct, now located in `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift`.
- Removed the Anchor (3×3 grid) and Padding controls from all layout sections. Position is now always set by numeric X/Y fields only.
- `OverlayLayoutInspectorRows` accepts optional `widthBinding`/`heightBinding` parameters; pass `nil` to hide those rows. Running Gauge passes `nil` for both (square component — no explicit dimensions). Distance Timeline passes both. Route Map, Numeric, and Lap views omit them.
- Rotation is intentionally excluded from the shared Layout rows so the cross-overlay Layout surface stays fixed.
- LapList, LapCard, and LapLive's Position section now shows Position X/Y + Scale instead of Scale only.
- Section ordering rule applied: if a detail view has a Preset section it must be first; otherwise Layout is first. Distance Timeline was reordered to: Preset → Layout → Value → Label → …

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayLayoutInspectorRows.swift` (added `OverlayLayoutInspectorRows`)
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/route-map/route-map-overlay-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build` — Build complete, no errors.

### Extract Shared OverlayStatsBarInspectorRows Component

Summary:

- Extracted the Stats Bar inspector UI shared between Distance Timeline and Route Map overlays into a new `OverlayStatsBarInspectorRows` view in `OverlayStatsBarInspectorRows.swift`.
- The shared component renders Placement, Layout, Height, Background, Dividers, Radius, and Slot rows, which are identical in both overlays.
- Distance Timeline-specific rows (Inside toggle; Width, Offset X/Y, Item Gap via `ExtraLayoutConfig`) are passed as optional config; Route Map-specific rows (Blur) are passed as an optional value.
- Moved `RouteMapStatsBarPlacement.distanceTimelinePlacements` from a private extension in `DistanceTimelineOverlayDetailView` to the shared file so both callers can reference it.
- Both detail views now delegate to `OverlayStatsBarInspectorRows`, eliminating ~80 lines of duplicated UI code.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/OverlayStatsBarInspectorRows.swift` (new)
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build` — Build complete, no errors.

### Locked Element List-Click Guard

Summary:

- Updated `Added Elements` row navigation so locked overlays cannot open the detail inspector from the list.
- Clicking a locked row now shows a status/toast-style message prompting the user to unlock before editing.
- Kept existing lock behavior unchanged for canvas interaction and context-menu actions.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Overlay Property Copy/Paste Menus

Summary:

- Added right-click `Copy Properties` / `Paste Properties` actions to Inspector Added Elements rows and Preview overlays.
- Implemented model-level copy buffer in `ProjectDocument` and paste validation by overlay category.
- Added `OverlayElementType.pasteCategory` so numeric overlays can paste only to numeric overlays, while non-numeric modules paste only within their own category.
- Paste now applies copied configuration fields (`scale`, `isVisible`, `isLocked`, `style`) to the target element while preserving target identity/type.
- Updated Inspector/Preview/development/requirements documentation for the new context-menu workflow.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/preview/preview-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Added Elements Visibility/Lock Actions

Summary:

- Implemented `Added Elements` row visibility and lock actions with real model-backed state.
- Added persistent `OverlayElement.isVisible` / `OverlayElement.isLocked` fields and template-schema compatibility defaults for older templates.
- Updated Preview behavior so hidden overlays are not rendered and locked overlays cannot be selected/dragged from canvas.
- Updated export rendering so invisible overlays are skipped by `OverlayFrameRenderer`.
- Synced Inspector/Preview/development/requirements docs to reflect shipped behavior.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/design/panels/preview/preview-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Lower Default Timeline Height On Launch

Summary:

- Reduced the initial vertical footprint of the Timeline panel so newly opened windows dedicate more space to Media/Preview/Inspector editing.
- Kept timeline resizing behavior unchanged by only adjusting `TimelineView` default frame targets.
- Updated development documentation to record the new default split allocation.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Preview Corner Handle Scale Drag

Summary:

- Upgraded selected-overlay corner handles in preview from visual affordances to interactive drag handles.
- Dragging any of the four blue corner handles now scales the selected overlay by directly updating `OverlayElement.scale`.
- Grouped scale drag updates as a continuous undo operation and commit at drag end.
- Updated preview/requirements/development docs so overlay-canvas interaction behavior matches implementation.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/design/panels/preview/preview-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Numeric Overlay Label/Unit Split + Background Effects

Summary:

- Refactored `NumericOverlayDetailView` to split Label and Unit into standalone sections with independent header toggles.
- Removed label/unit switches and label text editing from Content; Typography now controls value text only.
- Added independent label/unit typography controls (`font`, `size`, `weight`) and independent position controls (`top`, `bottom`, `left`, `right`).
- Added background fade-out and gaussian blur controls in the Numeric overlay background section.
- Standardized new numeric overlays to default to `Minimal Clean`.
- Updated preview/render model + style decoding to support new label/unit and background fields while keeping older projects loadable.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Clip Inspector Dense Sizing Pass

Summary:

- Tightened the selected clip Inspector to match the dense detail-view tokens used by `NumericOverlayDetailView`.
- Removed extra top padding before the clip timing section.
- Reduced clip detail section headers, rows, controls, and icon buttons to the shared dense dimensions.
- Moved `Apply to all clips in this layer` directly below the Offset row instead of keeping it in a sticky footer.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 55 tests passed.

### Upper Panel Divider Tightening

Summary:

- Removed the visual padding created by the upper horizontal resize handles between Media Pool, Preview, and Inspector.
- Kept a wider invisible drag target over the 1 px divider so the split lines remain easy to resize while the panels visually butt together.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 55 tests passed.
- Ran `swift build`.

### Timeline Ruler Hover Placement

Summary:

- Split the timeline ruler into a reserved hover-info band above the time scale and a lower scale band for ticks and labels.
- Moved the ruler hover info pill into the upper band so it no longer sits under the mouse cursor.
- Kept the pill arrow aligned to the hovered ruler position.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/design/timeline-ui.md`
- `docs/design/timeline-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 53 tests passed.
- Ran `jq empty docs/design/timeline-ui.spec.json`.

### Media Pool Row Refinement

Summary:

- Refined Media Pool rows against `Runner Overlay Design System/preview/components-rows.html`.
- Split search and status filters into distinct compact rows with design-system padding and borders.
- Tightened media row layout to 72 px height, 42 px thumbnail well, compact metadata, muted right-side status text, mark dot, and trailing more affordance. This was later simplified to a status dot with hover help and no trailing ellipsis.
- Adjusted status filter chips to use the solid active-blue treatment from the row component reference.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 52 tests passed.

### Clip Inspector Detail Style Alignment

Summary:

- Replaced the selected timeline clip Inspector's generic panel presentation with a dedicated clip detail view matching overlay detail structure.
- Added a clip detail header with back navigation, video icon, clip title, Clip pill, live layer/start summary, and delete action.
- Restyled clip timing controls as dense detail rows with a `Clip Timing` section header, editable layer field, Start and Offset numeric inputs, and preserved double-click reset behavior.
- Initially moved the layer-wide offset apply action into the clip detail footer; a follow-up sizing pass moved it directly below the Offset row to match the denser detail-view layout.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 52 tests passed.

### Distance Timeline Overlay Style System Design

Summary:

- Added a Distance Timeline Overlay design board with eight visual directions: Minimal, Dense, Sport, Splits, Glass, Neon, Lower Third, and Route.
- Added implementation-facing UI documentation for `OverlayElementType.distanceTimeline`, including preset behavior, progress track controls, typography, background, border, fade out, and effects.
- Defined customizable left media slots for Sport and Lower Third presets, including static SVG, animated SVG, image, icon, and future video-loop modes.
- Defined Route/Elevation customization, including route/path modes, start/finish/current markers, elevation profile, shaded area under the elevation line, shadow blur, and progress clipping.
- Documented border toggle, edge fade/fade-out behavior, background/material controls, current model gaps, and phased implementation guidance.
- Added the module to `docs/overlay-modules` so follow-up implementation work has both product-level and UI-level guidance.

Files changed:

- `docs/design/README.md`
- `docs/design/distance-timeline-overlay-ui.md`
- `docs/design/distance-timeline-overlay-ui.spec.json`
- `docs/design/distance-timeline-overlay-styles.png`
- `docs/overlay-modules/README.md`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/distance-timeline-overlay-ui.spec.json`.
- Documentation/design-only change; tests not run.

## 2026-04-27

### Detail Header Tap Area And Margin Cleanup

Summary:

- Updated detail view section headers so collapse/expand is triggered by tapping the full header row, not only the chevron icon.
- Applied this interaction change consistently across Numeric Overlay, Running Gauge, Route Map, and Lap List detail views.
- Removed extra inner scroll container paddings from these detail views to eliminate unintended outer margins and inter-section spacing artifacts.
- Kept existing control bindings and feature behavior unchanged; this is a visual and hit-area refinement only.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Inspector Outer Components Compactness Pass

Summary:

- Updated the outer Inspector (`Add Overlay` and `Added Elements`) to better match the compact density shown in `Runner Overlay Design System/preview/components-inspector.html`.
- Reduced segmented control visible height, tile icon scale, tile min-height, and added-row action button size to tighten vertical rhythm while keeping comfortable click targets.
- Adjusted outer panel and row horizontal paddings for denser composition.
- Fixed the add-tile plus icon alignment by giving the trailing plus a dedicated compact frame so it no longer appears overly flush-right.
- Kept the footer hint text removed (`Click an overlay to edit its style and position` remains absent).

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Detail Views Pixel-Level Polish Pass

Summary:

- Applied a pixel-level UI polish pass across all detail views to better match the `inspector-running-gauge.html` visual spec.
- Standardized switch sizing to mini controls in dense detail rows and section accessories for tighter vertical balance.
- Reduced segmented control visible height in dense detail rows and Lap List segmented pickers for better parity with the compact design target.
- Updated shared detail footers (`Reset` / `Done`) to use a 1:2 width ratio via a shared footer bar component, matching the target action hierarchy.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Lap Detail Delete Placement Alignment

Summary:

- Moved `Lap Live`, `Lap Card`, and `Lap List` overlay deletion into the detail header's trailing trash icon button, matching the existing Numeric, Route Map, and Running Gauge top-bar pattern.
- Removed the bottom delete footers from those three Lap detail views so destructive overlay actions have one consistent location.
- Aligned `Lap Live` and `Lap Card` headers with the shared fixed-height elevated Inspector header styling, including bottom separator and bordered category pill.
- Removed the extra top padding above the first `Lap List` detail section so `Layout` starts directly under the header separator.
- Removed the extra full-section outer stroke from shared `Background`, `Border`, and `Effects` inspector modules to prevent left-edge jitter when those sections expand or collapse.
- Removed the inset scroll padding and card-like section spacing from `Lap Card` and `Lap Live`; their overlay-specific sections now use the same full-width header/body rhythm as `Lap List` and Numeric detail sections.
- Replaced the long dense color preset strip with six mainstream swatches plus a trailing fixed-size custom color button that opens the shared system color panel, preventing fixed preset lists or embedded system picker intrinsic width from forcing narrow Inspector panels to overflow horizontally.
- Increased the Inspector split-pane default and minimum width to 460 px, and raised the app window minimum width to 1300 px so the three-column editor cannot compress the Inspector below its stored width.
- Shortened Numeric Overlay four-option segmented labels in dense rows (`Bot`, `Reg`, `Med`, `Semi`) so Label and Unit section expansion does not push segmented controls past the Inspector edge.

Files changed:

- `Sources/RunningOverlay/UI/InspectorRows/InspectorDenseComponents.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapLiveOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapCardOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayBackgroundInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayBorderInspectorRows.swift`
- `Sources/RunningOverlay/UI/InspectorRows/OverlayEffectsInspectorRows.swift`
- `docs/design/panels/inspector/inspector-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Lap List Detail View Visual Alignment

Summary:

- Updated `LapListOverlayDetailView` to match the same dense detail-view visual structure used by Numeric Overlay, Route Map, and Running Gauge.
- Removed the extra external divider row under the header and moved separator treatment into the header container.
- Updated section header styling to the same top/bottom border rhythm and panel-header background used by other detail views.
- Updated section body spacing to stack rows with the shared row-divider rhythm.

Files changed:

- `Sources/RunningOverlay/UI/LapListOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Detail Views Visual And Interaction Restyle (No Functional Changes)

Summary:

- Restyled dense Inspector detail views to match the design-system `inspector-running-gauge.html` direction more closely while preserving all existing behavior and bindings.
- Applied the updated dense row/section visual language across shared components so Numeric Overlay, Route Map, and Running Gauge detail views all inherit the same spacing, row height, control density, and section divider rhythm.
- Updated section headers to use explicit top/bottom 1 px borders and panel-header surfaces, and updated dense rows to use fixed-height rows with per-row bottom dividers.
- Updated shared dense control sizing (`rowHeight`, `controlHeight`, label column width, and numeric slider value chip width) for stronger visual parity with the design artifact.
- For Running Gauge, added visual sub-section headers for `Outer Ring` and `Progress Ring` (toggle + chevron) to mirror the reference hierarchy and interaction feel without changing any underlying setting logic.
- Moved Route Map and Running Gauge header separators into header views (removing external extra separator rows) to keep top-bar structure and vertical rhythm aligned with other detail views.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Remove Inspector Footer Hint

Summary:

- Removed the bottom Inspector hint bar that displayed `Click an overlay to edit its style and position` in the outer Inspector state.
- Kept the rest of the Inspector layout and add/manage overlay flows unchanged.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Numeric Overlay Header Height Alignment

Summary:

- Aligned the Numeric Overlay detail header bar with the shared top-bar height rhythm used by other editor headers.
- Moved the header separator line into `NumericOverlayHeader` so the panel no longer adds an extra external divider row under the header.
- This removes the extra visual 1 px height and makes the Numeric Overlay top bar match other header bars in both structure and rendered height.

Files changed:

- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Extended FIT Parsing — Running Dynamics + Lap Data

Extended `FitFileParser` and `ActivityTimeline` with two groups of new data:

**Running dynamics (Phase A from the FIT numeric overlay plan)**

Newly parsed FIT record fields (message type 20):

| Field | FIT # | Unit stored | Notes |
|---|---|---|---|
| vertical_oscillation | 39 | mm (double) | uint16 × 0.1 mm |
| ground_contact_time | 41 | ms (double) | uint16 × 0.1 ms |
| stride_length | 84 | m (double) | uint16 × 0.1 mm → m |
| ground_contact_balance | 30 | % (double) | uint8 × 100 (left % * 100) |
| temperature | 13 | °C (double) | sint8 |
| grade | 9 | % (double) | sint16 × 0.01 |

Added to `ActivityRecord`: `verticalOscillationMM`, `groundContactTimeMS`, `strideLengthM`, `groundContactBalance`, `temperatureCelsius`, `gradePercent`.

Added to `ActivityTimeline`: `verticalOscillation(at:)`, `groundContactTime(at:)`, `strideLength(at:)`, `verticalRatio(at:)` (computed: osc/stride × 100), `groundContactBalance(at:)`, `temperature(at:)`, `grade(at:)` — all interpolated.

**Lap data (FIT message type 19)**

Added `LapKind` enum (`warmup / active / rest / cooldown / unknown`) and `LapRecord` struct (lapIndex, startElapsedTime, endElapsedTime, startDistanceMeters, totalDistanceMeters, totalElapsedTime, avgPaceSecondsPerKm, avgHeartRate, maxHeartRate, avgCadenceSPM, avgPowerWatts, totalAscent, kind). Added `laps: [LapRecord]` to `ActivityTimeline`. Classification uses avg speed threshold 3.5 m/s with warm-up/cool-down detection for first and last laps.

Added to `ActivityTimeline`: `currentLap(at:)`, `lapElapsedTime(at:)`, `lapProgress(at:byDistance:)`.

Parser additions: `RawLap` private struct, `makeLap(from:architecture:)` (reads fields 2/7/8/9/13/15/16/17/19/21), `buildLapRecords(startDate:totalLaps:)`, `lapKind(index:total:avgSpeedMS:)`, `parseGroundContactBalance`, int8/int16 decode helpers.

**Numeric overlay types (7 new cases in `OverlayElementType`)**

`verticalOscillation`, `groundContactTime`, `strideLength`, `verticalRatio`, `groundContactBalance`, `temperature`, `grade` — each with corresponding `OverlayUnitOption` cases, `OverlayValueFormatter.components` formatting, `RunningGaugeModel.OverlayGaugeMetric` cases, `numericIcon` SF symbols, and tile entries in the Inspector overlay browser.

Files changed: `FitFileParser.swift`, `ActivityTimeline.swift`, `OverlayElement.swift`, `OverlayValueFormatter.swift`, `RunningGaugeModel.swift`, `NumericOverlayDetailView.swift`, `ParameterPanelView.swift`, `ProjectDocument.swift` (calibration activity `laps: []`), all test files that construct `ActivityTimeline`.

Verification: `swift build` clean. `swift test` — all 51 tests passed.

---

### Lap List Overlay — Teleprompter-Style Lap Course Display

New chart overlay type (`OverlayElementType.lapList`) that renders the full workout lap structure as a vertically scrolling list, centered on the current lap with real-time progress and configurable columns.

**Data model** (`OverlayElement.swift`): Added `LapProgressMode` (distance / time), `LapListAnchor` (top / center / bottom), `LapColumnMetric` (lapNumber / lapKind / distance / elapsedTime / pace / heartRate / cadence / power / ascent), `LapListColumn` (metric + visible), `LapListStyle` (visibleRowCount, currentRowAnchor, fadeEnabled, fadeMinOpacity, progressBarEnabled, progressMode, progressColor, progressOpacity, showCompletedMark, rowHeight, rowCornerRadius, rowSpacing, backgroundOpacity, columns[]). Added `var lapList: LapListStyle` to `OverlayStyle` with `decodeIfPresent` fallback to `.default`.

**Render layout** (`OverlayRenderModel.swift`): Added `LapListRowRenderLayout` (lapRecord, rowRect, progressFraction, isCurrent, rowOpacity, columnTexts) and `LapListRenderLayout`. `lapListLayout(for:in:)` computes: visible window of laps centered at anchor row, per-row opacity from distance-to-current with `fadeMinOpacity` floor, per-row progress (1.0 completed / live fraction current / 0.0 future), column text via `lapColumnText(_:lap:activity:elapsedTime:isCurrent:)`.

**Export renderer** (`OverlayFrameRenderer.swift`): `renderLapList(_:renderContext:)` draws row backgrounds (rounded rect, semi-transparent black), progress bar fills (rounded rect clipped to progress fraction, accent color), current-lap border stroke, and column text laid out in equal-width cells with leading alignment for the first column and centered for the rest. Wired as a new `case .lapList` in `renderElement`.

**Preview** (`PreviewCanvasView.swift`): `LapListOverlayView` SwiftUI view — `VStack` of `lapRow` cells, each a `ZStack` with background, GeometryReader progress bar, optional border stroke, and `HStack` of column `Text` views. Wired as `case .lapList` in `overlayView`.

**Inspector** (`LapListOverlayDetailView.swift`): New dedicated inspector with four collapsible sections: *Layout* (visible rows stepper, current lap anchor segmented picker, row height / spacing / background opacity sliders, fade toggle + min opacity slider), *Progress Bar* (enabled toggle, mode segmented picker, color swatch strip, opacity slider), *Columns* (toggle each of the 9 column metrics), *Position* (scale slider). Header mirrors the Route Map header pattern (back button, icon, title, category pill).

**Routing**: `ParameterPanelView` routes `.lapList` to `LapListOverlayDetailView`. `lapList` tile added to the Charts category in the overlay browser with `isAccent: true`. All 7 new running-dynamics tiles added to the Metrics category.

**ProjectDocument**: Added `mutateLapListStyle(_:_:)` and `mutateLapListStyleContinuous(_:_:)` mutation helpers.

Files changed: `OverlayElement.swift`, `OverlayRenderModel.swift`, `OverlayFrameRenderer.swift`, `PreviewCanvasView.swift`, `ParameterPanelView.swift`, `ProjectDocument.swift`, new file `LapListOverlayDetailView.swift`, `OverlayValueFormatter.swift` (stub case), `NumericOverlayDetailView.swift` (icon), all test files.

Verification: `swift build` clean. `swift test` — all 51 tests passed.

---

### Route Map — Stats Bar (replaces Legend card)

Replaced the bottom-left Start/Finish legend card with a horizontal **Stats Bar** that attaches below the map container. The bar is off by default (`visible = false`) so existing projects are unaffected.

**Data model** (`OverlayElement.swift`): Added `RouteMapStatsMetric` enum (distance / pace / elapsedTime / heartRate / elevation / cadence / power / calories), `RouteMapStatsBarSlot` struct (metric, visible, customLabel), and `OverlayRouteMapStatsBarConfig` (visible, backgroundOpacity, slots[]). Added `routeMapStatsBar: OverlayRouteMapStatsBarConfig` to `OverlayStyle` with `decodeIfPresent` default for backward compatibility.

**Render layout** (`RouteMapOverlay.swift`): Added `OverlayRouteMapStatsBarItemLayout` and `OverlayRouteMapStatsBarLayout` structs. Added `statsBarLayout: OverlayRouteMapStatsBarLayout?` to `OverlayRouteMapRenderLayout`.

**Rect calculation** (`OverlayRenderModel.swift`): `routeMapLayout` now computes `totalRect` (map + bar) centered at `element.position`, splits it into `mapRect` (top) and `statsBarRect` (bottom). Stats bar height = 64 design-pt × element.scale. Slot values are resolved via `OverlayValueFormatter.components`.

**Export renderer** (`OverlayFrameRenderer.swift`): Removed `drawRouteLegend` / `drawLegendItem` / `drawGradientBand` calls. Added `drawRouteMapStatsBar` which renders N equal-width cells with value (large, white), unit (small, 70% white), and label (uppercase, 50% white), separated by thin dividers.

**Preview** (`PreviewCanvasView.swift`): `RouteMapOverlayView.body` is now a `VStack(spacing: 0)` — masked map content on top, stats bar below. Removed `routeLegend` / `legendRow` / `distanceText` helpers. `statsBarView` and `statsBarCell` handle SwiftUI rendering.

**Inspector** (`RouteMapOverlayDetailView.swift`): Rewrote the Legend section as **Stats Bar** — toggle in header, background opacity slider, and 4 slot rows (metric picker + visible toggle each).

**ProjectDocument** (`ProjectDocument.swift`): Added `setOverlayRouteMapStatsBarVisible`, `setOverlayRouteMapStatsBarBackgroundOpacity`, `setOverlayRouteMapStatsBarSlotMetric`, `setOverlayRouteMapStatsBarSlotVisible`.

Files changed: `OverlayElement.swift`, `RouteMapOverlay.swift`, `OverlayRenderModel.swift`, `OverlayFrameRenderer.swift`, `PreviewCanvasView.swift`, `RouteMapOverlayDetailView.swift`, `ProjectDocument.swift`.

---

### Route Map — Edge Fade Preview Fix, Square Fade Fix, Border Toggle, Inspector Cleanup

Three bugs fixed and one new control added, all in the Route Map overlay:

**Edge Fade preview not working (`.luminanceToAlpha()` fix)**

`RouteMapMaskRenderer.makeCGMask` creates a grayscale CGImage with no alpha channel (every pixel has alpha = 1). SwiftUI's `.mask()` modifier reads the mask view's *alpha* channel, not luminance, so the grayscale fade image was treated as fully opaque and had no visual effect. The export path (`CGContext.clip(to:mask:)`) interprets the gray values as luminance and was already correct. Fix: added `.luminanceToAlpha()` to the mask `Image` in `RouteMapOverlayView.body`, converting brightness → alpha before SwiftUI applies the mask.

**Square fade only affecting corners (edge-distance pixel algorithm)**

The original `drawFadeMask` used a radial gradient for both shapes, with the outer radius set to the half-diagonal of the bounding rectangle so the fade would reach every corner. For a square box the half-diagonal is `√2 × (half-side)`, while the center-to-edge-midpoint distance is just `half-side`. The inner boundary `innerRadius = outerRadius × (1 - fadeAmount)` sits close to the edge midpoints, so they receive almost no fade while the corners go fully black — producing the "only corners faded" visual artifact.

Fixed by switching the square case to a **per-pixel minimum-edge-distance** algorithm: `gray = clamp(min(dist_left, dist_right, dist_top, dist_bottom) / fadeWidth, 0, 1)` where `fadeWidth = min(w, h) × 0.5 × fadeAmount`. The shape interior is first filled white using a CGContext clip path (handling rounded corners), then each non-black pixel is multiplied by its edge-distance value. The circle shape retains the existing radial gradient which was already correct.

**Border toggle added to Container section**

The white semi-transparent ring drawn around the container was always-on with no way to disable it. Added `routeMapBorderVisible: Bool` to `OverlayStyle` (default `true`, backwards-compatible via `decodeIfPresent`). The **Border** toggle in the Container inspector section controls the non-selected border in both preview (`RouteMapOverlayView`) and export (`strokeRouteMapBorder`). The selection-state accent border is unaffected.

**Distance row removed from Preset section**

The "Distance" row in the Preset inspector section displayed the total activity distance — a static metadata readout with no configurable effect. Removed to reduce noise; the value already appears in the panel header subtitle.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift` — `routeMapBorderVisible` field
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift` — `borderVisible` in render layout; square fade algorithm
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift` — pass `borderVisible` to layout
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift` — guard on `borderVisible` in `strokeRouteMapBorder`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift` — `.luminanceToAlpha()` on mask image; conditional border overlay
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift` — Border toggle in Container; Distance row removed
- `Sources/RunningOverlay/Project/ProjectDocument.swift` — `setOverlayRouteMapBorderVisible` mutation
- `docs/overlay-modules/route-map-overlay.md` — Phase E bug-fix notes
- `docs/project-log.md`

Verification: `swift build` succeeded with no errors.

### Inspector Segmented Controls Switched To Native Picker (All Inspector Flows)

Summary:

- Replaced Inspector custom segmented button rows with native SwiftUI segmented pickers (`Picker` with `.pickerStyle(.segmented)`).
- Updated all matching Inspector controls in `ParameterPanelView`, and migrated the shared dense segmented control used by Numeric Overlay, Running Gauge, and Route Map detail inspectors.
- Kept existing bindings and model mutations unchanged so behavior remains identical while interaction/focus/keyboard handling uses native control behavior.
- Removed the custom segmented-row implementations in favor of native segmented pickers.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Route Map — Phase E.1 Centering Fix, Decoupled Map Visibility, Adjustable Container Size, Stronger Edge Softness

Bug fixes and follow-up work on the Phase E refactor based on user feedback that (1) the projected route was running outside the map box, (2) the new Container Preset dropdown duplicated the Container section's controls, (3) square containers couldn't be resized independently, (4) Edge Softness barely affected the rendered output, and (5) "show map" was implicitly tied to Route Style.

Summary:

- Fixed the Mercator centering bug in `OverlayRouteMapRenderLayout.project`. `mercatorY` is monotonically *decreasing* in latitude, so the previous code was assigning the southernmost point's y to `minY` and the northernmost's to `maxY`, which produced a near-zero `yRange` (clamped to `0.000001`) and a huge `scale` that threw points way outside the rect. The new implementation computes `min` / `max` from the four projected corners and projects in a y-down coordinate system (matching both the SwiftUI preview and the `flipped: true` AppKit export context). The Container padding is now derived from the box's design size instead of being a flat `18 pt`, so wide rectangles still keep the polyline well inside the visible map. A regression assertion in `OverlayRenderModelTests` walks every projected point and the current point, and verifies they all fall inside `contentRect` (with a 1 pt FP tolerance for points that land exactly on an edge).
- Decoupled map visibility from the Route Style preset. `OverlayRouteMapPreset` is now `minimal` / `gradient` / `glow` only — the legacy `mapKit` case is migrated to `gradient` on decode for backward compatibility. Map presence is the single responsibility of `routeMapBackgroundStyle`: `.none` hides the map, every other case renders it. `OverlayRenderModel.routeMapLayout` now derives `routeMapProvider` from the background style, so callers no longer need to keep them in sync. `setOverlayRouteMapPreset` no longer mutates `routeMapProvider`.
- Added a dedicated **Show Map** toggle as the section accessory on `Background Map`, backed by the new `setOverlayRouteMapShowMap`. Off → `routeMapBackgroundStyle = .none`; on → restore the previously selected style, defaulting to `.dark` when the previous value was already `.none`. The Map Style dropdown excludes `.none` (`OverlayRouteMapBackgroundStyle.visibleCases`) and disables itself when Show Map is off.
- Added independent container dimensions: `OverlayStyle.routeMapWidth` and `routeMapHeight` (default `320 × 240`, clamped `80...1200`). Square containers expose two sliders; circle containers collapse to a single Size slider that drives both axes (the renderer takes the shorter edge as the diameter). New setters `setOverlayRouteMapWidth` / `setOverlayRouteMapHeight` use continuous undo. Switching shape to `circle` collapses width and height to the shorter edge so editor handles stay synced with the rendered diameter.
- Removed the `Container Preset` dropdown from the Inspector's Preset section because it duplicated the per-field Container controls. `OverlayRouteMapContainerPreset` and `setOverlayRouteMapContainerPreset` are kept for one-click recipes used by templates and tests, but no longer render an Inspector row.
- Reworked `RouteMapMaskRenderer.drawFadeMask` so Edge Softness has the dramatic vignette effect from the design mockup. Both shapes now draw a single radial gradient (3-stop white → white → black at locations `[0, 0.45, 1]`) clipped to the container outline, with the outer radius set to the half-diagonal for square containers so the fade reaches every corner without a hard step. The maximum softness is raised from `0.45` to `0.85` (matching the slider's new range) and exposed as `RouteMapMaskRenderer.maxFadeAmount`.
- Updated `OverlayFrameRenderer` and `PreviewCanvasView` so the map snapshot, the synthetic grid fallback, and the container background colour all key off `routeMapBackgroundStyle != .none` instead of `layout.preset == .mapKit`.

Documentation:

- `docs/design/route-map-overlay-ui.md` — Phase E.1 update. Section list now reads "Route Style Preset + Distance" for `Preset`, "Shape / Width / Height (or Size for circle) / Edge Mode / Edge Softness / Border" for `Container`, and "Show Map (header toggle) + Map Style (excluding none) + Map Opacity" for `Background Map`. Container Preset is documented as a templates-only API. Edge Softness range is `0...0.85`. Acceptance criteria updated to match.
- `docs/design/route-map-overlay-ui.spec.json` — same updates in machine-readable form. The `Container` section now lists `width` / `height` / `size` controls (with `visibleWhen` rules), the `Background Map` section gets a `showMap` accessory definition, and `routeMapPreset` no longer lists `mapKit` as an option. `modelGapsPhaseE` is now empty; the new fields move into `modelBackedToday`.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/design/route-map-overlay-ui.md`
- `docs/design/route-map-overlay-ui.spec.json`
- `docs/project-log.md`

Verification: `swift build` succeeded with only the pre-existing Running Gauge actor-isolation warnings. `swift test` passed all 51 tests in 8 suites; the route map projection regression assertion was added to ensure the centering fix doesn't regress.

## 2026-04-26

### Route Map — Phase E Container Presets, Map Opacity Slider, Inspector Spec Alignment

Summary:

- Promoted Route Map to its own dense Inspector detail view (`RouteMapOverlayDetailView`) modelled on `NumericOverlayDetailView`, so the right panel reuses `InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseSegmented`, `InspectorDenseMenuLabel`, `InspectorDenseSwatchStrip`, `InspectorAnchorGrid`, and `NumericTokens` for byte-for-byte density parity with Numeric Overlay.
- Reorganised the panel into the eight sections required by the new spec: `Preset` (Container Preset + Route Style Preset + Distance readout), `Layout` (Anchor / X / Y / Scale / Rotation / Opacity), `Container` (Shape / Edge Mode / Edge Softness), `Background Map` (Map Style / Map Opacity), `Route Line`, `Markers`, `Legend` (with toggle accessory in the section header), and `Effects`.
- Introduced `OverlayRouteMapContainerPreset` (`squareHardEdge` / `circleHardEdge` / `squareGradientEdge` / `circleGradientEdge`). Selecting a preset writes a bundle of defaults (`routeMapShape`, `routeMapEdgeFade`, `routeMapFadeAmount`, `routeMapMapOpacity`, `shadowEnabled`, `shadowOpacity`, `shadowRadius`, `shadowOffsetX`, `shadowOffsetY`) onto the element through a single undo checkpoint. The four reference variants from the user's mockup can now be reproduced in one click.
- Added `OverlayStyle.routeMapMapOpacity` (default `0.72`, clamped `0...1`) and wired it through `OverlayRouteMapRenderLayout.mapOpacity`. Preview (`PreviewCanvasView.RouteMapOverlayView`) now applies `layout.mapOpacity` to the MapKit snapshot instead of a hard-coded `0.82`. Export (`OverlayFrameRenderer.drawMapGrid`) now scales the synthetic map grid alpha by `layout.mapOpacity` so still / video exports match the slider.
- Added `setOverlayRouteMapContainerPreset` and `setOverlayRouteMapMapOpacity` mutators to `ProjectDocument`, both registering an undo point so preset switches and slider drags are reversible. `setOverlayRouteMapEdgeSoftness` keeps its dual behaviour (writes both `routeMapFadeAmount` and `routeMapEdgeFade`).
- Persisted the new fields through `OverlayStyle.init(from:)` with `decodeIfPresent` defaults so legacy templates and projects load unchanged. `routeMapMapOpacity` is clamped on decode.
- Added a `RouteMapOverlayHeader` that mirrors the Numeric header (back / icon / title / `Overlay` pill / trash) plus a distance subtitle, replacing the older "1657 pts" header block with a clean `12.86 km` readout.

Documentation:

- New design spec `docs/design/route-map-overlay-ui.md` — header, eight sections, every control's model mapping, density tokens shared with Numeric Overlay, container preset value table, model gaps grouped into Phase E (this revision: container preset + map opacity) and Phase F (border / glow / map adjustments / route line richness / per-marker details / legend item list / typography / blend mode), and acceptance criteria.
- New machine-readable spec `docs/design/route-map-overlay-ui.spec.json` listing every section, control, model path, options, default values, and `containerPresetDefaults` table — same shape as `numeric-overlay-ui.spec.json`.
- Updated `docs/overlay-modules/route-map-overlay.md` with a pointer to the new design spec and added Phase E and Phase F to the implementation phase list, marking Phase D items completed where applicable.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `docs/design/route-map-overlay-ui.md` (new)
- `docs/design/route-map-overlay-ui.spec.json` (new)
- `docs/overlay-modules/route-map-overlay.md`

Verification: `swift build` succeeded (only pre-existing Running Gauge actor-isolation warnings remain). `swift test` passed all 51 tests in 8 suites.

### Running Gauge — Full Module Redesign (7 Layouts × 7 Style Presets, Per-Region Metric Binding)

Summary:

- Promoted the Running Gauge from a hardcoded `Distance / Time / Pace / HR` disc to a fully configurable circular dial module with per-region metric binding, seven data-layout presets, seven visual style presets, and an Inspector that exposes every dial / ring / tick / divider / typography / color / effect knob the renderer consumes. Implements `Running Gauge Overlay 设计与实现指引` end-to-end through MVP scope (sections 1–8, 9, 14, 15 of the guide).
- New data model file `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift` introduces:
  - `OverlayGaugeMetric` (distance / pace / elapsedTime / realTime / heartRate / power / cadence / elevation / calories) with bridging to the existing `OverlayElementType` so `OverlayValueFormatter.components(for:activity:elapsedTime:)` can resolve label/value/unit tuples without duplication.
  - `RunningGaugeRegion` (11 region slots: top, middle, bottom, middleLeft/Center/Right, topLeft/Right, bottomLeft/Center/Right) and `RunningGaugeLayoutPreset` with the seven layouts from the spec — `topBottom`, `topMiddleBottom`, `threeZones`, `topTwoMiddleBottom`, `topThreeMiddleBottom`, `fourZones`, `fiveZones` — each declaring its visible regions in render order.
  - `RunningGaugeRegionConfig` per-region struct: metric, custom label, show label/unit/icon flags, value/label/unit font scale, value/label weight, optional value/label colours.
  - `RunningGaugeProgressMode` (none / distanceTarget / elapsedTimeTarget / heartRateZone / powerZone / paceIntensity / customPercentage).
  - `RunningGaugeStyle`: the single source of truth for a gauge — style preset, layout preset, regions[], dial (color/opacity/glass), outer ring (toggle/color/opacity/width-scale), tick marks (toggle/color/opacities/count/major-every), progress ring (toggle/mode/color/track/opacity/width-scale/rounded-caps), dividers (toggle/color/opacity/width), typography (font/monospaced/primary+secondary weight), color (primary/secondary text/accent), effects (shadow toggle/opacity/radius, glow toggle/color/opacity/radius).
  - Built-in presets `minimalSport`, `highContrastSport`, `roadRun`, `trailAdventure`, `futureTech`, `retroDigital`, `premiumGlass` matching the guide's recommended visual parameters and recommended layout pairings.
  - `RunningGaugeStyle.defaultRegions(for:)` factory that emits the recommended metric assignments per layout (e.g. `topTwoMiddleBottom` → Distance / Pace / Time / HR).
  - `RunningGaugeLayoutEngine.regionFrames(for:in:)` returns per-region `CGRect`s in gauge-local coordinates for every layout, and `dividerSegments(for:)` returns normalised divider lines so the renderer and the SwiftUI preview can share one source of truth.
- Wired `RunningGaugeStyle` into `OverlayStyle.gauge` (with default + Codable migration that seeds the gauge sub-style from the legacy top-level `gaugePreset` for older project files). Extended `OverlayGaugePreset` with two new cases (`.roadRun`, `.premiumGlass`) and updated all preset display labels to match the design guide's bilingual format.
- Refactored `OverlayRunningGaugeRenderLayout` and `OverlayRenderModel.runningGaugeLayout(for:in:)` to compute, for each rendered region, a canvas-space `CGRect`, the formatted metric value components, and value/label/unit font sizes scaled from the gauge diameter using the spec's `gaugeSize × 0.145` baseline. Progress is now derived from `RunningGaugeProgressMode` (distance target → distance ratio, elapsed-time / zone-style modes → elapsed/duration ratio, custom → 0.5 placeholder).
- Replaced `renderRunningGauge` and its helpers in `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift` with a layered draw pass: dial fill → outer ring (configurable width/color/opacity) → tick marks (count, major-every, two opacities) → progress ring (track + arc with rounded caps) → divider lines (driven by `RunningGaugeLayoutEngine.dividerSegments` clamped to a `safeRadius = diameter * 0.40` inset) → per-region label / value / unit text (alignment, weight, monospaced digits via `featureSettings`). The legacy preset-specific helper switches (`gaugeMinimumBackgroundOpacity`, `gaugeValueColor`, `gaugeLabelColor`, `gaugeTickColor`) are gone — colours and opacities now flow directly from the user-editable `RunningGaugeStyle`.
- Rewrote the SwiftUI `RunningGaugeOverlayView` in `PreviewCanvasView.swift` with the same layered structure so the in-editor preview is byte-for-byte parity with the export renderer. Tick and divider shapes share the layout engine helpers; per-region text uses `Text` views positioned via `position(x:y:)` from the same region frames the renderer consumes. New `GaugeMonospacedDigit` and `GaugeGlow` view modifiers conditionally apply monospaced digits and glow shadows so non-tech presets aren't taxed.
- Rebuilt `RunningGaugeOverlayDetailView` to expose 11 dense Inspector sections that mirror the numeric overlay's design language — Style Preset, Position & Scale, Data Layout, Region Settings, Dial, Ring, Ticks, Dividers, Typography, Color, Effects. Region Settings lists every region in the active layout with an inline metric picker; clicking the slider chevron expands a per-region drawer with custom label, show-label/unit toggles, value-size/weight sliders, and value-color swatch. Conditional sub-rows (e.g. tick-color appears only when ticks are enabled, glow color only when glow is on) keep the panel readable across presets.
- Added two new `ProjectDocument` mutators: `mutateGaugeStyle(_:_:)` (generic in-place mutator with a single undo checkpoint) and `setOverlayGaugeLayout(_:layout:)` / `updateOverlayGaugeRegion(_:region:_:)` for the layout + region surface area. `setOverlayGaugePreset` now re-seeds the gauge sub-style from the chosen preset so picking a preset resets visual parameters but not the user's data layout / region bindings.
- Updated `Tests/RunningOverlayTests/OverlayRenderModelTests.swift` to assert against the new region-based layout output (verifying that the default `.roadRun` preset yields `topTwoMiddleBottom` with Distance / Pace / Time / HR bound to top / middleLeft / middleRight / bottom).

Files changed:

- `Sources/RunningOverlay/Overlay/RunningGaugeModel.swift` (new)
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/project-log.md`
- `docs/requirements.md`

Verification:

- `swift build` clean.
- `swift test` 51 tests in 8 suites pass, including the rewritten `runningGaugeLayoutCarriesCoreMetricsAndProgress` and `overlayFrameRendererWritesRunningGaugePNG` golden frame.

Notes / next milestones (deferred to a follow-up per spec section 15 "v1 may defer"):

- Glass blur and texture effects, full free-form custom region drag, multi-progress-ring stacks, and animated entry. The data model already carries `glassEffectEnabled`, glow, and a `RunningGaugeLayoutPreset.custom` placeholder so the renderer/inspector can be extended without further migrations.
- Per-region icons and custom progress max for zone modes — fields are reserved (`showIcon`, `progressMode`) but the renderer currently substitutes time-based progress for HR/Power/Pace zones until a project-level zone configuration lands.

### Running Gauge Inspector — Dense Layout Aligned With Numeric Overlay

Summary:

- Added `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift`, a Running Gauge–specific Inspector panel that mirrors the dense design language of `NumericOverlayDetailView`. It reuses the same `NumericTokens` (row height 32, control height 28, panel padding 12/8, control radius 5, monospaced numeric font) and the shared dense components (`InspectorDenseRow`, `InspectorDenseSliderRow`, `InspectorDenseAxisField`, `InspectorDenseSegmented`, `InspectorDenseSwatchStrip`, `InspectorAnchorGrid`, `InspectorDenseMenuLabel`) so the two inspectors are visually identical pixel-for-pixel in spacing, typography, borders, and section disclosure behavior.
- The gauge panel exposes only the parameters the gauge renderer actually consumes, organised into the same five-section pattern used by the numeric inspector:
  - **Style** — gauge preset menu (Minimal Sport / High Contrast / Trail Adventure / Tech Future / Retro Digital).
  - **Layout** — 9-cell anchor grid, X/Y position fields, Scale and Rotation sliders.
  - **Typography** — Font menu, Size slider (drives all internal value/label/unit sub-sizes), Weight segmented control.
  - **Color** — Accent swatch strip (drives the progress arc and value text via `foregroundColor`).
  - **Background** — Opacity slider for the circular gauge background disc.
- Header matches the numeric overlay layout: back chevron, type icon tile, title plus a "Gauge" caption pill, trailing destructive delete button, and a `Reset` / `Done` footer with the same `EditorSecondaryButtonStyle` / `EditorPrimaryButtonStyle` pairing.
- Updated `ParameterPanelView.body` so the overlay element router dispatches `.runningGauge` to the new dense view; numeric overlays still route to `NumericOverlayDetailView` and the remaining non-numeric types (currently only `.routeMap`) keep using the legacy `OverlayDetailView`.

Files changed:

- `Sources/RunningOverlay/UI/RunningGaugeOverlayDetailView.swift` (new)
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`. Build succeeded.

### Numeric Overlay Presets — Canonical 10 (Minimal Clean → Digital Watch)

Summary:

- Adopted the brief in `assets/image-413a701b-166c-42e5-947c-31b27a732e25.png` as the canonical numeric overlay preset system. The 10 presets exposed in the inspector are: Minimal Clean, Minimal Label, Pill, Metric Card, Big Number, Split Label, Neon Glow, Racing Stripe, Editorial, Digital Watch.
- Added five new `OverlayTextPreset` cases (`.minimalLabel`, `.neonGlow`, `.racingStripe`, `.editorial`, `.digitalWatch`) and renamed display labels for the existing five reused cases (`.minimal` → "Minimal Clean", `.pillBadge` → "Pill", etc.).
- Refreshed `OverlayPresetTokens` to also carry `backgroundColor`, `backgroundOpacity`, and `backgroundRadius`, so applying a preset can fully snap the background look (e.g. Pill → black 48% capsule, Digital Watch → black 60% rounded with phosphor-green accent border).
- Recommended tokens are now defined for all 10 canonical presets. `ProjectDocument.applyOverlayTextPreset` writes the tokens through to `OverlayStyle` and `addOverlayElement(_:)` seeds new numeric elements with the type's recommended preset (e.g. `.power` → Racing Stripe, `.elapsedTime` → Digital Watch, `.heartRate`/`.cadence` → Pill).
- Replaced the preset preview/export bodies for the canonical 10 in `PreviewCanvasView` (`minimalCleanView`, `minimalLabelView`, `pillView`, `splitLabelView`, `neonGlowView`, `racingStripeView`, `editorialView`, `digitalWatchView`) and `OverlayFrameRenderer` (`renderMinimalLabel`, `renderNeonGlow`, `renderRacingStripe`, `renderEditorial`, `renderDigitalWatch`). Added matching `presetTextRect` sizing for each new layout.
- The numeric inspector preset menu and the text-preset row in `ParameterPanelView` both now iterate `OverlayTextPreset.numericPresets` (the 10 canonical cases) so legacy / deprecated cases (`.sportWatch`, `.inlineGhost`, `.accentBar`, `.sportNeon`, `.serifEditorial`) remain decodable for old projects but never appear in the picker.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`. All 51 tests passed.

### Numeric Overlay Visual Presets — Inline Ghost / Accent Bar / Sport Neon / Serif Editorial

Summary:

- Added four new `OverlayTextPreset` cases for numeric overlays: `.inlineGhost`, `.accentBar`, `.sportNeon`, `.serifEditorial`. Each follows the design brief in `assets/image-621dbbba-3e2f-42df-87df-80810a9c2be0.png`.
- Implemented preview rendering for the new presets in `TextPresetOverlayView`, including 0.5 px rules, accent bars/dots, uppercase tracked labels, and Georgia serif numerals.
- Implemented matching export rendering in `OverlayFrameRenderer` (`renderInlineGhost` / `renderAccentBar` / `renderSportNeon` / `renderSerifEditorial`) plus per-preset bounding-box sizing in `presetTextRect`. `drawText` now accepts an optional foreground color so per-element opacity and accent tints work without overriding `OverlayStyle.foregroundColor`.
- Added `OverlayPresetTokens` and `OverlayTextPreset.recommendedTokens`. The new `ProjectDocument.applyOverlayTextPreset` setter snaps `fontName`, `fontSize`, `fontWeight`, `textAlignment`, `showLabel`, `showUnit`, `backgroundEnabled`, and `accentColor` to the brief's tokens (e.g. Sport Neon → 36 pt heavy, cyan accent #22d3ee, transparent background) when the user picks a preset.
- Added a `Style` row to the Content section of the numeric Inspector so users can pick any preset (existing or new) from the dense panel; selecting a preset routes through `applyOverlayTextPreset` so token snapping is undoable and Reset still works.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`. All 51 tests passed.

### Numeric Overlay Preview Wiring & Inspector Polish

Summary:

- Wired numeric overlay preview rendering to the new style fields so toggles in the Inspector now affect the live preview, not just export:
  - `.minimal` text preset honors `showLabel` (renders the label inline) and `showUnit` (hides the unit suffix when off).
  - Background drawing now uses `backgroundEnabled` + `backgroundColor`; turning the toggle off removes the bubble entirely (selection highlight still draws).
  - Shadow drawing now gates on `shadowEnabled` and uses `shadowOffsetX/Y`.
- Removed the read-only `Metric` row at the top of the Content section in the numeric Inspector; metric is already shown in the header.
- Removed the duplicate chevron in `InspectorDenseMenuLabel`; we now rely on the platform `Menu` indicator only.
- Renamed the `Effects` section to `Shadow` (Inspector + design doc) so the title matches the controls inside it.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift`
- `docs/design/numeric-overlay-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`. All 51 tests passed.

### Numeric Overlay UI Refactor

Summary:

- Refactored the numeric category Inspector to a dense, DaVinci-style two-column panel matching `docs/design/numeric-overlay-ui.md` and the `numeric-overlay.png` mockup.
- Added a new `NumericOverlayDetailView` with collapsible sections (Content, Layout, Typography, Color, Background, Effects), compact dense rows, and a sticky Reset/Done footer.
- Routed numeric overlay types (heart rate, pace, calories, elapsed time, real time, distance, elevation, cadence, power) through the new view via `ParameterPanelView`; non-numeric overlays continue to use the legacy `OverlayDetailView`.
- Extended `OverlayStyle` with the previously missing fields: `unitOption`, `showLabel`, `showUnit`, `customLabel`, `rotationDegrees`, `textAlignment`, `accentColor`, `backgroundEnabled`, `backgroundColor`, `backgroundRadius`, `backgroundPaddingX`, `backgroundPaddingY`, `shadowEnabled`, `shadowOffsetX`, `shadowOffsetY`. All new fields decode with defaults for legacy templates.
- Added `OverlayUnitOption` and `OverlayTextAlignment` enums plus `OverlayElementType.isNumericOverlay` / `defaultUnitOption` helpers.
- Updated `OverlayValueFormatter` to be element-aware so it honors the new unit option, label/unit visibility, and custom label fields.
- Updated `OverlayRenderModel` and `OverlayFrameRenderer` so the `.minimal` text preset uses the new background color/radius/padding/shadow fields when rendering.
- Added `ProjectDocument` setters for every new field plus a `resetOverlayStyle` action used by the Reset footer button.
- Added formatter tests covering pace metric/imperial/rowing units, distance miles/meters, elevation feet, duration seconds, and label/unit/custom-label flags.
- Updated `docs/design/numeric-overlay-ui.md` to mark the previously-missing model fields as implemented.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/NumericOverlayDetailView.swift` (new)
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Tests/RunningOverlayTests/OverlayValueFormatterTests.swift`
- `docs/design/numeric-overlay-ui.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 51 tests passed.

### Layer-Wide Clip Offset Action

Summary:

- Updated the clip-offset action in the Inspector from camera-wide apply to layer-wide apply.
- Changed clip Inspector button copy to `Apply to all clips in this layer`.
- Updated timeline offset application logic to target only the selected clip's timeline layer, not all clips sharing camera/source group.
- Added and updated tests to ensure only the current layer receives the offset update.
- Synced requirements, development notes, and roadmap wording with the new layer-wide behavior.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 49 tests passed.

### Numeric Overlay UI Design Spec

Summary:

- Added implementation-facing design documentation for a dense reusable Numeric Overlay Inspector detail template.
- Scoped the template to single-value numeric overlays including Pace, Heart Rate, Distance, Power, Cadence, Calories, Elevation, Elapsed Time, and Real Time.
- Captured the DaVinci-like compact panel direction with dense sections, two-column label/control rows, unit selection, background controls, typography, layout, color, and effects groups.
- Added Pace unit choices: `Metric (min/km)`, `Imperial (min/mi)`, and `Rowing (min/500m)`, plus suggested unit options for other numeric metrics.
- Documented current model-backed fields and model gaps so follow-up agents can separate visual implementation from schema work.
- Linked the Numeric Overlay template from the Inspector design docs and structured spec.

Files changed:

- `docs/design/README.md`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/design/numeric-overlay-ui.md`
- `docs/design/numeric-overlay-ui.spec.json`
- `docs/design/numeric-overlay.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/inspector-ui.spec.json docs/design/numeric-overlay-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Stable Pane Widths With Custom Horizontal Splitter

Summary:

- Replaced the upper editor `HSplitView` with a custom `HStack` plus `HorizontalResizeHandle` dividers because SwiftUI `HSplitView` reset child pane widths whenever Inspector internal selection changed (overlay detail, timeline clip selection) or Media Pool content changed (importing/matching media).
- Stored Media Pool and Inspector widths in `@State` (`mediaPoolWidth = 380`, `inspectorWidth = 400`) so user-dragged sizes persist across every internal state change.
- Added Min/Max clamping (Media Pool 300-720 px, Inspector 320-720 px) and `NSCursor.resizeLeftRight` hover feedback on the custom handles.
- Synced Inspector design and project documentation to require width stability across all internal state changes for both panes.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 49 tests passed.

### Resizable Media Pool And Inspector Defaults With Stable Inspector Width

Summary:

- Set Media Pool default width to `380 px` (min `300 px`) and Inspector default width to `400 px` (min `320 px`); both panels remain user-resizable via the split dividers.
- Removed the fixed-width frame from `ParameterPanelView` body so the HSplitView pane width is owned by the split view; internal Inspector selection changes (outer/clip/overlay) no longer resize the right pane.
- Synced Inspector design and project documentation to require draggable Inspector width that is preserved across internal state switches.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All tests passed.
- Ran `jq empty docs/design/inspector-ui.spec.json`.

### Inspector Fixed Width Across Editing States

Summary:

- Fixed the Inspector split-pane width at `380 px` so switching between outer/detail/editing states no longer changes panel width.
- Updated Inspector panel sizing in both the split-view host and `ParameterPanelView` to use a single fixed-width constraint.
- Synced Inspector design and implementation docs to explicitly require fixed-width behavior.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All tests passed.

### Header Height Unification For Media Preview Inspector

Summary:

- Unified top header height across Media, Preview, and Inspector panels.
- Updated Preview header to use the shared `EditorPanelHeader` and shared header button sizing.
- Updated Inspector header to also use `EditorPanelHeader`, with the status label rendered as caption metadata and the trailing icon button as a header action.
- Removed redundant inline `Divider()` after Inspector headers because `EditorPanelHeader` already draws its own bottom divider, eliminating extra vertical pixels that made Inspector taller than Preview.
- Synced requirements and development docs with the new header and button-size consistency rule.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Timeline Frame Step Shortcuts

Summary:

- Changed Left Arrow and Right Arrow to step the timeline playhead backward or forward by one project frame.
- Frame-step size is derived from the current project frame rate.
- Manual frame stepping stops playback and exits temporary media-pool source preview before moving the timeline playhead.
- Added a project-level test covering frame-rate-based stepping.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 49 tests passed.

### Timeline UI Polish: Playhead, Selection, Hover Pill, Header Picker

Summary:

- Removed the timeline header `Preview` `Auto` picker because per-track visibility in the eye-icon menu already covers the same workflow; the implicit auto preview track is preserved.
- Updated the AppKit playhead to a small downward-pointing triangle inside the ruler band connected to a thin red line that extends down through the tracks; the playhead no longer extends above the ruler and is no longer a square block.
- Updated selected timeline clips to draw a 2 px white border on top of the blue fill so the selected clip matches the design mockup.
- Updated the ruler hover info pill to draw a small downward-pointing arrow on its bottom edge whose tip aligns with the hovered ruler position.
- Synced the timeline design docs and project docs with the picker removal, playhead shape rules, selected-clip border rule, and hover-pill arrow rule.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/design/timeline-ui.md`
- `docs/design/timeline-ui.spec.json`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.
- Ran `jq empty docs/design/timeline-ui.spec.json`.

### Timeline UI Restyle Implementation

Summary:

- Reworked timeline visuals in `TimelineView` to match the latest `timeline-ui` design spec while preserving existing timeline behaviors.
- Added timeline-specific AppKit color tokens in `EditorTheme` for FIT bars, clip blocks, playhead, lane bands, label column, splice borders, and drop targets.
- Updated the timeline canvas styling for compact ruler ticks, alternating dark track bands, square-adjacent clip joins, subtle dashed drop targets, compact hover info pills, and a muted-red playhead with a small connected marker.
- Updated timeline header styling to include the explicit `Preview` label and clearer collapse-toggle active-state signaling.
- Synced implementation docs and requirements with the new timeline visual language and removed outdated references to a large playhead head.

Files changed:

- `Sources/RunningOverlay/UI/EditorTheme.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Timeline UI Design Spec

Summary:

- Added implementation-facing design documentation for the bottom Timeline UI.
- Captured current timeline functionality in design form, including Preview track selection, per-track preview visibility, collapse/expand gaps, nonlinear zoom, ruler hover data, FIT layer alignment, video tracks, media drop targets, selected clip styling, and collapsed gap behavior.
- Added the final Timeline mockup with a subtle connected playhead marker and no separate `Gaps hidden` status row.
- Added a machine-readable Timeline UI spec for future agents to refine `TimelineView` and `TimelineCanvasNSView` from structured component, token, and interaction data.
- Updated the app-level design system and design index to include Timeline UI references.

Files changed:

- `docs/design/README.md`
- `docs/design/app-ui.md`
- `docs/design/app-ui.spec.json`
- `docs/design/timeline-ui.md`
- `docs/design/timeline-ui.spec.json`
- `docs/design/timeline.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/app-ui.spec.json docs/design/timeline-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Preview Header And Playback Row Spacing

Summary:

- Removed the apparent top and bottom blank strips in the Preview panel by moving fixed row heights inside the header and playback-row components so their backgrounds fill the rows.
- Reduced the Preview header controls to leave visible vertical margin around the safe guides and Fit buttons.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Preview UI Implementation

Summary:

- Implemented the Preview UI design spec in `PreviewCanvasView`.
- Added an in-preview header with title, project resolution/frame-rate metadata, a safe guides toggle, and a compact Fit menu placeholder.
- Removed the safe guides toggle from the app-level toolbar so Export remains the only app-level action on the right side.
- Restyled the canvas workspace around the fitted project canvas and added a subtle Guides On HUD while safety guides are enabled.
- Added blue safe guide strokes and selected-overlay affordances with a border plus corner handles.
- Reworked the bottom playback row into a centered previous/stop/play-pause/next cluster with a right-pinned playback-rate menu.
- Added direct playback-rate selection for 1x, 2x, 4x, and 8x.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Preview UI Design Spec

Summary:

- Added implementation-facing design documentation for the central Preview UI.
- Captured the final Preview interaction direction: safe guides live in the Preview header, Fit remains in the Preview header, and Export stays in the app toolbar.
- Defined the simplified bottom playback row with centered previous/stop/play-pause/next controls, no timecode, no scrubber, and playback speed pinned to the bottom right.
- Added a machine-readable Preview UI spec for future agents to implement `PreviewCanvasView` and remove the safe guides toggle from `MainEditorView.toolbar`.
- Updated the app-level UI design docs to reference Preview-specific components and guidance.

Files changed:

- `docs/design/README.md`
- `docs/design/app-ui.md`
- `docs/design/app-ui.spec.json`
- `docs/design/preview-ui.md`
- `docs/design/preview-ui.spec.json`
- `docs/design/preview.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/app-ui.spec.json docs/design/preview-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Media Pool Header Menu Simplification

Summary:

- Removed the unused trailing Media Options dropdown from the Media Pool header.
- Changed the mark filter menu entries to use circular color icons.
- Removed the extra chevron-style visual from the mark filter button label.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Media Pool Icon Alignment And Mark Menu Polish

Summary:

- Centered the media row file icon inside its thumbnail well.
- Changed Mark submenu entries to use generated circular color icons so color marks are visible in the native context menu.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Media Pool UI Spec Implementation

Summary:

- Implemented the Media Pool design spec in `MediaBrowserView` with a header toolbar, search field, visible clip count, and real `All` / `Ready` / `Aligned` status filters.
- Added filename search and made tag/status/search filter changes prune hidden selections.
- Restyled media rows with compact file icon wells, hover fills, selected-row blue accent strips, status pills, source-preview play indicators, and Mark submenu color dots.
- Expanded the no-media and filtered-empty states with the import action, matching-workflow helper text, supported-format hint, and dashed drop-zone treatment.
- Preserved drag/drop import, Command-click multi-select, Command+A visible selection, double-click source preview, native context menu actions, and focus-loss preview clearing.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### App UI Visual System Implementation

Summary:

- Added shared SwiftUI/AppKit `EditorTheme` tokens matching `docs/design/app-ui.md` for app backgrounds, panel surfaces, controls, borders, text, accent colors, spacing, radii, and typography.
- Restyled the main toolbar, status bar, export progress popover, Media Pool, Preview playback controls, Timeline toolbar/canvas, Project Settings, and Export dialog toward the shared dark editor system.
- Migrated Inspector token definitions to use the shared app theme while preserving its feature-specific component structure.
- Increased Media Pool split-pane minimum width and kept Inspector width constraints stable for dense controls.
- Updated AppKit timeline drawing colors to use the same app-level palette instead of system window/control backgrounds.

Files changed:

- `Sources/RunningOverlay/UI/EditorTheme.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### App UI Design System And Media Empty State

Summary:

- Added an application-level UI design system for Running Overlay covering product character, shared tokens, typography, layout, component standards, interactions, empty states, and accessibility.
- Added a machine-readable app-level UI spec for future agents to consume shared design guidance consistently across Media Pool, Preview, Timeline, and Inspector work.
- Added the Media Pool empty-state design mockup with drag/drop import affordance, import action, and supported-format hint.
- Updated the Media Pool UI spec and structured spec to reference both populated and empty media states.
- Updated the design docs index so app-level and empty-state assets are discoverable.

Files changed:

- `docs/design/README.md`
- `docs/design/app-ui.md`
- `docs/design/app-ui.spec.json`
- `docs/design/media-pool-ui.md`
- `docs/design/media-pool-ui.spec.json`
- `docs/design/media-pool-empty.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/app-ui.spec.json docs/design/media-pool-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Media Pool UI Design Spec

Summary:

- Added implementation-facing design documentation for the refreshed Media Pool UI.
- Captured the media list layout, header toolbar, search/filter area, row states, context menu, and Mark submenu behavior.
- Aligned Media Pool colors, spacing, typography, row styling, and menu treatment with the Inspector design language.
- Added a machine-readable JSON spec so follow-up agents can implement or restyle `MediaBrowserView` from structured token, component, and interaction data.
- Documented which current Media Pool behaviors must be preserved, including drag/drop import, selection, source preview, context-menu matching, tag filtering, and focus-loss preview clearing.

Files changed:

- `docs/design/README.md`
- `docs/design/media-pool-ui.md`
- `docs/design/media-pool-ui.spec.json`
- `docs/design/media-pool.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/media-pool-ui.spec.json`.
- Documentation/design-only change; tests not run.

## 2026-04-25

### Inspector UI Refactor Implementation

Summary:

- Rebuilt the Inspector SwiftUI surface around the design spec in `docs/design/inspector-ui.md`.
- Added tokenized dark Inspector styling for headers, sections, rows, tiles, icon buttons, segmented controls, sliders, value fields, and swatches.
- Replaced the flat overlay library with an outer add/manage state using Metrics, Charts, and Route tabs plus live-value added-overlay rows.
- Replaced the selected overlay form with a detail state that includes a detail header, Content, Position & Size, Style, and a sticky Done footer.
- Kept controls model-backed and rendered unsupported visibility/lock actions as disabled placeholders while omitting animation, generic opacity, and metric reassignment persistence.
- Restyled clip timing Inspector controls to use the same dark panel language.
- Added a stable 360 px minimum / 380 px ideal Inspector width so hierarchy changes do not collapse the right split pane.
- Expanded add-overlay tab hit targets so clicking anywhere inside a tab segment switches tabs.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Inspector UI Design Spec

Summary:

- Added implementation-facing design documentation for the refreshed Inspector UI.
- Captured the two primary Inspector overlay states: outer add/manage state and selected Overlay Detail state.
- Defined app-level dark editor UI guidance, design tokens, spacing, typography, component structure, and interaction rules.
- Added a machine-readable JSON spec so follow-up agents can implement SwiftUI components from structured state, token, and model mapping data.
- Documented current model gaps for visibility, lock, generic opacity, animation, and metric reassignment controls.

Files changed:

- `docs/design/README.md`
- `docs/design/inspector-ui.md`
- `docs/design/inspector-ui.spec.json`
- `docs/design/inspector-outer.png`
- `docs/design/overlay-detail-running-gauge.png`
- `docs/project-log.md`

Verification:

- Ran `jq empty docs/design/inspector-ui.spec.json`.
- Documentation/design-only change; tests not run.

### Route Map Overlay First Pass

Summary:

- Added GPS coordinate parsing for FIT record `position_lat` and `position_long`.
- Added route points, route bounds, and current-position interpolation to the activity timeline.
- Added the Route Map overlay type with Minimal, Gradient, Glow, and MapKit presets.
- Added preview/export route rendering with start, finish, and current-position markers.
- Added a MapKit snapshot provider abstraction and preview-time `MKMapSnapshotter` loading for the MapKit preset, with local fallback rendering.
- Added route map render model and PNG export tests.

Files changed:

- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Overlay/RouteMapOverlay.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/overlay-modules/route-map-overlay.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 48 tests passed.

### Route Map Overlay Design

Summary:

- Added a dedicated featured overlay module documentation area under `docs/overlay-modules/`.
- Drafted the Route Map Overlay design covering user-facing styles, Inspector controls, FIT GPS data needs, map API options, rendering architecture, caching, privacy, template behavior, and phased implementation.
- Linked the module from README, requirements, and roadmap.

Files changed:

- `README.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/overlay-modules/README.md`
- `docs/overlay-modules/route-map-overlay.md`

Verification:

- Documentation-only change; tests not run.

### Source Preview Playback Controls

Summary:

- Made media-pool double-click source preview start playback immediately instead of showing a paused first frame.
- Kept temporary source preview playback independent from the timeline playhead, including pause/resume from the current source time.
- Added a Preview-area playback strip below the video canvas with previous, stop, play/pause, and next controls.
- Added global K play/pause and L forward-speed behavior, stepping playback from 1x to 2x, 4x, and 8x.
- Moved the toolbar playback button into the Preview area.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 42 tests passed.

### Media Browser Keyboard Focus Cleanup

Summary:

- Restored Command+A selection for the custom media browser by adding an invisible AppKit key-capture view.
- Removed the visible blue system focus ring that appeared around the media browser while it was active.
- Kept first-responder loss tied to clearing transient media-pool preview.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Media Pool Alternating Row Styling

Summary:

- Replaced the system media `List` with a custom scroll view so media rows no longer use horizontal divider lines.
- Added DaVinci-style dark alternating row backgrounds across the media pool, including the empty scroll area behind rows.
- Preserved media selection, Command-click multi-select, select-all-visible, drag-to-timeline, context menu actions, and double-click source preview.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Timeline Empty State And Collapse Icon

Summary:

- Replaced the text `收缩` / `展开` timeline control with an icon-only collapse/expand button and tooltip.
- Changed the completely empty timeline to render as an empty work area without playhead, FIT layer, or fake track.
- Kept the default empty drop lane available once FIT or media context exists, while omitting the FIT layer when no FIT activity is loaded.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Collapse Mode Splice Styling And Drag Lock

Summary:

- Changed collapsed timeline clip rendering to use square internal edges and dark block borders, closer to DaVinci-style clip joins without full-height separator lines.
- Added dark borders to collapsed FIT segments as well, so FIT and video blocks share the same visual boundary language.
- Disabled horizontal dragging for existing video clips while the timeline is collapsed; clicking still selects clips.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Timeline Pinch Zoom And Accurate Clip Widths

Summary:

- Added macOS trackpad pinch zoom support on the AppKit timeline canvas.
- Removed the fixed minimum video clip block width so clip blocks reflect actual media duration at the current zoom level, including fit view.
- Hid clip titles when the block is too narrow to contain text.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Media Pool Source Preview

Summary:

- Added transient media-pool source preview: double-clicking a media row switches the preview to that video from the beginning without placing it on the timeline.
- Media-pool preview is cleared when the media browser loses focus or the user interacts with the preview/timeline, returning the preview to timeline playhead mode.
- Kept media-pool preview from driving timeline playback state or advancing the project playhead.
- Added a project-level test for media-pool preview selection and clearing when the media item is deleted.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 41 tests passed.

### Timeline Collapse Mode

Summary:

- Added a `收缩` / `展开` toggle next to the timeline zoom slider.
- Collapsed mode hides no-video gaps: a single layer displays clips back-to-back, while multiple layers display the union of video spans and hide FIT-only gaps.
- Playback in collapsed mode skips hidden empty regions and continues from the next visible video span.
- Timeline clip titles are clipped and middle-truncated inside their blue clip blocks.
- Added tests for collapsed single-layer mapping, multi-layer video-span union mapping, and playback gap skipping.

Files changed:

- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 40 tests passed.

### Timeline Clip Alignment Semantics (2026-05-10)

Summary:

- Timestamp-matched clips now treat their automatic matched start as read-only in the Inspector and expose offset as the adjustment value.
- Timeline dragging of timestamp-matched clips changes offset while preserving the automatic matched start.
- Timeline dragging of manually placed clips changes aligned time while preserving offset.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 93 tests passed.

### Export Text Supersampling

Summary:

- Added 2x offscreen supersampling for exported overlay text before compositing it into PNG and MOV frames.
- Applied the same path to plain text overlays and chart/timeline labels so large colored timer text has smoother alpha edges.
- Kept layout sizing, positions, shared render model values, and preview behavior unchanged.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 37 tests passed.

### Default Dark Editing Workspace

Summary:

- Set the macOS app default appearance to AppKit `darkAqua`.
- Set the SwiftUI root view preferred color scheme to dark.
- This makes system controls, lists, sheets, inspector, media browser, and timeline default to a dark editing workspace instead of a white/light theme.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 37 tests passed.

### Export Destination Defaults To First Video Folder

Summary:

- Changed the export dialog default destination from a fixed `~/Movies` path to the folder containing the first video in the media pool.
- Kept `~/Movies` as the fallback when no video files are loaded.
- Added tests for both default export destination cases.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 37 tests passed.

### Timeline Full-Height Playhead

Summary:

- Replaced per-track playhead markers with a single DaVinci-style full-height playhead overlay.
- Added a larger red ruler head and a vertical red line spanning the visible timeline canvas.
- Updated timeline documentation to describe the full-height playhead behavior.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/adr/0004-appkit-timeline.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 35 tests passed.

### Inspector Clip Timing Inputs

Summary:

- Replaced selected-clip Start and Offset sliders with second-based numeric inputs in the Inspector.
- Quantized Inspector start and offset edits to 0.01 seconds and displayed fields with two decimal places.
- Added double-click reset behavior on the Start and Offset labels, restoring each value to `0.00 s`.
- Removed the selected-clip Duration control from the Inspector until clip length adjustment is needed.
- Updated documentation for the current Inspector timing behavior.

Files changed:

- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 33 tests passed.

### Timeline Zoom Centers Playhead

Summary:

- Added zoom-change tracking to the SwiftUI/AppKit timeline bridge.
- Timeline zoom changes now recenter the scroll view on the current playhead.
- Playback still uses the existing keep-playhead-visible behavior.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 35 tests passed.

### Media Pool Explicit Matching And Tags

Summary:

- Changed video import so files enter the media pool without being automatically placed on timeline layers.
- Added `readyToMatch` media status for items with usable timestamps, reserving `aligned` for media that has actually been matched or manually placed.
- Added media-pool multi-selection, select-all-visible, right-click matching to the current layer or a new layer, right-click deletion, and right-click color tag assignment.
- Added media tag filtering in the media browser header while keeping tag assignment inside the context menu.
- Deleting media-pool items also removes timeline clips that reference those media IDs.
- Added tests for explicit matching, media tags, deletion, and undo restoration.

Files changed:

- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/MediaImport/MediaMetadataReader.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/architecture.md`
- `docs/development.md`
- `docs/requirements.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 35 tests passed.

### Preview Canvas Overlay Position Stability

Summary:

- Changed `PreviewCanvasView` to compute the actual fitted project canvas inside the preview panel from the selected project resolution aspect ratio.
- Moved video preview, safety guides, and editable overlays into that fitted canvas instead of using the outer preview container as the coordinate space.
- Updated overlay drag delta conversion and SwiftUI preview render context to use fitted canvas dimensions, keeping normalized overlay positions stable when preview split panes are resized.
- Preview text, padding, shadows, distance timeline, and elevation chart dimensions now scale with the fitted preview canvas size.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 35 tests passed.

### Project Timeline And Movable FIT Axis

Summary:

- Refactored timeline placement to use project time instead of clamping all clips to FIT elapsed time.
- Added `TimelineModel.fitStartTime` so the FIT activity is a movable axis inside the project timeline.
- Preserved imported video timestamps before activity start and after activity finish, allowing race start/finish buffer footage.
- Added a dedicated `FIT` layer above video layers in the AppKit timeline.
- Updated overlay sampling and export sampling to map project time back to FIT elapsed time through the FIT axis.
- Added tests for pre-start clips, movable FIT axis mapping, layer data sampling with FIT offset, the provided FIT file path, and GoPro-style filename timestamps.

Files changed:

- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `Tests/RunningOverlayTests/FitFileParserTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 33 tests passed.

### Shared Frame Renderer And Calibration PNG

Summary:

- Extracted overlay frame drawing from `OverlayVideoExporter` into `OverlayFrameRenderer`.
- Kept `OverlayVideoExporter` focused on MOV encoding, frame timing, pixel buffer allocation, and progress.
- Added `Export Test Frame` to render a calibration PNG through the same frame renderer used by calibration MOV export.
- Added a PNG render test that verifies the renderer writes a valid PNG file.

Files changed:

- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 29 tests passed.

## 2026-04-24

### Export Pixel Buffer Orientation Fix

Summary:

- Added a final vertical row flip after drawing each overlay frame into the export pixel buffer.
- This compensates for the current `CVPixelBuffer` to MOV orientation path, where a correctly drawn top-left overlay was encoded upside down in QuickTime.
- Normal exports and calibration exports use the same correction.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 28 tests passed.

### Preview Safety Guides And Calibration Export

Summary:

- Added a toolbar safety-frame toggle for preview alignment checks.
- Added 90%/80% preview safety frames and center crosshairs.
- Added a calibration test export from the export dialog that renders a short transparent MOV with fixed reference overlays and safety guides.
- Added optional guide rendering to the export renderer without affecting normal exports.
- Added synthetic calibration activity data so the test clip can be exported even before a FIT file is loaded.
- Added tests for calibration overlay layout and calibration activity data.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 28 tests passed.

### Shared Overlay Render Layout And Chart Export

Summary:

- Added a shared `OverlayRenderModel` for preview/export overlay value, geometry, font, padding, progress, and chart sample layout.
- Updated the SwiftUI preview to consume the shared overlay render layout for text, distance timeline, and elevation chart elements.
- Updated the export renderer to consume the same layout model and render distance timeline plus elevation chart elements instead of treating the chart as plain text.
- Moved export shape drawing to AppKit paths inside a flipped graphics context so text, backgrounds, progress bars, and chart paths use the same top-left coordinate system.
- Added render model tests covering text scaling, distance timeline progress/geometry, and elevation chart sample/progress layout.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/architecture.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- Ran `swift build`.
- All 26 tests passed.

### Export Coordinate And Progress Popover Fixes

Summary:

- Removed the export renderer's global CGContext inversion and switched text drawing to a flipped `NSGraphicsContext`, fixing upside-down exported overlay text.
- Added a small export render scale calibration so exported text and controls better match the preview scale.
- Changed the export progress popover from hover-open to click-open so the cancel button remains reachable.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 23 tests passed.

### Export Renderer Text, Scale, Cache, And Codec Fixes

Summary:

- Fixed export text drawing by creating an explicit `NSGraphicsContext` for the bitmap `CGContext`.
- Scaled export text, padding, rounded corners, shadows, and distance timeline geometry from a 1280x720 reference to the selected output resolution.
- Switched frame allocation to `AVAssetWriterInputPixelBufferAdaptor`'s pixel buffer pool.
- Added attributed text layout caching to reduce repeated per-frame font/string work.
- Added a ProRes 4444 codec option alongside H.265 with alpha.
- Removed bitrate compression properties from ProRes 4444 output settings.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 23 tests passed.

### App Focus And Timeline Zoom Slider Granularity

Summary:

- Set the app activation policy to regular on launch so the SwiftPM-started macOS app can become the active keyboard target.
- Timeline mouse-down now activates the app, makes the window key, and makes the AppKit timeline canvas first responder.
- Changed the timeline zoom slider from direct pixels-per-second mapping to a nonlinear 0-100 scale with finer low-end control.
- Reduced Command zoom's first step from fit view to a much smaller pixels-per-second value.
- Added a regression test for low-end zoom slider mapping.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 23 tests passed.

### Timeline Drop Target Highlight And Export Cancellation

Summary:

- Added AppKit timeline key handling so Delete and Forward Delete remove selected clips even when the timeline canvas has focus.
- Added layer highlighting while dragging media onto the timeline.
- Added exactly one new layer drop target beyond existing layers during media drag.
- Added export cancellation from the toolbar progress popover.
- Added cancellation checks inside the export renderer and progress state coverage.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ExportProgressTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 22 tests passed.

### Timeline Layer Label And Export Progress UI

Summary:

- Changed the default empty timeline lane name from `Video` to `Layer 1`.
- Added clearer AppKit timeline separation between the left label column and central lane area.
- Added structured export progress state with overall and per-output item progress.
- Added a toolbar export progress control that shows a hover popover with detailed export progress rows.
- Added export progress tests.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ExportProgressTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 21 tests passed.

### Timeline Delete And Finder Media Drop

Summary:

- Added Delete and Forward Delete handling for selected timeline clips and selected overlay elements.
- Added timeline clip deletion to the timeline model and routed selected deletion through `ProjectDocument` so it is undoable.
- Added Finder file drop support to the media browser for appending supported video files.
- Shared video URL import logic between toolbar import and media browser drop import.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 19 tests passed.

### Slider Tick Mark Cleanup

Summary:

- Removed SwiftUI Slider `step` parameters from timeline zoom, bitrate, clip, and overlay controls to hide macOS tick marks.
- Preserved existing value increments by quantizing values in bindings instead of relying on stepped Slider rendering.

Files changed:

- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 17 tests passed.

### Sequential Feature Pass: Templates, Preview Tracks, Overlay Editing, Export, Timeline Basics

Summary:

- Added standalone `.rotemplate` import/export for overlay templates.
- Moved overlay template management into Project Settings because it is a low-frequency workflow.
- Added preview track selection and per-track preview disable toggles so lower/other tracks can be inspected without affecting export.
- Added overlay X/Y numeric position entry, shadow controls, and arrow-key nudging.
- Added first-pass transparent MOV overlay export using H.265 with alpha.
- Added full FIT activity overlay export that ignores timeline video clips and renders from activity start to finish.
- Added selected clip Inspector controls for camera/track rename, start time, and duration.
- Updated timeline visible-clip selection to use right-open clip ends and support disabled preview tracks.

Files changed:

- `Sources/RunningOverlay/Export/OverlayVideoExporter.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 17 tests passed.

### Overlay Template Local Library

Summary:

- Added a versioned Codable overlay template schema.
- Added local JSON persistence for overlay templates under Application Support.
- Added ProjectDocument actions to save, apply, and delete templates.
- Applying a template replaces the current overlay layout and is undoable.
- Added an Overlay Templates section to the Project Settings sheet.
- Added template persistence and undo tests.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayTemplate.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Tests/RunningOverlayTests/OverlayTemplateTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 15 tests passed.

### AVPlayer-Driven Playback Sync

Summary:

- Changed video playback synchronization so `AVPlayer` drives project playhead while the playhead is inside a video clip.
- Added a periodic player time observer that reports activity time back to `ProjectDocument`.
- Kept timer-based playback advancement only for timeline gaps with no visible preview clip.
- Added drift correction for large manual seeks during playback without reintroducing per-frame seeking.
- Added tests for playback time updates and activity-end clamping.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 13 tests passed.

### Layer Data FPS Project Setting

Summary:

- Added a project-level Layer Data FPS setting with 1, 2, 5, 10, 15, and 30 fps presets.
- Quantized FIT-derived overlay sample time through `ProjectDocument` so preview and Inspector values update at the configured cadence.
- Added the setting to the project settings sheet and export dialog.
- Documented that future export rendering must use the same data sampling cadence as preview.

Files changed:

- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Tests/RunningOverlayTests/ProjectSettingsTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 11 tests passed.

### Video Seek And FIT Sampling Fixes

Summary:

- Fixed FIT record elapsed times by normalizing records after parsing with the final activity start date.
- This allows heart rate and other overlay values to sample changing records as playhead moves.
- Reduced video preview jumping by avoiding repeated `AVPlayer` seeks during normal playback.
- Added FIT parser regression assertions that the provided sample has nonzero elapsed record time and varying heart rate values.

Files changed:

- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Tests/RunningOverlayTests/FitFileParserTests.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 9 tests passed.

### Split Divider Cursor Hit Area

Summary:

- Expanded resize cursor hit areas around the main split dividers.
- Added cursor coverage on both sides of the horizontal divider between the upper editor area and timeline.

Files changed:

- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `docs/project-log.md`

Verification:

- Ran `swift build`.

### Playback And Timeline Interaction Fixes

Summary:

- Made playhead and zoom updates assign updated `TimelineModel` values so SwiftUI/AppKit refreshes are reliable.
- Added a Playback command with Space shortcut so play/pause works even when focus is outside the main editor key handler.
- Changed video preview playback so `AVPlayer` is not repeatedly seeked on every playhead tick, reducing playback stutter.
- Added a timeline zoom slider above the AppKit timeline canvas.
- Kept Command + Plus, Command + Minus, and Command-scroll timeline zoom support.
- Added resize cursor hints to major split-view boundaries without intercepting drag events.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/SplitCursorRegion.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 9 tests passed.

### Overlay Template Requirements

Summary:

- Defined overlay templates as a separate feature from full project files.
- Clarified that templates save reusable overlay layout and style only.
- Excluded FIT data, video paths, timeline clips, playhead, and sampled values from template contents.
- Added initial template UI requirements and implementation phases.

Files changed:

- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0005-overlay-templates-before-project-files.md`

Verification:

- Documentation-only change.

### Inspector Overlay List And Undo Redo Foundation

Summary:

- Added an Inspector list of already-added overlay elements when no element is selected.
- Clicking an overlay in the list selects the same element as preview selection.
- Added delete controls for overlay elements in the Inspector list.
- Added a project-level snapshot undo/redo stack to `ProjectDocument`.
- Wired `Command-Z` and `Shift-Command-Z` to project undo and redo.
- Routed core timeline and overlay mutations through undo registration.
- Optimized AppKit timeline clip dragging so movement is previewed locally and committed once on mouse-up.
- Added undo/redo tests for overlay add and delete.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/ProjectDocumentUndoTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 9 tests passed.

### FIT Timeline Refresh And Playback Follow

Summary:

- Fixed AppKit timeline refresh after FIT import by passing activity, timeline, media presence, and selection as explicit values through `NSViewRepresentable`.
- FIT-only projects now show the full activity ruler and an empty video lane before video import.
- Replaced direct timeline zoom mutation from commands and AppKit scroll handling with `ProjectDocument` methods.
- Added horizontal playback follow so the timeline scrolls to keep the playhead visible during playback.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 7 tests passed.

### Real Video Preview And AppKit Timeline

Summary:

- Added AVPlayerLayer-backed source video preview behind the overlay canvas.
- Preview now displays the first timeline clip containing the current playhead.
- Added timeline model lookup for the visible clip at a playhead time.
- Replaced the SwiftUI-rendered timeline with an AppKit self-drawing timeline embedded through `NSViewRepresentable`.
- AppKit timeline now draws ruler, hover data, tracks, clips, playhead, and handles clip selection, clip dragging, ruler seeking, media drops, and Command-scroll zoom.
- Added a timeline model test for visible clip lookup.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/VideoPreviewPlayerView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0004-appkit-timeline.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 7 tests passed.

### Empty Project State And Panel Background Fix

Summary:

- Removed startup sample media, sample timeline clips, sample overlay elements, and fake activity duration.
- Removed mock data helper entry points so startup state cannot accidentally repopulate sample content.
- Timeline now hides fake tracks when no media has been imported.
- Timeline ruler hides labels and hover data until a real FIT activity is loaded.
- Media and Inspector panels now use normal window backgrounds instead of the gray under-page background.
- Removed remaining visible export placeholder wording.

Files changed:

- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- Confirmed there are no remaining source/test references to startup placeholder/mock data.

### Overlay Visual Styling And Chart Rendering

Summary:

- Expanded overlay styles with font family, font weight, foreground color, and background opacity.
- Added Inspector controls for font family, font weight, color presets, and background opacity.
- Rendered distance timeline overlays as progress bars.
- Rendered live elevation chart overlays as compact line charts with playhead markers.
- Kept overlay style values in serializable model-friendly RGBA/value types.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 6 tests passed.

### First-Pass Overlay Editing And Live Data Binding

Summary:

- Added activity data interpolation for overlay values.
- Added `OverlayValueFormatter` for heart rate, pace, calories, elapsed time, real time, distance, elevation, cadence, and power.
- Connected preview overlay text to current playhead data instead of static placeholders.
- Added drag positioning for overlay elements in the preview.
- Added selected overlay scale and font size controls in the Inspector.
- Added playback-driven playhead advancement.
- Added timeline ruler seeking and a red playhead indicator.
- Added overlay value formatter tests.

Files changed:

- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayValueFormatter.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/OverlayValueFormatterTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 6 tests passed.

### Direct Timeline Clip Movement

Summary:

- Added horizontal drag movement for existing timeline clips.
- Dragging a clip updates its effective timeline start while preserving its alignment offset.
- Added a timeline model test for direct clip movement.
- Marked first-pass timeline editing complete in the roadmap.

Files changed:

- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Ran `swift test`.
- All 4 tests passed.

### Manual Timeline Placement And Clip Offset Editing

Summary:

- Added drag support from the media browser to timeline tracks.
- Added a default empty timeline track when no imported videos auto-align.
- Dropping media on a timeline track now creates or moves a timeline clip at the drop time.
- Added selected clip offset editing in the Inspector.
- Added the apply-to-camera action for copying the selected offset to clips from the same camera/source group.
- Added timeline model tests for manual placement and camera-wide offset application.

Files changed:

- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Tests/RunningOverlayTests/TimelineModelTests.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- All 3 tests passed.

### FIT Import Diagnostics And Developer Field Handling

Summary:

- Fixed FIT parsing for files that include developer field definitions by reading and skipping developer data fields.
- Added FIT import success and failure logs to stdout for `swift run RunningOverlay`.
- Added a parser regression test using the provided FIT sample path when available.

Files changed:

- `Package.swift`
- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Tests/RunningOverlayTests/FitFileParserTests.swift`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift test`.
- The provided FIT sample parsed successfully in the regression test.

### Video Import And First-Pass Alignment

Summary:

- Added native multi-select video import.
- Added AVFoundation metadata reading for video duration and creation date.
- Added filename timestamp parsing for common camera/phone naming patterns.
- Replaced placeholder video import from toolbar and command menu with real import.
- Rebuilt timeline tracks from auto-aligned imported videos.
- Updated media browser to show inferred timestamps.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/MediaImport/MediaMetadataReader.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Layout Adjustment And FIT Import Start

Summary:

- Adjusted the main editor layout so the timeline spans the full window width.
- Made media browser, preview, inspector, and timeline regions resizable through split-view boundaries.
- Added a native FIT file picker.
- Added a first-pass FIT parser for standard record/session messages.
- Added timeline ruler hover values for elapsed time, real-world time, and distance.

Files changed:

- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/FitData/FitFileParser.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `docs/requirements.md`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0003-focused-fit-parser.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Native App Skeleton

Summary:

- Created a Swift Package based native macOS SwiftUI app target named `RunningOverlay`.
- Added the first editor layout with media browser, preview, inspector, timeline, status bar, project settings sheet, and export sheet.
- Added placeholder project, activity, media, timeline, and overlay models so later feature work has stable module boundaries.
- Wired basic commands for FIT import placeholder, video import placeholder, playback toggle, and timeline zoom.

Files changed:

- `Package.swift`
- `Sources/RunningOverlay/App/RunningOverlayApp.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/Project/ProjectSettings.swift`
- `Sources/RunningOverlay/FitData/ActivityTimeline.swift`
- `Sources/RunningOverlay/MediaImport/MediaItem.swift`
- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/UI/MainEditorView.swift`
- `Sources/RunningOverlay/UI/MediaBrowserView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`
- `Sources/RunningOverlay/UI/ParameterPanelView.swift`
- `Sources/RunningOverlay/UI/ProjectSettingsView.swift`
- `Sources/RunningOverlay/UI/ExportDialogView.swift`
- `docs/development.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0002-swift-package-bootstrap.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Distance Timeline Refinement

Summary:

- Split Distance Timeline controls into Value, Label, Axis Labels, and Stats Bar sections.
- Added metric/imperial Value units, Value disable mode, four custom Value slots, axis label/distance-point controls, and a Route Map-style Stats Bar.
- Removed the standalone Distance Timeline Typography section; Value now owns the value font, size, weight, and color controls.
- Added a Custom Values master toggle; when enabled, Custom 1-4 metric-picker rows appear and render inline after the main Value with adjustable group gap, item gap, size, color, and opacity.
- Fixed Custom Values inline layout so increasing Group Gap moves the whole custom group without truncating custom values or reducing Item Gap.
- Updated Axis Labels so start/end endpoint text uses Point Gap like intermediate distance points.
- Kept Point Gap editable when More Points is disabled because endpoint labels also depend on it.
- Added Stats Bar width, item gap, and X/Y offset controls, and adjusted inside/attached placement so the bar sits at component edges without covering the progress axis.
- Split Distance Timeline Stats Bar placement into top/bottom/left/right plus a separate Inside toggle, including inside-left and inside-right rendering.
- Expanded Distance Timeline background/border bounds to cover Axis Labels and inside Stats Bar placements at their current size and offset.
- Added Tick Density control and updated tick rendering to use the configured density.
- Fixed left/right Stats Bar background sizing so vertical slots and labels are fully covered.
- Updated Distance Timeline preview selection bounds to cover the dynamic visual bounds, including Axis Labels and Stats Bar.
- Removed inline Percent handling from the Distance Timeline content flow; progress percentage now lives in Stats Bar slots.
- Changed Dense and Splits progress from segmented/dashed fills to solid progress fills.
- Disabled the fake Glass background until a real blur/material effect is available.

Files changed:

- `Sources/RunningOverlay/Overlay/OverlayElement.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/DistanceTimelineOverlayDetailView.swift`
- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/UI/RouteMapOverlayDetailView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.md`
- `docs/design/overlays/distance-timeline/distance-timeline-overlay-ui.spec.json`
- `docs/overlay-modules/distance-timeline-overlay.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Ran `swift build`.
- Build completed successfully.

### Documentation Bootstrap

Summary:

- Created initial documentation structure for the Running Overlay macOS app.
- Captured the first-pass product requirements from the initial brief.
- Added engineering guidance, proposed module boundaries, architecture notes, roadmap, and decision records.

Files changed:

- `README.md`
- `docs/requirements.md`
- `docs/development.md`
- `docs/architecture.md`
- `docs/roadmap.md`
- `docs/project-log.md`
- `docs/adr/0001-documentation-first-development.md`

Verification:

- Confirmed the project directory was empty before creating documentation.
- No code or build verification yet because no app project exists.

### Decor Category — Phases C through G (2026-04-30)

Plan reference: `~/.claude/plans/overlay-pool-solid-color-layout-bg-effe-shiny-pudding.md`.

**Phase C — Icon subsystem**

- `IconAsset` enum (sfSymbol / userStaticSVG / userLottie / bundledSVG) with hand-rolled Codable.
- `IconRendering` dual-path API: `IconView` (SwiftUI) and `IconRenderer.draw` (Core Graphics).
- SF Symbol and bundled SVG rendering with tint, preserveSVGColors, content mode.
- SVG smoke test gate passed (three fixtures rasterize via NSImage + CGContext).
- Lottie dependency (`lottie-ios` 4.5.0) added; LottieView path works; offscreen CG path is a documented limitation.

**Phase D — Decor Icon UI**

- `DecorIconRenderLayout` / `decorIconLayout` on OverlayRenderModel.
- `DecorIconOverlayView` / `OverlaySharedDecorIconView` in DecorOverlayViews.swift.
- Preview canvas and SwiftUI export switch arms wired.
- Full icon inspector: source picker (SF Symbol / Bundled SVG / Upload), symbol search + common grid, weight/scale pickers, tint swatch, content mode, preserveSVGColors toggle, Layout / Background / Effects sections.

**Phase E — User asset store**

- `UserAsset` model + `UserAssetStore` (content-addressed .assets/ folder).
- `ProjectDocument.userAssets` with undo support.
- `IconAssetResolver` wired to resolve user assets from the project.
- Import action via NSOpenPanel for SVG files.
- `OverlayTemplate` schemaVersion bumped to 2; optional `assets` field with custom Codable for backward compat.

**Phase F — Decor Text**

- `DecorFontRef`, `DecorTextFill`, `GradientSpec`, `DecorTextAlignment` types.
- `DecorTextResolved` coalescing nil optionals.
- `DecorTextRenderLayout` / `decorTextLayout` on OverlayRenderModel.
- `DecorTextOverlayView` / `OverlaySharedDecorTextView` with stroke, shadow, glow.
- Full text inspector: content editor, font picker (system/bundled), alignment, line height, letter spacing, auto-fit, fill color, stroke width/color, Layout / Background / Effects.
- Default presets seeded for all three decor types.

**Phase G — Polish**

- All three decor element types render end-to-end: Pool → Canvas → Inspector → Export.
- Default styles on add: Solid Color (240×80 white rounded rect), Icon (SF star.fill, 80×80, white tint), Text ("Hello", SF Pro, 320×60, centered).

Verification:
- `swift build` clean.
- `swift test` — all 75 tests pass.

### Numeric Preset Label/Accent Decoupling (2026-04-30)

Summary:

- Updated `splitLabel`, `racingStripe`, and `editorial` so label text color follows `labelColor`/`labelOpacity`.
- Kept accent visuals style-specific: split divider, racing stripe bar, and editorial underline still use `accentColor`.
- Synced preview and export renderers so canvas output and exported frames match.
- Updated preset apply behavior so these three presets default `labelColor` to the preset accent color for backward visual parity.

Files changed:

- `Sources/RunningOverlay/UI/PreviewCanvasView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `docs/design/overlays/numeric/numeric-overlay-ui.md`
- `docs/project-log.md`

### Timeline Layer Right-Click Delete + FIT Drag Lock (2026-05-10)

Summary:

- Added right-click context menu on non-FIT timeline layer rows (`Layer 1`, `Layer 2`, …) with a "Delete <layer>" action; FIT row has no menu.
- `ProjectDocument.removeTrack(named:)` removes the track and its clips, clears matching `previewTrackName`/`disabledPreviewTrackNames`, and registers an undo point.
- Disabled horizontal drag on the FIT green track — dragging it had no meaningful semantics. Mouse-down on FIT rects is now a no-op; drag state and `mouseUp` commit removed.

Files changed:

- `Sources/RunningOverlay/Timeline/TimelineModel.swift`
- `Sources/RunningOverlay/Project/ProjectDocument.swift`
- `Sources/RunningOverlay/UI/TimelineView.swift`

### Timeline Sticky Label Column (2026-05-10)

Summary:

- The left label column (FIT / Layer 1 / Layer 2 …) now stays pinned to the viewport when the timeline scrolls horizontally. Previously the labels scrolled away with the content.
- Implementation: `TimelineCanvasNSView` observes its clip view's `boundsDidChange` notifications and, after all timeline content draws, paints a label-column overlay shifted to the current `scrollOffsetX`. The original document-coordinate label cells remain at x=0, so the un-scrolled state is unchanged.

Files changed:

- `Sources/RunningOverlay/UI/TimelineView.swift`

### Export Performance Test9 + Next Benchmark Plan (2026-05-12)

Summary:

- Added the fixed benchmark fixture workflow for future optimization rounds:
  `/Users/codywang/Documents/Video Production/0509 纽约/running_overlay_project_snapshot.json`.
- Ran the new non-interactive benchmark command into Test9. Results:
  `totalDuration=428.517s`, `imageRenderDuration=290.774s`,
  `pixelBufferDrawDuration=135.670s`, `renderPath=perOverlay`.
- Test9 kept the Test8 render-time improvement, but draw time increased, so
  the next slice should reduce `ImageRenderer` work without adding more final
  pixel-buffer draw operations.
- Tested and reverted the next Distance Timeline static/dynamic split after
  Test10/Test11. It reduced pixel-buffer draw time but increased
  `ImageRenderer` time enough to regress total export time.

Files changed:

- `docs/export-performance.md`
- `docs/development.md`
- `docs/project-log.md`

Verification:

- Automated benchmark command completed successfully:
  `swift run RunningOverlay --benchmark-export "/Users/codywang/Documents/Video Production/0509 纽约/running_overlay_project_snapshot.json" --benchmark-output "/Users/codywang/Documents/Video Production/0509 纽约/Test9"`.
- Rejected benchmark results:
  - Test10: `totalDuration=435.685s`, `imageRenderDuration=362.332s`,
    `pixelBufferDrawDuration=71.044s`.
  - Test11: `totalDuration=470.050s`, `imageRenderDuration=381.938s`,
    `pixelBufferDrawDuration=85.704s`.

### Export Numeric Batch Candidate (2026-05-12)

Summary:

- Added a conservative numeric overlay batch candidate for the per-overlay
  export path.
- Batchable overlays are simple numeric/text overlays; complex overlays such
  as Distance Timeline, Route Map, Running Gauge, lap overlays, weather, and
  decor remain separate.
- The batch is enabled only when the padded numeric union is below 45% of the
  canvas and smaller than the sum of individual numeric padded areas.
- Profiling records the batch under the first grouped numeric overlay type so
  the existing schema remains stable.
- Test12 improved on Test9: `totalDuration=408.537s`,
  `imageRenderDuration=282.182s`, `pixelBufferDrawDuration=124.412s`,
  `overlayRenderCount=18882`, and `overlayDrawCount=75464`.

Verification:

- `swift test`
- `git diff --check`
- Fixed-snapshot benchmark:
  `swift run RunningOverlay --benchmark-export "/Users/codywang/Documents/Video Production/0509 纽约/running_overlay_project_snapshot.json" --benchmark-output "/Users/codywang/Documents/Video Production/0509 纽约/Test12"`.
- Extracted a Test12 frame with `ffmpeg` and confirmed overlay positions match
  the expected preview layout.

### Interval FIT Track Coloring (2026-05-13)

Summary:

- Added interval-workout detection on `ActivityTimeline` using existing lap
  classifications: at least two RUN laps and at least one REST lap.
- Updated the AppKit timeline FIT track to color interval phases from
  `LapRecord.kind` while preserving the default green bar for steady
  activities.
- Timer-paused spans still render as muted gray overlays above any interval
  phase colors, but below the FIT track outer border so their visual height
  matches adjacent phase blocks.
- FIT track hover tooltips are English: pause spans show `Timer Paused`, and
  interval phase spans show lap kind, lap number, elapsed range, and duration.
- Documented that the current FIT track UI is not draggable.

Verification:

- Added unit coverage for interval-workout detection.
- `git diff --check`
- `swift test`
- `swift test --filter TimelineModelTests`

### Interval HUD Bar Inspector Customization (2026-05-13)

Summary:

- Reworked Interval HUD Bar metrics from fixed visibility toggles into an ordered add/delete list with unlimited slots and duplicate metrics allowed.
- Added dividers between every metric block so user-added metrics follow the same block rhythm as Rep, Phase, and Remaining.
- Changed the HUD main row so Rep, Phase, Remaining, and each metric render as equal-width cells; empty metric space is not reserved when no metrics are configured.
- Expanded Interval HUD Bar metric options to include every Numeric Overlay metric.
- Moved `HR Zone` and `HR Drop` out of the Metrics add list into a dedicated HR Zone HUD cell with `HR Zone` and `HR Drop at Rest` display modes.
- Added visibility toggles for the four primary HUD cells: Rep, Current Training, Remaining, and HR Zone.
- Added Current Training detail controls so normal training and REST can independently show remaining time or remaining distance.
- Moved the `HR Drop` bpm/% mode control under the HR Zone settings.
- Split Bottom Bar into its own Inspector section below Metrics with an enable switch, type menu, progress mode, Glow toggle, and Glow Intensity.
- Added Bottom Bar glow rendering: lap progress glows the completed portion, and zone modes glow the active segment using the phase/zone color.
- Added a Remaining setting that swaps the primary/secondary display between time left and distance left.
- Simplified Remaining secondary label to always read `LEFT`.
- Added separate typography controls for labels, primary values, phase, phase detail, metric values, and metric units.
- Aligned the Inspector tail with the shared pattern: Divider, Background, Border, Effects. Background, Border, and Effects use the shared modules; Divider uses shared overlay divider fields.
- Added default-backed decoding for Interval HUD Bar styles so early project snapshots survive newly added style fields.
- Restored collapsible behavior and header divider lines for Layout, HUD Bar, Metrics, and Typography, and aligned the Interval HUD Bar detail header height with the shared Inspector header.

Files changed:

- `Sources/RunningOverlay/Overlay/IntervalHUDBarModel.swift`
- `Sources/RunningOverlay/Overlay/OverlayRenderModel.swift`
- `Sources/RunningOverlay/UI/IntervalHUDBarOverlayView.swift`
- `Sources/RunningOverlay/UI/IntervalHUDBarOverlayDetailView.swift`
- `Sources/RunningOverlay/Export/OverlayFrameRenderer.swift`
- `Tests/RunningOverlayTests/OverlayRenderModelTests.swift`
- `Tests/RunningOverlayTests/OverlayTemplateTests.swift`
- `docs/design/overlays/interval-hud-bar/interval-hud-bar-overlay-ui.md`
- `docs/design/overlays/interval-hud-bar/interval-hud-bar-overlay-ui.spec.json`
- `docs/overlay-modules/interval-hud-bar-overlay.md`
- `docs/project-log.md`
