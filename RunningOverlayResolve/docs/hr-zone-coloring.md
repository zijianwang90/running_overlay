# Heart Rate Zone Coloring

N3 adds independent zone-color toggles to each numeric slot. They are visible
and effective only when Metric is **Heart Rate** or **HR Zone**. Each enabled
role uses the current heart rate's zone color; disabled roles keep their
configured colors.

| Control | Input ID | Default | Role tinted |
|---|---|---|---|
| Value Follows HR Zones | `NumericValueFollowHRZones` | Off | Numeric value or `Z1`…`Z6` text |
| Label Follows HR Zones | `NumericLabelFollowHRZones` | Off | Label |
| Unit Follows HR Zones | `NumericUnitFollowHRZones` | Off | Unit |
| Icon Follows HR Zones | `NumericIconFollowHRZones` | Off | Icon |

The four roles are independent: enabling one does not enable the others. The
**HR Zone Bar** shares the zone-range inputs below, but does not expose or use
these four toggles.

## Zone ranges

Ranges belong to each slot, not to a global setting. Use that slot's existing
**Zone Count** (5 or 6) and **Z1 Min/Max** through **Z6 Min/Max** HR inputs. The
same inputs classify heart rate for the HR Zone label, numeric tint and HR Zone
Bar when the corresponding metric is selected.

The default is six zones, in bpm:

| Zone | Default range |
|---|---|
| Z1 | 0–134 |
| Z2 | 134–151 |
| Z3 | 152–160 |
| Z4 | 161–171 |
| Z5 | 172–178 |
| Z6 | 178–250 |

Both endpoints are inclusive; the first matching zone wins overlaps. With the
defaults, 134 bpm belongs to Z1 and 178 bpm belongs to Z5. Five-zone mode uses
only the first five ranges. When heart rate is missing or outside every active
range, each role keeps its configured color.

## Palette and opacity

The fixed palette matches Mac `HRZonePalette.overlayColors`. RGB values are
normalized to 0–1; hex values are rounded to 8-bit channels.

| Zone | RGB | Hex |
|---|---|---|
| Z1 | 0.12, 0.56, 1.00 | `#1F8FFF` |
| Z2 | 0.28, 0.82, 0.96 | `#47D1F5` |
| Z3 | 0.18, 0.86, 0.42 | `#2EDB6B` |
| Z4 | 1.00, 0.84, 0.12 | `#FFD61F` |
| Z5 | 1.00, 0.56, 0.20 | `#FF8F33` |
| Z6 | 1.00, 0.22, 0.18 | `#FF382E` |

Only RGB is replaced. Each role retains its configured color alpha and opacity.
Zone tint does not change the background, border, glow or text-shadow colors
or settings; see [Numeric Container Controls](numeric-container.md) for those
effects.

## Mac parity and compatibility

For the shared model and renderer references, see the
[module parity audit](module-parity-audit.md#shared-references).

Mac classification reads global `HeartRateZonePreferences`. Resolve has no
project physiology settings, so it uses the slot's explicit ranges instead.
The default ranges and tint palette match the Mac defaults; later changes to
Mac preferences do not update Resolve slots.

Mac's legacy aggregate `textColorsFollowHeartRateZones` flag is not exposed.
Although it can trigger base-color resolution in the Mac render model, actual
role tinting reads the four role flags. Resolve exposes those four flags
independently. Resolve also preserves the configured color's alpha as well as
role opacity; the Mac tint path uses the opaque palette color multiplied by
role opacity, replacing the configured swatch alpha.

All four toggles default off. Existing input IDs and defaults are unchanged;
the new toggles therefore leave existing projects and renders unchanged.

## Limitations and validation

Tint is limited to Heart Rate and HR Zone. There is no pace-zone coloring, and
HR Zone Bar uses only the shared range inputs, not the numeric tint toggles.

Run the focused Node/Lua renderer suite from the repository root:

```sh
cd RunningOverlayResolve && node --test test/numeric-renderer.test.js
```

N3 host rendering is unverified. The Resolve Inspector, preview and Deliver
still need validation; passing the focused suite does not establish host
rendering or save/reopen compatibility.
