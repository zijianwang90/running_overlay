# Quality, Testing, and Documentation

### Phase 7: Polish And Reliability

- Add error handling.
- Add project persistence.
- Add sample-file regression tests.
- Add interaction polish and performance profiling.

## 6. Testing Strategy

Initial testing should cover:

- FIT parsing using representative sample files.
- Time alignment from media metadata and filename patterns.
- Timeline model operations independent of UI.
- Overlay data sampling at known timestamps.
- Layer Data FPS quantization and activity-duration clamping.
- Export filename generation.

Later testing should cover:

- Visual snapshot checks for overlay rendering.
- Export smoke tests.
- Performance tests on long activities and many video clips.
- UI interaction tests for timeline drag and zoom.

## 7. Documentation Maintenance

For each development step:

- Update `docs/requirements.md` if user-facing behavior changes.
- Update the relevant guide linked from `docs/development.md` if
  implementation workflow or module boundaries change.
- Update `docs/architecture.md` if data flow, rendering flow, or subsystem responsibilities change.
- Add or update an ADR when a decision would be expensive to reverse.
- Add an entry to the current monthly file linked from `docs/project-log.md`
  with date, summary, files changed, and verification performed.
