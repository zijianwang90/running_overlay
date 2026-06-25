# Documentation Index

This page routes contributors and AI agents to the smallest relevant document
set. Current requirements and architecture take precedence over historical
entries in `project-log.md`.

## First Read

| Task | Read |
|---|---|
| Any code change | `AGENTS.md`, then this index |
| Contributor workflow | `docs/contributing.md`, `docs/testing.md` |
| Product behavior | `docs/requirements.md` |
| Architecture or subsystem boundaries | `docs/architecture.md`, relevant ADR |
| Implementation conventions | `docs/development.md`, then the relevant subsystem guide |
| Planned work | `docs/roadmap.md` |
| Historical context | `docs/project-log.md` |

## Task Routing

| Change area | Primary documents |
|---|---|
| FIT parser or workout analysis | `docs/architecture.md#fit-data`, `docs/testing.md` |
| Media import and alignment | `docs/architecture.md#media-import`, `docs/architecture.md#alignment-engine` |
| Timeline behavior | `docs/architecture.md#timeline`, `docs/design/panels/timeline/` |
| Numeric overlays | `docs/design/overlays/numeric/`, `docs/requirements.md` |
| Featured overlays | `docs/overlay-modules/README.md`, matching module and design directory |
| Preview | `docs/architecture.md#preview`, `docs/design/panels/preview/` |
| Export or performance | `docs/architecture.md#export`, `docs/export-performance.md` |
| Project persistence or undo | `docs/architecture.md`, `docs/development/persistence.md` |
| UI design system | `docs/design/README.md`, `docs/design/system/` |
| Fixtures and snapshots | `docs/testing.md` |
| Security and privacy | `docs/security.md` |
| User data and network behavior | `PRIVACY.md` |
| Mac App Store packaging and submission | `docs/development/release.md`, `docs/app-store-readiness.md` |
| Maintainer and support policy | `MAINTAINERS.md`, `SUPPORT.md` |
| Asset and dependency licensing | `docs/assets-and-licenses.md` |
| Publication readiness | `docs/open-source-readiness.md` |
| Issue preparation | `docs/issue-labels.md`, GitHub issue templates |

## Decision Records

ADRs under `docs/adr/` document decisions that constrain future work. Add a
new ADR when changing a cross-cutting architectural choice, not for routine
implementation detail.

## Documentation Maintenance

- Update requirements when product behavior changes.
- Update architecture when responsibilities or data flow change.
- Update module/design docs when controls or rendering behavior change.
- Update testing documentation when fixture or validation workflows change.
- Add important completed work to the current monthly file linked from
  `docs/project-log.md`.
- Keep machine-specific paths, credentials, private data, and unsupported
  future claims out of current documentation.
