# Assets and Third-Party Licenses

## Repository License

Unless a file states otherwise, source code, documentation, authored test
fixtures, project templates, design references, and image assets in this
repository are distributed under the repository
[PolyForm Shield License 1.0.0](../LICENSE).

The license is source-available rather than OSI-approved open source. It does
not permit providing a product that competes with Running Overlay. Separate
commercial licensing is described in
[`COMMERCIAL-LICENSE.md`](../COMMERCIAL-LICENSE.md).

Contributors must not add assets copied from products, icon packs, fonts,
stock libraries, activity services, or media files without documenting the
license and attribution requirements here.

## Runtime Dependencies

The Swift package currently declares no third-party runtime dependencies.

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
- Design mockups under `docs/design/` are project documentation assets and
  are distributed under the repository license.
- Product screenshots under `docs/assets/screenshots/` are project
  documentation assets supplied by the repository owner and distributed under
  the repository license.
- Donation QR images under `docs/assets/donations/` are supplied by the
  repository owner solely to receive voluntary project support. They contain
  personal payment identifiers and are not licensed for reuse or redistribution
  outside this repository's support section.
- `EasyRun.rotemplate` is an authored project template distributed under the
  repository license.
- Test SVG, FIT, and visual snapshot fixtures are synthetic project
  assets documented in `Tests/RunningOverlayTests/Fixtures/README.md`.

## External Services

Open-Meteo and OpenWeather are optional runtime data providers, not bundled
code dependencies. Users are responsible for complying with provider terms
and supplying their own OpenWeather credentials where required.
