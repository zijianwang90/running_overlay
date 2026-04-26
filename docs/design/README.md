# Design Docs

This directory stores implementation-facing product design references for Running Overlay.

## App UI

- [App UI Design System](./app-ui.md): application-level visual language, tokens, layout principles, and interaction standards.
- [App UI Structured Spec](./app-ui.spec.json): machine-readable app-level token and component guidance.

## Preview UI

- [Preview UI Spec](./preview-ui.md): human-readable layout, interaction, and component guidance for the central Preview area.
- [Preview UI Structured Spec](./preview-ui.spec.json): machine-readable state, component, and interaction definitions for implementation agents.
- [Preview mockup](./preview.png): Preview panel with in-panel safe guides control and simplified playback row.

## Timeline UI

- [Timeline UI Spec](./timeline-ui.md): human-readable layout, interaction, and component guidance for the bottom Timeline panel.
- [Timeline UI Structured Spec](./timeline-ui.spec.json): machine-readable state, component, and interaction definitions for implementation agents.
- [Timeline mockup](./timeline.png): Timeline panel with FIT track, video tracks, subtle playhead, collapse control, zoom, and drop target.

## Inspector UI

- [Inspector UI Spec](./inspector-ui.md): human-readable design, interaction, layout, and component guidance.
- [Inspector UI Structured Spec](./inspector-ui.spec.json): machine-readable state, component, and token definitions for implementation agents.
- [Inspector outer mockup](./inspector-outer.png): default Inspector state for adding and managing overlays.
- [Overlay detail mockup](./overlay-detail-running-gauge.png): detail editor state after selecting an overlay.
- [Numeric Overlay UI Spec](./numeric-overlay-ui.md): dense reusable Inspector detail template for numeric metric overlays.
- [Numeric Overlay UI Structured Spec](./numeric-overlay-ui.spec.json): machine-readable controls, model gaps, and unit rules for numeric overlay development.
- [Numeric Overlay mockup](./numeric-overlay.png): compact numeric overlay detail panel with units and background controls.

## Media Pool UI

- [Media Pool UI Spec](./media-pool-ui.md): human-readable design, interaction, layout, and component guidance.
- [Media Pool UI Structured Spec](./media-pool-ui.spec.json): machine-readable state, component, and token definitions for implementation agents.
- [Media Pool mockup](./media-pool.png): media list state with context menu and mark submenu.
- [Media Pool empty mockup](./media-pool-empty.png): empty media state with drag/drop import affordance.
