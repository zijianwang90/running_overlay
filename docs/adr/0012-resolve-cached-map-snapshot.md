# ADR 0012: Cached Map Snapshots Keep Resolve Route Rendering Offline

Date: 2026-11-01

## Status

Implemented for development validation; Mapbox licensing and attribution require
focused human review before merge.

## Context

The Resolve sibling cannot use MapKit. Users still expect the Mac templates'
dark map background, zoomable follow camera and course-up orientation for race
visuals. Fusion render callbacks must stay deterministic and offline, must not
read private credentials, and must not depend on the network during playback or
Deliver. A long race needs more map detail than a single low-zoom picture can
provide near the runner.

## Decision

- The control plane, not the Fuse, owns the map provider. One Mapbox Static
  Images request per successful apply fetches a square snapshot using the same
  Web Mercator bounds and coverage factor as the Fuse's projected route.
- The snapshot and token-free metadata are written into the immutable render
  bundle referenced by the manifest. The Fuse reads the image through an optional
  `MapImage` input from a Loader marked as managed by the product, and performs
  panning, zoom and rotation in the render callback with no networking.
- The public `pk.*` token belongs only to local project settings. It is never
  written into the bundle, templates, logs or repository. Fetches use the token
  in the query string only for that request.
- Provider or network failures are non-fatal: the panel reports the error, skips
  the background and still publishes data and the transparent trace.
- The map, trace, position marker and direction arrow share one camera and card
  mask. Mapbox attribution is present in the snapshot and a text attribution is
  drawn over the card.

## Consequences

Existing projects without a token render exactly as before, and a published
bundle always renders the same map even without network access. Changing the
token or coverage requires a new apply, which creates a new immutable revision;
ordinary style and time-offset edits reuse the cached snapshot. The fixed
snapshot softens at high camera zoom, so live tiles or multi-resolution snapshots
remain future work. Mapbox terms, logo/attribution placement and the single
provider choice need human review before this is treated as release-ready.
