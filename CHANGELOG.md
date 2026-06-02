# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Smart URL fallback (post-failure)** — optional retry heuristics for likely host/TLD mistakes after a failed first load (for example `google.c` -> `google.com`), configurable via `isSmartURLFallbackEnabled`, `maximumSmartURLFallbackAttempts`, and `smartURLFallbackTLDStrategy`.

## [1.4.0] — 2026-05-31

### Added

- **Tile context menu (long-press)** — Opt-in `WebImageTileContextMenuConfiguration` on `WebImagePickerConfiguration` for copy image, copy URL, cut out subject (iOS/macOS), in-picker preview, and metadata sheets. Clipboard actions can appear as separate menu items or a grouped picker. Documented in README, `AI_INTEGRATION.md`, and DocC (`TileContextMenu` article).
- **Tile context menu localizations** — All bundled `Localizable.strings` locales include menu, sheet, metadata, and error strings for tile actions (see `Scripts/add_tile_localizations.py` and `Scripts/tile_localization_generated.json`).

## [1.3.0] — 2026-05-26

### Added

- **Largest-image promotion** — probes image headers (ranged GET) and promotes the top 10% by pixel area to the front of the browsing grid (`LargestImagePromotion`).
- **WiFi prefetch** — when on a non-expensive network, the picker speculatively fetches image discovery results 1 second after the URL field changes, so tapping "Load" is nearly instant on WiFi.
- **Favicon in toolbar** — the browsing phase shows the page favicon as the navigation title image (falls back to the SF Symbol).
- **Source URL display** — a subtle link caption below the search bar shows the loaded page host/path.
- **Collapsible HTTP-skipped-images warning** — the notice can now be collapsed to a single line; separate release/debug wording hides developer-only advice from end-users.

### Changed

- **Default deduplication strategy** — `similarImageDeduplication` now defaults to `.normalizedResourceURL` instead of `.disabled`.
- **Failed-image tiles** — tiles for images that fail to load are hidden (`EmptyView`) instead of showing a placeholder.

## [1.2.2] — 2026-05-22

### Changed

- **Browsing grid thumbnails** — masonry column count and tile dimensions now scale with the number of displayed images: raised baseline at 40+ images (never smaller than the previous layout), up to 3× today’s size when only a few images are shown.

## [1.2.1] — 2026-05-20

### Changed

- **Localization** — updated and refined `Localizable.strings` translations across all bundled locales.

## [1.2.0] — 2026-05-20

### Added

- **`WebImagePickerConfiguration.isMultiplePageEntryEnabled`** — opt-in multi-page URL entry (extra rows in the picker UI and aggregation of `additionalPageURLs` with the primary URL). Default **`false`**.
- **Expanded picker localizations** — additional `Localizable.strings` bundles for many languages and regional variants (beyond the original `en` / `es` pair).

### Changed

- **Picker chrome** — toolbar, navigation title, form actions, and selection summary use **SF Symbols** with localized accessibility labels instead of localized visible chrome text.

## [1.1.0] — 2026-05-04

First release after [1.0.0](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/releases/tag/1.0.0) with the current package feature set. Full commit range: [`1.0.0...1.1.0`](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/compare/1.0.0...1.1.0).

### Added

- **`WebImagePickerConfiguration.automaticallyLoadOnAppear`** — optional first-appear auto `loadPage()` when a URL is already available (e.g. `initialURLString` / `additionalPageURLs`), with a dedicated loading state in `WebImagePicker`.
- **HTTP/HTTPS scheme policy** for discovery — `DiscoveredImageURLSchemePolicy`, `PageImageDiscoveryOutcome`, and user-visible notices when pages reference disallowed `http:` images on HTTPS-only configs.
- **Multi-URL aggregation** — `additionalPageURLs` and per-page `maximumDiscoveredImagesPerPage`.
- **Discovered image sort** (including per-page order before cap) and **similar-URL deduplication**; **pixel dimension** filters; **UTType** allowlist for image types.
- **Selection output modes** — data-only, validated bitmap, or temporary file.
- **Vision: face-count sort** — `DiscoveredImageSort.faceCountDescending` / `faceCountAscending` and `maximumFaceCountAnalysisImages`. ([#44](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/issues/44))
- **In-image and metadata search** — text search over alt/title/URL; optional Vision OCR for text inside images; metadata blocklist (substring + regex).
- **Pluggable cache policy** — `URLRequest` cache and optional discovered-image LRU/TTL/per-domain memo.
- **DocC** catalog, expanded tests, snapshot tests, **Dependabot** for GitHub Actions.

### Changed

- **Default `selectionLimit`** is now **`1`** (single-tap pick). Set `selectionLimit` to a value greater than `1` for multi-select with Done. ([#43](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/issues/43))
- **Demo** — sample page catalog, onboarding, and localized UI (en + es).

### Fixed

- Browsing UI shows image download errors; static HTML CSS `url(...)` extraction improvements; other fixes as in linked PRs from compare range.

## [1.0.0] — 2026-05-01

- Initial published tag with root `Package.swift` for URL-based SwiftPM. ([#16](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/issues/16))
