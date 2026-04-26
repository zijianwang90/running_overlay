# ADR 0002: Swift Package Bootstrap For Native macOS App

Date: 2026-04-24

## Status

Accepted

## Context

The project started from an empty directory. The immediate goal is to begin native macOS development with a small, buildable foundation while product requirements are still evolving.

## Decision

Bootstrap the app as a Swift Package executable target using SwiftUI.

The initial package layout separates app, project state, FIT data, media import, timeline, overlay, preview, export, and UI concerns under `Sources/RunningOverlay/`.

## Consequences

Benefits:

- Fast setup from an empty repository.
- Simple command-line build with `swift build`.
- Clear source layout before Xcode-specific project settings become important.
- Easy future migration into an `.xcodeproj` or document-based app if needed.

Costs:

- A Swift Package executable is not the final distribution format for a polished macOS app.
- App bundle metadata, signing, entitlements, document types, and sandboxing still need to be formalized later.
