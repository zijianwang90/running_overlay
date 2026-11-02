# Provider Credentials

Running Overlay ships no API keys and embeds no credentials in the Fuse, the
Workflow plugin, templates, fixtures, or render bundles. Any provider token is
supplied by the person using the app and is stored locally.

## Mapbox token

The optional Route Map background uses a Mapbox public token (`pk.*`).

- Location: one user-level file, `settings.json`, in the app's user-data
  directory (`~/Library/Application Support/Running Overlay Resolve/` on macOS).
- Format: `{ "schemaVersion": 1, "mapboxToken": "pk.…" | null }`.
- Permissions: the directory is created with mode `0700` and the file is written
  with mode `0600`.
- The file is written atomically (temporary file, then rename), so an
  interrupted save leaves the previous complete file.
- The token is shared by every Resolve project on that Mac. It is not copied
  into per-project configurations under `configurations/`.
- It never appears in `map.png`, `map.json`, `map-tiles.json`, the bundle
  manifest, saved templates, or logs. Only the snapshot and token-free metadata
  are written into the immutable render bundle.
- The panel reads and writes it through the `settings:load` / `settings:save`
  IPC handlers. The renderer cannot choose a file path or request an arbitrary
  URL.

### Legacy project tokens

Earlier builds stored the token in each project configuration. When a project
file that still contains one is loaded, the service copies it into
`settings.json` if that file has no token yet, then rewrites the project file
without the token. A normal panel scan performs this migration; no apply is
needed. An existing user-level token always wins over a legacy project token.

## Clearing and rotating

- **Clear:** open the **Settings** card and choose **Clear token**. The next
  overlay update removes the map background; existing bundles keep their
  already-fetched snapshot until they are updated.
- **Rotate:** paste the new `pk.*` token in **Settings**, then choose
  **Update overlay** so a new snapshot is fetched with it. Until then, the
  previous snapshot keeps rendering.
- **Reset:** if `settings.json` is malformed, the panel reports an error instead
  of silently ignoring it. Delete the file to return to defaults, then paste the
  token again. Deleting it does not affect saved projects or render bundles.

Mapbox bills requests made with your token to your Mapbox account. High-detail
tiles add four requests per overlay update and are off by default.
