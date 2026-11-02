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
- Multi-resolution detail is opt-in. When enabled, the control plane also fetches
  a 2×2 grid of quadrants at one zoom level deeper and writes four `map-N.png`
  files. The Fuse selects the quadrant under the camera above 1.5× zoom through
  optional `MapTile1`–`MapTile4` inputs, keeping route coordinates in overview
  units so the overview and tiles share one transform. Detail requests are
  billable, so a failed tile fetch keeps the overview and reports the error
  instead of failing the apply.
- The public `pk.*` token belongs to one user-level settings file on this Mac,
  not to a project file. It is never written into the bundle, templates, logs or
  repository. Legacy project tokens migrate to settings on the first scan.
  Fetches use the token in the query string only for that request. The product
  ships no provider key; users paste their own.
- Provider or network failures are non-fatal: the panel reports the error, skips
  the background and still publishes data and the transparent trace.
- The map, trace, position marker and direction arrow share one camera and card
  mask. Mapbox attribution is present in the snapshot and a text attribution is
  drawn over the card.

## Consequences

Existing projects without a token render exactly as before, and a published
bundle always renders the same map even without network access. Changing the
token or coverage requires a new apply, which creates a new immutable revision;
ordinary style and time-offset edits reuse the cached snapshot. Detail tiles
cost five requests per apply when enabled and still sharpen only one quadrant at
a time, so live tiles remain future work. Mapbox terms, logo/attribution
placement, request billing and the single provider choice need human review
before this is treated as release-ready.
