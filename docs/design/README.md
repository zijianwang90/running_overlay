# Design Docs

This directory stores implementation-facing product design references for Running Overlay.

## How To Read

- Start with [App UI Design System](./system/app-ui.md) for global tokens, tone, layout principles, and shared interaction rules.
- Use panel specs in `panels/` when implementing editor surfaces.
- Use overlay specs in `overlays/` when implementing or reviewing a specific overlay detail UI.
- Each topic keeps its human-readable `.md`, machine-readable `.spec.json`, and related mockups together.
- Older project log entries may mention the previous flat `docs/design/*.md` paths; this README is the current source of truth.

## System

- [App UI Design System](./system/app-ui.md): application-level visual language, tokens, layout principles, and interaction standards.
- [App UI Structured Spec](./system/app-ui.spec.json): machine-readable app-level token and component guidance.

## Panels

- [Preview UI Spec](./panels/preview/preview-ui.md): central Preview panel layout, interactions, and component guidance.
- [Preview UI Structured Spec](./panels/preview/preview-ui.spec.json): machine-readable Preview state, component, and interaction definitions.
- [Preview mockup](./panels/preview/preview.png): Preview panel with in-panel safe guides control and simplified playback row.
- [Timeline UI Spec](./panels/timeline/timeline-ui.md): bottom Timeline panel layout, interactions, and component guidance.
- [Timeline UI Structured Spec](./panels/timeline/timeline-ui.spec.json): machine-readable Timeline state, component, and interaction definitions.
- [Timeline mockup](./panels/timeline/timeline.png): Timeline panel with FIT track, video tracks, playhead, collapse control, zoom, and drop target.
- [Media Pool UI Spec](./panels/media-pool/media-pool-ui.md): left Pool panel design for Media Pool, Overlay Pool, Templates, FIT-first import, interactions, layout, and component guidance.
- [Media Pool UI Structured Spec](./panels/media-pool/media-pool-ui.spec.json): machine-readable left Pool state, component, template management, and token definitions.
- [Media Pool mockup](./panels/media-pool/media-pool.png): media list state with context menu and mark submenu.
- [Media Pool empty mockup](./panels/media-pool/media-pool-empty.png): empty media state with drag/drop import affordance.
- [Inspector UI Spec](./panels/inspector/inspector-ui.md): right Inspector panel design, interaction, layout, and component guidance.
- [Inspector UI Structured Spec](./panels/inspector/inspector-ui.spec.json): machine-readable Inspector state, component, and token definitions.
- [Inspector outer mockup](./panels/inspector/inspector-outer.png): legacy Inspector outer reference; current Inspector outer manages added overlays while add-overlay tiles live in Overlay Pool.
- [Overlay detail mockup](./panels/inspector/overlay-detail-running-gauge.png): detail editor state after selecting an overlay.
- [Project Settings, Heart Rate Zones, and Font Library UI Spec](./panels/project-settings/project-settings-ui.md): grouped settings modal, HR/pace zone sheet, and font favorite management sheet.
- [Project Settings, Heart Rate Zones, and Font Library Structured Spec](./panels/project-settings/project-settings-ui.spec.json): machine-readable settings, physiology zone, and font library layout rules.
- [Project Settings and Font Library mockup](./panels/project-settings/project-settings-font-library.png): shared visual reference for both modals.
- [Heart Rate Zones mockup](./panels/project-settings/heart-rate-zones.png): simplified HR/pace zone configuration sheet reference.
- [Font Library inline default mockup](./panels/project-settings/font-library-default-inline.png): default font action shown inline after the favorite family name.

## Overlays

- [Numeric Overlay UI Spec](./overlays/numeric/numeric-overlay-ui.md): dense reusable Inspector detail template for numeric metric overlays.
- [Numeric Overlay UI Structured Spec](./overlays/numeric/numeric-overlay-ui.spec.json): machine-readable controls, model gaps, and unit rules for numeric overlay development.
- [Numeric Overlay mockup](./overlays/numeric/numeric-overlay.png): compact numeric overlay detail panel with units and background controls.
- [Route Map Overlay UI Spec](./overlays/route-map/route-map-overlay-ui.md): route map overlay editor layout and visual rules.
- [Route Map Overlay UI Structured Spec](./overlays/route-map/route-map-overlay-ui.spec.json): machine-readable route map controls, model paths, and presets.
- [Distance Timeline Overlay UI Spec](./overlays/distance-timeline/distance-timeline-overlay-ui.md): progress/timeline overlay style system, custom media slots, variants, and Inspector controls.
- [Distance Timeline Overlay UI Structured Spec](./overlays/distance-timeline/distance-timeline-overlay-ui.spec.json): machine-readable style variants, customization fields, and model gaps.
- [Distance Timeline style board](./overlays/distance-timeline/distance-timeline-overlay-styles.png): eight style directions for distance progress overlays.
- [Interval HUD Bar Overlay UI Spec](./overlays/interval-hud-bar/interval-hud-bar-overlay-ui.md): horizontal interval-training HUD with rep, phase, remaining work, live metrics, HR drop, and lap/zone bar modes.
- [Interval HUD Bar Overlay UI Structured Spec](./overlays/interval-hud-bar/interval-hud-bar-overlay-ui.spec.json): machine-readable Interval HUD Bar content, bottom bar, recovery, and inspector rules.
- [Interval HUD Bar mockup](./overlays/interval-hud-bar/interval-hud-bar.png): visual reference for WORK, REST, and HR zone bar states.
- [Weather Widget Overlay UI Spec](./overlays/weather-widget/weather-widget-overlay-ui.md): weather-app-style overlay presets, location/temperature content rules, and shared condition icon guidance.
- [Weather Widget Overlay UI Structured Spec](./overlays/weather-widget/weather-widget-overlay-ui.spec.json): machine-readable weather widget presets, fields, icon set, and data strategy.
- [Weather Widget preset board](./overlays/weather-widget/weather-widget-presets.png): five visual directions for weather app plugin-style overlays.
- [Weather Widget icon set](./overlays/weather-widget/weather-icon-set.png): unified weather condition icon family reference.
