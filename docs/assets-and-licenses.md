# Assets and Third-Party Licenses

## Repository License

Unless this document or a file states otherwise, source code, documentation,
authored test fixtures, project templates, design references, and image assets
in this repository are distributed under the repository
[MIT License](../LICENSE).

The following are not licensed under the MIT License:

- the Running Overlay Studio name, logos, and other marks described in
  [`TRADEMARKS.md`](../TRADEMARKS.md);
- AppIcon renditions under `AppStore/Assets.xcassets/AppIcon.appiconset/`;
- branding artwork under `docs/design/branding/`;
- donation QR images under `docs/assets/donations/`.

Forks and modified distributions must replace those items.

Contributors must not add assets copied from products, icon packs, fonts,
stock libraries, activity services, or media files without documenting the
license and attribution requirements here.

## Runtime Dependencies

The Swift package currently declares no third-party runtime dependencies.

## Resolve Test Dependencies

The Resolve Node tests execute Lua through Fengari 0.1.5 (MIT). Its locked
transitive dependencies are readline-sync 1.4.10 (MIT), sprintf-js 1.1.3
(BSD-3-Clause) and tmp 0.2.7 (MIT). These are development-only dependencies;
the assembly script does not copy node_modules into the Workflow plugin.
Their upstream license files remain in the installed npm packages. No new
font files are bundled by the numeric text controls.

## Apple Platform Resources

The project references SF Symbols by symbol name and uses Apple system fonts
at runtime. It does not redistribute SF Symbols artwork or Apple font files.
Their use remains subject to the applicable Apple platform and SDK terms.

The Digital Watch preset uses the system-provided `Menlo-Bold` face. The
previous third-party Bank Gothic font file was removed before public source
publication because its redistribution rights were not sufficiently
documented.

## Repository Assets

- Weather condition PNGs under
  `Sources/RunningOverlay/Resources/Icons/` are project assets contributed by
  the repository owner and distributed under the repository license.
- The Running Overlay Studio AppIcon renditions under
  `AppStore/Assets.xcassets/AppIcon.appiconset/` are derived from artwork
  supplied by the repository owner. They are excluded from the repository
  license.
- Design mockups under `docs/design/` are project documentation assets and
  are distributed under the repository license, except `docs/design/branding/`.
  The horizontal banner concept under `docs/design/branding/` was generated
  specifically for this project with OpenAI image generation, using the
  repository App Icon as a visual reference, and contains no third-party
  artwork.
- Product screenshots under `docs/assets/screenshots/` are project
  documentation assets supplied by the repository owner and distributed under
  the repository license.
- App Store source captures and rendered marketing screenshots under
  `AppStore/Screenshots/` are supplied by the repository owner or generated
  from those captures and are distributed under the repository license. The
  reusable telemetry background was generated specifically for this project
  with OpenAI image generation and contains no third-party artwork.
- Donation QR images under `docs/assets/donations/` are supplied by the
  repository owner solely to receive voluntary project support. They contain
  personal payment identifiers and are not licensed for reuse or redistribution
  outside this repository's support section.
- `EasyRun.rotemplate`, `IntervalWorkout.rotemplate`, and `Race.rotemplate`
  are authored project templates distributed under the repository license.
- Test SVG, FIT, and visual snapshot fixtures are synthetic project
  assets documented in `Tests/RunningOverlayTests/Fixtures/README.md`.

## External Services

Open-Meteo and OpenWeather are optional runtime data providers, not bundled
code dependencies. Users are responsible for complying with provider terms
and supplying their own OpenWeather credentials where required.

## Resolve Vector Glyphs

The numeric glyph paths in
`RunningOverlayResolve/fusion/Fuses/RunningOverlayNumeric.fuse` were authored for
this project on a 24-unit grid and are distributed under the repository MIT
license. They are original line/Bezier shapes, not extracted SF Symbols artwork.
No Apple font files, symbol assets, map tiles or third-party icon packs are
bundled. Resolve uses installed fonts at runtime. Synthetic route coordinates
in tests are fictional authored fixtures and do not describe a user's activity.
