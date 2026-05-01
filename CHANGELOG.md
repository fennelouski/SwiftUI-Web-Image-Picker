# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `DiscoveredImageSort.faceCountDescending` / `faceCountAscending`: optional ranking by on-device face count (Vision `VNDetectFaceRectanglesRequest`), with `WebImagePickerConfiguration.maximumFaceCountAnalysisImages` to cap work per page. ([#44](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/issues/44))

### Changed

- **Default `selectionLimit`** is now **`1`** (single-tap pick). Multi-select requires setting `selectionLimit` to a value greater than `1`. ([#43](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/issues/43))

### Fixed

### Removed
