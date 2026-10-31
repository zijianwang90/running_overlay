# ADR 0007: MIT License And Free App Distribution

Date: 2026-10-31

## Status

Accepted

## Context

The repository was published under the source-available PolyForm Shield License
with a separate commercial licensing path and a contributor license agreement.
The Mac App Store listing has moved to free, and the project owner wants the
project to be open source. The owner authored the existing code, so no other
contributor consent was needed to change the license.

## Decision

- License project code, documentation, fixtures, and templates under the MIT
  License from this change onward.
- Remove the commercial licensing path and contributor license agreement.
- Accept contributions under the MIT License with the Developer Certificate of
  Origin.
- Keep the trademark policy. Exclude the name, application icon, branding
  artwork, and donation images from the MIT License.

## Consequences

- Anyone may fork, sell, or close-source derivative work if they keep the
  copyright and license notice and do not use the project's marks.
- MIT grants for published versions cannot be withdrawn. A later license change
  can only affect later versions.
- The project no longer sells competing-use exceptions. Ongoing support relies
  on voluntary donations.
- Without a contributor agreement, a future relicense would require permission
  from outside contributors or removal of their work.
