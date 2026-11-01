# Synthetic Resolve Fixtures

These fixtures are authored for this repository and contain no athlete,
device, media-path, or real GPS data.

- `activity.synthetic.json` describes a fictional 30-minute activity beginning
  at a deterministic UTC instant, including authored running dynamics,
  temperature and grade values with explicit gaps.
- `activity.synthetic.gpx` is an authored four-point fictional track with
  explicit microsecond timestamps, two track segments, sparse metrics, and
  coordinates chosen solely to verify that segment gaps add no distance.
- `timeline.synthetic.json` models two ordinary 1x timeline cuts at 30000/1001
  fps. The first cut starts 12 seconds into its source media.
- `media.synthetic.json` provides fictional, mutually agreeing capture-time
  evidence for both source clips.

Together they verify the central piecewise-alignment case: the first edit maps
to activity time 05:22, while the second edit jumps to 20:00 rather than
continuing from the finished-program duration.
