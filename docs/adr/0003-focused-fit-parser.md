# ADR 0003: Focused First-Pass FIT Parser

Date: 2026-04-24

## Status

Accepted

## Context

The next product milestone needs a real activity timeline from imported FIT files. The project does not yet have a finalized dependency policy or a selected FIT library. Waiting for a full parser decision would slow down UI and data-flow development.

## Decision

Implement a focused first-pass FIT parser in `Sources/RunningOverlay/FitData/FitFileParser.swift`.

The parser currently targets standard FIT definition/data messages and extracts the fields required for the first activity timeline:

- record timestamp
- distance
- speed-derived pace
- heart rate
- elevation
- cadence
- power
- calories when available
- session start time
- session elapsed time
- session distance

## Consequences

Benefits:

- The app can import real `.fit` files early.
- Timeline and overlay work can proceed against real activity data.
- Parser limitations remain visible and contained in one module.

Costs:

- It is not a full FIT profile implementation.
- CRC validation, developer fields, compressed timestamp reconstruction, pauses, timezone behavior, and broader sport/session handling still need additional work.
- A mature external parser may still replace this implementation if later evaluation shows that is a better long-term choice.
