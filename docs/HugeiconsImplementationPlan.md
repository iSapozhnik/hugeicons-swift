# Hugeicons (Free) Swift Wrapper Implementation Plan

## Goal
Maintain a standalone Hugeicons free-tier Swift package with deterministic codegen and update scripts.

## Scope
- Source: **official free set only** from `@hugeicons/core-free-icons`.
- Style: **Stroke Rounded** only (the free tier source package already aligns with free scope).
- Integration target: reusable Swift package consumed by apps (including Reforge).
- Codegen: use **SwiftGen** for strongly-typed access.

## Architecture (KISS + extraction-ready)

### 1) Directory layout
Use a future-package-friendly structure now:

- `Sources/Hugeicons/` (wrapper API layer + generated code)
- `Sources/Hugeicons/Resources/Hugeicons/` (generated SVG asset payload)
- `Scripts/icons/` (fetch + transform + generation scripts)
- `swiftgen.yml` for icon code generation

This keeps runtime API (`Platform/UI`) separate from generated resources and tooling.

### 2) Responsibility boundaries
- **Fetch script**: downloads and validates free icon source from official package.
- **Transform script**: normalizes filenames and writes `.svg` files in deterministic layout.
- **SwiftGen**: generates typed accessors from resource folder.
- **Wrapper layer**: exposes app-facing API and naming aliases if needed.

No runtime network fetches and no business logic in icon layer.

## Source of truth for free icon data

### Official programmatic source
Use npm tarball/package metadata for:
- `@hugeicons/core-free-icons`

Implementation detail:
1. Script reads pinned version from a lock/pin file.
2. Script runs `npm pack @hugeicons/core-free-icons@<version>` in a temp folder.
3. Script extracts package payload and converts `dist/esm/*Icon.js` module exports into on-disk SVG files.
4. Script writes a machine-readable manifest (icon name, category, source version, checksum).

Why this approach:
- Official source.
- Deterministic and reproducible builds.
- Easy to diff across updates.

## Suggested implementation phases

### Phase 0 — Preflight
- Add `UI/Icons` folder and placeholder README for conventions.
- Decide naming strategy for generated identifiers (see naming section below).
- Decide whether icons go to asset catalog vs plain resource SVG files.

Recommendation: start with plain SVG resources + generated constants, then add optional `Image` convenience wrappers.

### Phase 1 — Fetch pipeline
Create `Scripts/icons/fetch_hugeicons_free.sh`:
- Inputs: version pin, output directory.
- Actions:
  - Create temp working dir.
  - `npm pack` free package.
  - Extract package.
  - Convert `dist/esm/*Icon.js` icon modules into canonical `.svg` payload in repo staging folder.
  - Write `conversion-report.json` with module/converted/skipped counts and skip reasons.
- Validation:
  - Non-zero converted icon count.
  - Warn-and-skip on unexpected module shapes.
  - Do not fail solely due to skipped modules; fail only when converted icon count is zero (or fetch/converter setup fails).

Create `Scripts/icons/verify_hugeicons_free.swift` (or shell/python equivalent):
- Verify duplicate names.
- Verify all files are valid SVG XML.
- Produce `manifest.json` with checksums.

### Phase 2 — Name normalization
Create deterministic mapping rules from kebab-case file names to Swift-safe identifiers:
- `home-01` -> `home01`
- `arrow-down-left` -> `arrowDownLeft`
- Leading digits prefixed, e.g. `24-hours` -> `icon24Hours`
- Swift keywords suffixed/prefixed safely.

Output mapping file:
- `Sources/Hugeicons/Resources/Hugeicons/name-map.json`

This map is critical for stable API during future updates.

### Phase 3 — SwiftGen integration
Configure SwiftGen for SVG resource generation.

Two viable paths:
1. **files template** over SVG directory (simplest).
2. **xcassets template** if converting SVGs into asset catalogs with “Preserve Vector Data”.

Initial recommendation:
- Use `files` template to generate:
  - `HugeiconsGenerated.swift`
  - static typed constants for resource names/paths.

Then add thin wrapper:
- `Hugeicons` namespace/enum in `Sources/Hugeicons/`.
- Optional helpers:
  - `func image(bundle: Bundle = .module) -> Image`
  - `func nsImage(bundle: Bundle = .module) -> NSImage?`

### Phase 4 — App integration
- Replace ad-hoc icon usages incrementally.
- Keep existing SF Symbols where design prefers platform-native symbols.
- Add internal usage examples in previews.

### Phase 5 — Update workflow
Add one command for refresh:
- `Scripts/icons/update_hugeicons_free.sh`

Pipeline:
1. fetch
2. verify
3. regenerate SwiftGen
4. summary output (added/removed/renamed counts)

## Naming/API proposal
Keep generated layer separate from public wrapper API:

- Generated: `HugeiconsGenerated` (machine-owned; never edit)
- Public wrapper: `Hugeicons` (human-owned)

Example API:
- `Hugeicons.home01.image`
- `Hugeicons.arrowDownLeft.resourceName`

Package layout (implemented):
- `Sources/Hugeicons`, `Sources/Hugeicons/Resources/Hugeicons`, `Scripts/icons`, and `swiftgen.yml`.

## Versioning and reproducibility
- Pin upstream source version in a tracked file:
  - `version.lock`
- Track manifest checksums to detect silent upstream changes.
- Regeneration should be deterministic and stable across machines.

## Licensing and compliance
- Include license provenance file:
  - `THIRD_PARTY_HUGEICONS.md`
- Store:
  - source URL
  - pinned package version
  - retrieval date
  - license/terms summary for free tier

Hard guardrail:
- Never import Pro assets into this tree.

## CI / local validation checks
When implemented, these checks should pass:
- fetch script exits successfully
- verify script reports valid SVG set + manifest
- SwiftGen generation succeeds
- Debug build succeeds

## Risks and mitigations
- **Name churn upstream** -> stable `name-map.json` + deprecation aliases in wrapper.
- **Large diff noise** -> deterministic ordering + normalized file formatting.
- **App size growth** -> optionally split only-used subset later, but start with full free set for discoverability.
- **Swift compile time** -> keep generated API flat and machine-only; avoid heavy generic wrappers.

## First concrete delivery slice
1. Add scripts + version pin.
2. Import one small category subset as proof of pipeline.
3. Generate SwiftGen output and wrapper API.
4. Wire 2-3 icons in one SwiftUI view to validate runtime loading.
5. Expand to full free set after pipeline is stable.

This de-risks tooling before committing 4,600+ assets.
