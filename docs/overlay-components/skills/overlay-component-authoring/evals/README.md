# Authoring Skill Smoke Tests

The prompts in [evals.json](evals.json) exercise scalar metrics and list data.
They are reproducible workflow checks, not a comparative model benchmark.

On 2026-11-07 an independent authoring run read only this skill and the public
protocol/docs/examples; it did not read Swift or change the application:

| Case | Validation | Rendering | Content checks |
|---|---|---|---|
| Pace badge | Passed | Empty, 30 s, 60 s, long-title/accent override | Non-reserved ID, host metric formatting, content sizing, editable title/accent, explicit missing-data text |
| Newest-first lap list | Passed | Empty, 30 s, 60 s, two-row/title override | Non-reserved ID, `structure.laps`, bounded unnested repeat, row-count/title params, reversed list indexing |

All final CLI runs exited zero with empty diagnostic output. The parent also
inspected the final lap override and empty pace images. Neither run claimed
app import/undo/save-reopen or video-export validation.

The exercise found three documentation gaps, since corrected in the guide:

- Lap lists include the whole source activity rather than only completed laps
  at the playhead. FIT indices start at zero; row numbering is a presentation
  choice. "Newest" in this test means the last entries in that full list.
- Copied bundled examples need new component IDs and author metadata.
- App content-sized ink outsets differ from the CLI's tight PNG crop.

For future repetitions, save components, override files, PNGs and exact command
results outside the repository. Validate and render before judging the output;
inspect missing data and parameter variants. Mark unavailable Skia or untested
app interactions explicitly. Keep the generated fixtures public and synthetic.
