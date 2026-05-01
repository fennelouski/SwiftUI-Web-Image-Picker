# SwiftUI Web Image Picker

A Swift Package that brings **web pages into an image-picking flow** similar to the system photo library: users paste or type a URL, the package loads the page’s HTML, discovers image URLs, and presents them in a **masonry-style** grid for single or multi-select. Selected images are returned as **`Data`** with metadata, with helpers to build **`UIImage`** / **`NSImage`** on Apple platforms.

Use it when you want users to pull images from the web without leaving your app or juggling Safari and the clipboard.

## Features

- **Photos-like sheet** — Navigation stack with Cancel, Done (multi-select), and “Change URL” while browsing.
- **URL entry first** — Text field with URL-friendly keyboard options where supported; loads the page on demand.
- **Static HTML extraction** — Collects `<img>`, `srcset`, `<picture>` sources, Open Graph, and Twitter card images; resolves relative URLs and deduplicates.
- **Masonry layout** — Custom SwiftUI `Layout` with staggered columns (column count adapts by platform / size class).
- **Configurable** — Selection limit, timeouts, size caps, allowed URL schemes, user agent, and extraction mode (extensible for future strategies).
- **Cross-platform** — iOS, macOS, visionOS, and tvOS (see [Requirements](#requirements)).

## Requirements

- Swift 5.9+
- Deployment targets as declared in the package: **iOS 17**, **macOS 14**, **visionOS 1**, **tvOS 17**
- Network access where you fetch pages and images (e.g. macOS App Sandbox: **Outgoing Connections (Client)**)

## Installation

The Swift package lives under **`Packages/WebImagePicker/`** in this repository.

For **exact, step-by-step integration** (including SPM path rules, Xcode, entitlements, and verification), see **[AI_INTEGRATION.md](AI_INTEGRATION.md)**.

### Swift Package Manager

**Repository:** [github.com/fennelouski/SwiftUI-Web-Image-Picker](https://github.com/fennelouski/SwiftUI-Web-Image-Picker)

The Swift manifest is under **`Packages/WebImagePicker/`**, not the git root, so **`package(url:)` does not work yet** for this layout. Use a **path** dependency (clone or submodule) or **Add Local…** in Xcode until a root `Package.swift` (and version tags) is published for URL-based SPM.

Path dependency (adjust the path to where you cloned the repo):

```swift
dependencies: [
    .package(name: "WebImagePicker", path: "./vendor/SwiftUI-Web-Image-Picker/Packages/WebImagePicker"),
]
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "WebImagePicker", package: "WebImagePicker"),
    ]
),
```

**Future (URL-based):** After `Package.swift` exists at the repository root and you tag releases, you will be able to use:

```swift
.package(name: "WebImagePicker", url: "https://github.com/fennelouski/SwiftUI-Web-Image-Picker.git", from: "1.0.0"),
```

If the package manifest is not at the repository root, use a **path** dependency in Xcode or in `Package.swift`:

```swift
.package(path: "Packages/WebImagePicker")  // relative to your project/repo root
```

### Xcode (local clone)

1. **File → Add Package Dependencies…**
2. Choose **Add Local…** and select the `Packages/WebImagePicker` folder (or the repo root if you add a root `Package.swift` later).
3. Add the **WebImagePicker** product to your app target.

## Quick start

```swift
import SwiftUI
import WebImagePicker

struct ContentView: View {
    @State private var showPicker = false
    @State private var selections: [WebImageSelection] = []

    var body: some View {
        Button("Pick from web") { showPicker = true }
            .webImagePicker(isPresented: $showPicker) { newSelections in
                selections = newSelections
            }
    }
}
```

The modifier presents **`WebImagePicker`** in a sheet and dismisses it after a successful pick. For full control (e.g. custom dismissal), use **`WebImagePicker`** directly and pass `onCancel` / `onPick` closures.

### Using the selection

```swift
// Raw bytes and type
let data = selection.data
let mime = selection.contentType
let url = selection.sourceURL

#if os(iOS) || os(tvOS) || os(visionOS)
let uiImage = selection.makeUIImage()
#elseif os(macOS)
let nsImage = selection.makeNSImage()
#endif
```

### Configuration

```swift
var config = WebImagePickerConfiguration(
    selectionLimit: 5,
    maximumConcurrentImageLoads: 4,
    requestTimeout: 30,
    allowedURLSchemes: ["https"],
    userAgent: nil,
    maximumHTMLDownloadBytes: 2_000_000,
    maximumImageDownloadBytes: 25_000_000,
    extractionMode: .staticHTML
)

.webImagePicker(isPresented: $showPicker, configuration: config) { selections in
    // ...
}
```

With **`selectionLimit == 1`**, tapping an image downloads it immediately and completes the pick (no separate Done step).

## How it works

1. **Fetch** — The active **`PageImageExtractor`** downloads the HTML document (with a byte limit and timeout). Default mode is **`.staticHTML`** (**`StaticHTMLExtractor`**), backed by [SwiftSoup](https://github.com/scinfu/SwiftSoup).
2. **Discover** — Image candidates are parsed from the markup, normalized to absolute URLs, filtered by allowed schemes, and deduplicated.
3. **Present** — **`AsyncImage`** loads thumbnails in a **`MasonryLayout`**; the user selects one or more items (subject to the limit).
4. **Deliver** — On Done (or single-tap when limit is 1), selected URLs are downloaded in bounded concurrency into **`WebImageSelection`** values.

**JavaScript-rendered pages** may not expose images in the initial HTML; only server-rendered (or statically embedded) images are found today. The **`PageImageExtractor`** / **`WebImageExtractionMode`** design is intended to allow a future WebKit-based extractor without breaking callers.

## Demo app

This repository includes a small **SwiftUI** demo target (**SwiftUI Web Image Picker**) that links the local package and shows selected images. Open **`SwiftUI Web Image Picker.xcodeproj`** in Xcode and run the scheme on your chosen destination.

## Development

From the package directory:

```bash
cd Packages/WebImagePicker
swift build
swift test
```

Unit tests cover HTML parsing and URL resolution using bundled fixtures (no network in CI by default).

## License

This project is licensed under the **Mozilla Public License 2.0** — see [LICENSE](LICENSE). You must preserve copyright and license notices; if you distribute **modified** versions of the **covered source files**, those modifications must be made available under MPL-2.0 as described in the license.

## Security and fair use

- Users supply URLs; treat untrusted input like any other network feature in your threat model.
- Only fetch and display content your users are allowed to access; respect site terms and copyright.
