# Tile context menu

Optional long-press and right-click actions on images in the browsing grid.

## Overview

By default, grid tiles only respond to tap (select or toggle). Set ``WebImagePickerConfiguration/imageTileContextMenu`` to a non-disabled ``WebImageTileContextMenuConfiguration`` to add a SwiftUI context menu on each tile.

Tap behavior is unchanged: the menu does not call `onPick`. Actions that need full image bytes use the same download path as selection, respecting ``WebImagePickerConfiguration/maximumImageDownloadBytes`` and ``WebImagePickerConfiguration/urlSession``.

## Enable the menu

```swift
var config = WebImagePickerConfiguration.default
config.imageTileContextMenu = WebImageTileContextMenuConfiguration(
    isEnabled: true,
    actions: [.copyImage, .copyImageURL, .preview, .showMetadata],
    clipboardPresentation: .groupedPicker
)
```

Use ``WebImageTileContextMenuConfiguration/disabled`` (the default on ``WebImagePickerConfiguration``) to preserve tap-only behavior.

## Configuration

### ``WebImageTileContextMenuConfiguration``

| Property | Default | Role |
|----------|---------|------|
| `isEnabled` | `false` | When `false`, no context menu appears regardless of `actions`. |
| `actions` | `[]` | Which commands are available (see below). |
| `clipboardPresentation` | `.separateMenuItems` | How copy / URL / lift actions appear in the menu. |

### ``WebImageTileContextMenuAction``

Option set; combine members with array literal syntax.

| Member | Behavior |
|--------|----------|
| `copyImage` | Download, then copy PNG to the system pasteboard. |
| `copyImageURL` | Copy the discovered URL string (no download). |
| `liftSubject` | Download, isolate the foreground with Vision, copy a transparent PNG. **iOS and macOS only**; not shown on tvOS or visionOS. |
| `preview` | Present an in-picker preview sheet (may fetch full resolution). |
| `showMetadata` | Present a sheet with URL, alt, title, optional OCR text, and probed dimensions. |

``WebImageTileContextMenuAction/clipboardActions`` groups `copyImage`, `copyImageURL`, and `liftSubject` for use with ``WebImageTileClipboardPresentation``.

### ``WebImageTileClipboardPresentation``

| Case | Behavior |
|------|----------|
| `separateMenuItems` | Each enabled clipboard action is its own context-menu row. |
| `groupedPicker` | One **Image Actions** row opens a nested menu with the enabled clipboard actions. |

`preview` and `showMetadata` are always separate top-level rows when enabled.

## Platform notes

- **Interaction:** Long-press on iOS; right-click on macOS. tvOS and visionOS use the platform context-menu affordance when the menu is enabled.
- **Subject lift:** Requires iOS 17+ / macOS 14+ Vision APIs. If ``liftSubject`` is set in `actions` on an unsupported platform, it is stripped from the menu at build time for that platform.
- **Errors:** Download, decode, pasteboard, or lift failures surface in the browsing-phase error banner (same area as pick failures).

## Privacy and networking

Copy image, preview, metadata probes, and subject lift may issue additional HTTP requests beyond thumbnail loading. Document this in your app privacy policy when enabling these actions for untrusted pages.
