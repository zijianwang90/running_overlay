# Running Overlay

Running Overlay is a native macOS app for generating sports-data overlay videos from FIT activity files and one or more source videos.

Current project status: product and engineering documentation bootstrap.

## Build

```sh
swift build
```

Run from source during early development:

```sh
swift run RunningOverlay
```

## Documents

- [Product Requirements](docs/requirements.md)
- [Development Guide](docs/development.md)
- [Architecture Notes](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Featured Overlay Modules](docs/overlay-modules/)
- [Project Log](docs/project-log.md)
- [Decision Records](docs/adr/)

## Documentation Rule

Every meaningful product or engineering change should update the relevant documents in the same development step:

- Requirements changes go into `docs/requirements.md`.
- Implementation decisions and engineering notes go into `docs/development.md` or `docs/architecture.md`.
- Milestone progress goes into `docs/roadmap.md`.
- Work history goes into `docs/project-log.md`.
- Decisions that affect future work get an ADR under `docs/adr/`.
