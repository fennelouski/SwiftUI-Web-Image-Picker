# SwiftUI Web Image Picker

A Swift Package that brings **web pages into an image-picking flow** similar to the system photo library: users paste or type a URL, the package loads the page’s HTML, discovers image URLs, and presents them in a **masonry-style** grid for single or multi-select. Selected images are returned as **`Data`** with metadata, with helpers to build **`UIImage`** / **`NSImage`** on Apple platforms.

Use it when you want users to pull images from the web without leaving your app or juggling Safari and the clipboard.

## Quick try (~5 minutes)

**Start here:** the repo ships a small SwiftUI app that links **WebImagePicker** locally so you can learn the flow without wiring SPM into your own project first.

1. **Clone** — `git clone https://github.com/fennelouski/SwiftUI-Web-Image-Picker.git` and `cd` into the folder.
2. **Open** — **`SwiftUI Web Image Picker.xcodeproj`** in Xcode.
3. **Scheme** — choose **SwiftUI Web Image Picker** in the scheme picker next to Run/Stop.
4. **Destination** — an **iOS Simulator**, **My Mac**, or a **visionOS** simulator (the demo is multiplatform).
5. **Signing** — if Xcode complains, select the app target → **Signing & Capabilities** → enable **Automatically manage signing** and pick a **Team** (Personal Team is fine for local runs). See **[CONTRIBUTING.md](CONTRIBUTING.md#code-signing-demo-target)**—do not commit team IDs.
6. **Run** — **Product → Run** (⌘R). Tap **Pick from web** and type a URL, or open **Try a sample page** for a pre-filled HTTPS URL, then **Load page**, select thumbnails, and **Done**.

When you are ready to integrate, follow **[Installation](#installation)** and **[Quick start](#quick-start)** below.

## Features

- **Photos-like sheet** — Navigation stack with Cancel, Done (multi-select), and “Change URL” while browsing.
- **URL entry first** — Text field with URL-friendly keyboard options where supported; loads the page on demand. Bare hosts (e.g. `example.com/path`) are **best-effort normalized** by prepending an allowed scheme (`https` preferred, then `http`, then other schemes in `allowedURLSchemes`). Users can still type an explicit `http://` URL when `http` is allowed.
- **Static HTML extraction** — Collects `<img>`, `srcset`, `<picture>` sources, Open Graph, Twitter card images, and **`url(...)` targets** from inline `style` attributes plus `<style>` blocks for `background-image` / `background` declarations; resolves relative URLs and deduplicates.
- **WebView extraction mode** — Optional `WKWebView`-based discovery for JavaScript-rendered pages.
- **Masonry layout** — Custom SwiftUI `Layout` with staggered columns (column count adapts by platform / size class).
- **Configurable** — Selection limit, timeouts, size caps, allowed URL schemes, user agent, and extraction mode (extensible for future strategies).
- **Cross-platform** — iOS, macOS, visionOS, and tvOS (see [Requirements](#requirements)).

## Requirements

- Swift 5.9+
- Deployment targets as declared in the package: **iOS 17**, **macOS 14**, **visionOS 1**, **tvOS 17**
- Network access where you fetch pages and images (e.g. macOS App Sandbox: **Outgoing Connections (Client)**)

## Installation

Library sources live under **`Packages/WebImagePicker/`**. SwiftPM manifests exist at the **repository root** (`Package.swift`, for URL-based dependencies) and under **`Packages/WebImagePicker/Package.swift`** (for path dependencies that point only at the package folder).

For **exact, step-by-step integration** (including SPM path rules, Xcode, entitlements, and verification), see **[AI_INTEGRATION.md](AI_INTEGRATION.md)**.

### Swift Package Manager

**Repository:** [github.com/fennelouski/SwiftUI-Web-Image-Picker](https://github.com/fennelouski/SwiftUI-Web-Image-Picker)

**URL-based (recommended for most apps):** depend on the repo root and a [SemVer tag](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/tags) (e.g. `1.0.0`):

```swift
dependencies: [
    .package(name: "WebImagePicker", url: "https://github.com/fennelouski/SwiftUI-Web-Image-Picker.git", from: "1.0.0"),
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

**Path dependency** (monorepo, submodule, or vendored clone — adjust paths to your layout):

```swift
// Repo root (same manifest URL-based consumers use)
.package(name: "WebImagePicker", path: "./vendor/SwiftUI-Web-Image-Picker"),

// Or only the package subtree (uses Packages/WebImagePicker/Package.swift)
.package(name: "WebImagePicker", path: "./vendor/SwiftUI-Web-Image-Picker/Packages/WebImagePicker"),
```

### Xcode (local clone)

1. **File → Add Package Dependencies…**
2. Choose **Add Local…** and select the **repository root** (recommended, matches URL-based resolution) or the **`Packages/WebImagePicker`** folder.
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

The default **`selectionLimit`** is **`1`**: one tap downloads and completes the pick (no separate Done step). Set **`selectionLimit`** to a value greater than `1` for multi-select with a Done button.

```swift
var config = WebImagePickerConfiguration(
    maximumConcurrentImageLoads: 4,
    requestTimeout: 30,
    allowedURLSchemes: ["https"],
    userAgent: nil,
    maximumHTMLDownloadBytes: 2_000_000,
    maximumImageDownloadBytes: 25_000_000,
    extractionMode: .staticHTML // or .webView for JS-rendered pages
)

.webImagePicker(isPresented: $showPicker, configuration: config) { selections in
    // ...
}
```

For example, **`selectionLimit: 10`** allows up to ten images before the user taps Done.

**`maximumDiscoveredImagesPerPage`** — Optional cap on how many image candidates are kept from **each** loaded page after discovery (default `nil` = unlimited). Truncation keeps the first N URLs in extractor order. For **`.staticHTML`**, that order is: `<img>` / `srcset` and `<picture>` sources in DOM order, then Open Graph and Twitter image tags, then `url(...)` values from inline `style` attributes and `<style>` blocks. In **multi-URL** mode (primary field + `additionalPageURLs` + extra rows), the limit applies **per page** before results are merged and de-duplicated across pages.

### Localization

UI strings and errors load from **`Localizable.strings`** under `Packages/WebImagePicker/Sources/WebImagePicker/Resources/` (e.g. `en.lproj`, `es.lproj`). The picker follows the user’s preferred language when a matching localization exists. To add or adjust translations, edit those files in the package and ship an updated dependency revision.

## How it works

1. **Fetch** — The active **`PageImageExtractor`** either downloads and parses raw HTML (**`.staticHTML`**, default, using [SwiftSoup](https://github.com/scinfu/SwiftSoup)) or loads the page in **`WKWebView`** (**`.webView`**) before collecting image candidates from the rendered DOM.
2. **Discover** — Image candidates are parsed from the markup, normalized to absolute URLs, filtered by allowed schemes, and deduplicated. If **`maximumDiscoveredImagesPerPage`** is set, each page’s list is truncated to that many candidates (in discovery order) before the grid is shown.

**Static HTML — what is included:** `<img>` / `srcset`, `<picture>` `<source>`, Open Graph and Twitter image meta tags, and CSS `url(...)` strings taken from (1) any inline `style` attribute and (2) `background-image` / `background` values inside `<style>` elements.

**Static HTML — what is excluded (by design):** **`data:` URLs** (including `data:image/svg+xml`, …) are dropped so extraction stays bounded and avoids inlining huge payloads. **Same-document references** (`url(#id)`) are ignored because they do not name a network image. **Inline `<svg>` markup** is not traversed for nested raster `<image>` references in static mode (use **`.webView`** if you need the live DOM). External `.svg` files linked like any other `https` URL remain eligible when the scheme is allowed. Stylesheets loaded only via `<link rel="stylesheet">` are not fetched or parsed in static mode.
3. **Present** — **`AsyncImage`** loads thumbnails in a **`MasonryLayout`**; the user selects one or more items (subject to the limit). While browsing, the search field matches **alt text**, optional **`title`**, and the image **URL** (case-insensitive). You can narrow by file type using tokens **`format:<extension>`** (for example `format:png`, `format:webp`, `format:jpeg`). Tokens are **case-insensitive**, can appear anywhere in the query (with or without other search words), and multiple `format:` tokens combine with **OR**. Unknown extensions after `format:` match nothing. When **`allowedImageTypeIdentifiers`** is set, format filters only show types that are both requested and allowed by that allowlist (the same rules as discovery).
4. **Deliver** — On Done (or single-tap when limit is 1), selected URLs are downloaded in bounded concurrency into **`WebImageSelection`** values.

Use **`.staticHTML`** for fastest extraction on server-rendered pages. Use **`.webView`** when content is injected by JavaScript and missing from initial HTML.

`WKWebView` mode considerations:
- Runs WebKit work on the main actor and can use more memory/CPU than static parsing.
- Subject to platform sandbox/network policy (for example, App Sandbox outgoing network permission on macOS).
- Embedded/isolated content (cross-origin iframes, blocked resources, CSP constraints) may still limit what becomes discoverable.

## API reference (DocC)

The Swift package ships a **DocC** catalog for the public API:

- **Location:** [`Packages/WebImagePicker/Sources/WebImagePicker/WebImagePicker.docc/`](Packages/WebImagePicker/Sources/WebImagePicker/WebImagePicker.docc/)

**Browse in Xcode:** open `SwiftUI Web Image Picker.xcodeproj` or add the package, then choose **Product → Build Documentation** and open the **WebImagePicker** documentation in the Documentation navigator. Entry points include `WebImagePicker`, the `webImagePicker` view modifier, `WebImagePickerConfiguration`, and `WebImageSelection`.

## Development

From the **repository root** (canonical for CI and URL-based SPM):

```bash
swift build
swift test
```

Or from the nested package directory (equivalent manifest):

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

## Privacy and `PrivacyInfo.xcprivacy`

This package loads remote HTML and images over the network and can use **`WKWebView`** when you enable **`.webView`** extraction. Your app is responsible for App Store privacy labels and for any privacy manifests required by **your** code and **binary** dependencies.

If we ship **precompiled** binaries (for example an XCFramework), those artifacts will need an accurate **`PrivacyInfo.xcprivacy`** per Apple’s rules. Source-only SwiftPM consumption today does not add a manifest file in-repo; see **[docs/PRIVACY_MANIFEST.md](docs/PRIVACY_MANIFEST.md)** for policy detail and a **maintainer release checklist**.
