# Project Settings And Font Library UI Spec

Last updated: 2026-04-30

## Purpose

This spec defines the Project Settings modal and the Font Library management sheet. The two surfaces share one macOS utility design language: dark translucent window chrome, centered modal titles, grouped sections, inset rows, subtle dividers, and blue primary actions.

Mockup reference:

![Project Settings and Font Library mockup](./project-settings-font-library.png)

Default font interaction reference:

![Font Library inline default mockup](./font-library-default-inline.png)

## Visual Language

- Use the same modal treatment for both windows: dark glassy panel, subtle border, large outer corner radius, and macOS traffic-light controls when presented as a standalone window mockup.
- Titles are centered at the top of the modal.
- Settings content is organized into section headers and bordered grouped boxes.
- Rows use stable heights, thin separators, left labels, and right-aligned controls.
- Primary actions use the app blue. Secondary buttons use raised dark control styling.
- Footer areas are separated from content by a divider and keep the primary `Done` button right-aligned.

## Project Settings Layout

The settings modal should include only the current project export/settings controls:

1. `Video`
   - `Resolution` dropdown with `1080p 16:9`.
   - `Frame Rate` dropdown with `30 fps`.
   - `Layer Data FPS` dropdown with `10 fps`.
2. `Encoding`
   - `Bitrate` slider with blue filled track, knob, and right-aligned value `30 Mbps`.
3. `Typography`
   - `Font Library` row.
   - Caption: `Choose fonts shown in overlay menus.`
   - Right secondary button: `Manage...`.

The modal footer contains a right-aligned primary `Done` button.

Do not add unrelated settings such as project name, theme, notifications, hotkeys, opacity, or background controls unless those features are implemented and explicitly added to the settings model.

## Font Library Layout

The Font Library sheet manages the global favorite font list used by overlay font pickers.

Structure:

1. Centered title: `Font Library`.
2. Subtitle: `Manage fonts shown in overlay menus.`
3. Search field with magnifying glass and placeholder `Search fonts`.
4. `Favorites` grouped list.
5. `All Fonts` grouped list.
6. Footer with selected count and primary `Done` button.

Rows use checkbox selection rather than a trailing-only checkmark because this screen is a management surface, not a picker menu.

## Font Row Content

Every font row contains three aligned parts, plus an inline default action in the `Favorites` section:

- Checkbox at the leading edge.
- Font family name rendered in that family.
- Inline `Default` action immediately after the font family name when applicable.
- Numeric running preview rendered in the same family.

Examples:

| Family | Preview |
| --- | --- |
| `SF Pro` | `5'42"/km` |
| `Avenir Next` | `10.24 km` |
| `Helvetica Neue` | `4'58"/km` |
| `Menlo` | `42.20 km` |
| `Arial` | `4'45"/km` |

The numeric preview column must be right-aligned so users can compare how digits, decimal points, and pace notation look across fonts. Row height must remain stable even when font metrics vary.

## Default Font

The Font Library supports one default font selected from the favorite list.

Default display rules:

- The current default favorite shows a compact blue `Default` pill immediately after the font family name.
- Non-default favorites do not show the action by default.
- On row hover, a compact gray `Default` button appears in the same inline position after the font family name.
- Clicking the gray `Default` button makes that font the new default and turns its button blue.
- Do not use stars, trailing badges, or a separate default column.
- Reserve enough inline space after the family name so the row does not jump when the hover button appears.
- Keep the numeric preview column right-aligned independently from the inline `Default` action.

Default behavior:

- The default font must always be one of the favorite fonts.
- Removing the current default from favorites should promote the first remaining favorite to default.
- If no favorites remain, overlay pickers still use the fallback family list and the default resolves to the first fallback family.
- The footer should include both count and default, for example `6 fonts selected • Default: SF Pro`.

## Behavior

- Search filters all system font families by localized case-insensitive family name.
- Toggling a checkbox adds or removes that family from favorites.
- `Favorites` shows selected fonts first.
- `All Fonts` shows searchable system font families and still reflects selected state.
- The footer count uses the raw selected count and current default, for example `6 fonts selected • Default: SF Pro`.
- If the user clears all favorites, overlay font pickers fall back to the default set: `SF Pro`, `Avenir Next`, `Helvetica Neue`, `Menlo`.

## Implementation Notes

- Use shared app tokens from [App UI Design System](../../system/app-ui.md).
- Prefer reusable grouped-section and row primitives instead of one-off styling in `ProjectSettingsView` and `FontLibraryView`.
- Keep control radii within the app system guidance: 6-8 px for controls and grouped boxes.
- Use monospaced or stable numeric rendering only where it does not conflict with the row's requirement to preview the selected font. In the Font Library list, the preview must use the row font.
- Avoid decorative copy or explanatory blocks inside the modal beyond the one Font Library subtitle and the Typography row caption.
