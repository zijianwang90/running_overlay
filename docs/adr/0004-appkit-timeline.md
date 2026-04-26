# ADR 0004: AppKit Self-Drawing Timeline

Date: 2026-04-24

## Status

Accepted

## Context

The first SwiftUI timeline validated the timeline data model, but high-frequency interactions such as clip dragging, seeking, scrolling, and future dense clip rendering need tighter control than a large SwiftUI view tree provides.

## Decision

Move the timeline interaction surface to an AppKit `NSView` embedded in SwiftUI through `NSViewRepresentable`.

The timeline draws ruler, tracks, clips, selection, and a DaVinci-style full-height playhead directly in `draw(_:)`, and handles pointer events with AppKit mouse, scroll, and dragging APIs.

SwiftUI remains responsible for the app shell, media browser, preview, inspector, sheets, and other lower-frequency UI.

## Consequences

Benefits:

- Smoother clip dragging and timeline seeking.
- Lower view hierarchy overhead for dense timeline rendering.
- More direct control over drawing, hit testing, scrolling, and modifier-key behavior.

Costs:

- Timeline UI now has AppKit-specific code.
- Some SwiftUI conveniences need explicit bridging.
- Future timeline features should keep model updates separate from transient drag state.
