# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
