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

The Swift package declares no third-party Swift package dependencies. Setting
`SKIA_DIR` enables an optional native Skia dependency; its GPU build links
`libskia.dylib`. The baseline development prebuilt is Skia m152 at
`0873ec164a06966b90ae0d43ef783cfb180084ae`; its original distributor provenance
still needs confirmation before shipping that binary.

The experimental SDK is built directly from the official
[Skia repository](https://skia.googlesource.com/skia.git) at m159 commit
`1bbd9b972a4667a98fb16b8441444b2282fed0ac`. Its included skcms revision is
`f0bbebbebb50851813e4f11d3d4b9edd2878a056`. Both use BSD-3-Clause notices,
reproduced in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) and copied
into the generated SDK with the build manifest. The minimal recipe excludes
external codec, HarfBuzz, ICU, Dawn and PartitionAlloc libraries. See the
[SDK guide](development/skia-sdk.md) for the exact source, build flags and
verification process. No Skia binary is committed. Building an experimental
SDK does not itself complete release approval. The Skia-enabled SwiftPM app
packager now embeds/signs the dylib and includes the notices in the app's Legal
directory. ADR 0011 selects the source-built m159 SDK for product cutover;
m152 distributor provenance is not required to distribute that different binary.

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
