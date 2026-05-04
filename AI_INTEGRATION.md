# AI / automation guide: integrating **WebImagePicker**

This document is written for **AI coding agents** and **scripted tooling**. Follow it literally. All paths below are relative to a **clone of this repository** unless stated otherwise.

## What you are integrating

- **Product (library) name:** `WebImagePicker` (SwiftPM product and `import WebImagePicker`).
- **Package manifests in this repo:**
  - **Repository root** `Package.swift` — use with **remote** `.package(url:)` (SemVer tags on the default branch).
  - **`Packages/WebImagePicker/Package.swift`** — same products/targets; use when the host’s path dependency points **only** at the `WebImagePicker` package folder.
  Keep dependency versions and platforms aligned between the two manifests.
- **Transitive dependency:** [SwiftSoup](https://github.com/scinfu/SwiftSoup) (declared in those manifests). Do not add SwiftSoup manually unless you have a conflict to resolve.
- **License:** MPL-2.0 — preserve notices; see [LICENSE](LICENSE).

## Preconditions (verify before editing)

1. **Host app deployment target** must be at least: **iOS 17**, **macOS 14**, **visionOS 1**, **tvOS 17** (see `platforms` in the root `Package.swift` or `Packages/WebImagePicker/Package.swift`).
2. **Swift** toolchain compatible with `// swift-tools-version: 5.9` in those manifests.
3. **Network:** The feature loads HTML and image bytes over HTTP(S). Ensure the host process may open outbound connections:
   - **macOS App Sandbox:** entitlement **`com.apple.security.network.client`** = `true` (boolean).
   - **iOS / others:** Usually sufficient for HTTPS; no extra WebImagePicker-specific plist keys required for default ATS.

## Monorepo fact (critical for SPM path)

This repository has **`Package.swift` at the git root** and a second copy at **`Packages/WebImagePicker/Package.swift`** (same library product).

- **Remote `.package(url:)`** resolves the **root** manifest after checkout.
- **Path dependencies** may point at either the **repository root** or **`Packages/WebImagePicker`**, depending on what you vendored; the path must be the directory that contains the **`Package.swift` you intend to use** for that dependency.

If the consumer only vendors the library subtree, the path is whatever folder contains **that** `Package.swift` (often `./WebImagePicker` or `./Packages/WebImagePicker` after copy).

---

## Integration method A — Swift Package Manager (`Package.swift` of the host)

**Goal:** Add a dependency on **WebImagePicker**, then link the product **`WebImagePicker`**.

### A1. Remote Git URL (preferred for published consumers)

**Repository:** **https://github.com/fennelouski/SwiftUI-Web-Image-Picker**

Use a **version requirement** that matches a **tag** on the default branch (e.g. `from: "1.1.0"`).

```swift
.package(
    name: "WebImagePicker",
    url: "https://github.com/fennelouski/SwiftUI-Web-Image-Picker.git",
    from: "1.1.0"
),
```

```swift
.product(name: "WebImagePicker", package: "WebImagePicker"),
```

### A2. Same machine / monorepo / vendored folder (path)

Use a **path** dependency. The path is **relative to the host package’s `Package.swift` location**.

Example — depend on the **clone root** (same layout remote consumers get):

```swift
.package(name: "WebImagePicker", path: "../SwiftUI-Web-Image-Picker"), // adjust
```

Example — depend on **only** the package folder (uses `Packages/WebImagePicker/Package.swift`):

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HostApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HostApp", targets: ["HostApp"]),
    ],
    dependencies: [
        .package(name: "WebImagePicker", path: "Packages/WebImagePicker"),
    ],
    targets: [
        .target(
            name: "HostApp",
            dependencies: [
                .product(name: "WebImagePicker", package: "WebImagePicker"),
            ]
        ),
    ]
)
```

**Naming rule:** The string `package: "WebImagePicker"` in `.product(...)` must match the **`name:`** in `.package(...)`. If you omit `name:` on `.package(path:)`, SwiftPM infers a name from the path (often the last path component). To avoid ambiguity, prefer an explicit `name:` as above.

---

## Integration method B — Xcode (GUI)

Use when the host is an **`.xcodeproj`** / **`.xcworkspace`** app, not necessarily an SPM-only package.

1. Open the host project in Xcode.
2. **File → Add Package Dependencies…**
3. For a **remote** dependency: enter **https://github.com/fennelouski/SwiftUI-Web-Image-Picker.git** and a **version rule** (e.g. **Up to Next Major** from **1.1.0**, or **1.0.0** if you want any compatible **1.x**).
4. For **Add Local…**: select the **repository root** (recommended; uses root `Package.swift`) or **`Packages/WebImagePicker`**.
5. Add the product **`WebImagePicker`** to the **application** target (or the framework target that needs the UI).
6. **macOS:** Enable **App Sandbox** → check **Outgoing Connections (Client)** (maps to `com.apple.security.network.client`).
7. Build. Fix **deployment target** if Xcode warns; raise to iOS 17 / macOS 14 / etc.

### Xcode project file (automation hint)

If generating or patching `project.pbxproj`, a local package reference typically looks like:

- `XCLocalSwiftPackageReference` with `relativePath = .;` **when the `.xcodeproj` sits next to the root `Package.swift`** (this repo’s demo), or `relativePath = Packages/WebImagePicker;` when linking only the nested manifest — paths are **relative to the `.xcodeproj`’s parent directory**.
- `XCSwiftPackageProductDependency` with `productName = WebImagePicker;` linked to that reference.

Do **not** set `relativePath = ..` unless `Package.swift` truly lives one level above the `.xcodeproj`.

---

## Minimal SwiftUI usage (required API)

1. `import WebImagePicker` in any file that shows the UI.
2. Hold presentation state, e.g. `@State private var showPicker = false`.
3. Present with either:

### Option 1 — Convenience modifier (sheet + auto-dismiss on success)

```swift
import SwiftUI
import WebImagePicker

struct ExampleView: View {
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

The modifier calls `onPick` then sets `isPresented` to `false`.

### Option 2 — Full control (`WebImagePicker` inside your own `sheet`)

```swift
.sheet(isPresented: $showPicker) {
    WebImagePicker(
        configuration: .default,
        onCancel: { showPicker = false },
        onPick: { selections in
            // handle selections; dismiss yourself if needed
            showPicker = false
        }
    )
}
```

## Configuration (optional but explicit)

Use **`WebImagePickerConfiguration`** when calling `.webImagePicker(..., configuration:onPick:)` or `WebImagePicker(configuration:onCancel:onPick:)`.

### `WebImageExtractionMode`

Public enum (defined next to **`WebImagePickerConfiguration`** in `WebImagePickerConfiguration.swift`). Additional cases may be added without breaking the public API.

- **`.staticHTML`** — Parse the raw HTML response; **no JavaScript execution**. Best default for server-rendered pages; uses SwiftSoup-based discovery.
- **`.webView`** — Load the page in **`WKWebView`** and collect image URLs from the live DOM **after** scripts run. Use for client-rendered pages where images are injected at runtime. Higher memory/runtime cost than `.staticHTML`; WebKit work runs on the main actor and is subject to sandbox/network policy, CSP, and cross-origin or iframe limits.

Default is **`.staticHTML`**. On your configuration, **`configuration.extractionMode.makeExtractor()`** returns the active **`PageImageExtractor`**: **`StaticHTMLExtractor`** or **`WebViewPageImageExtractor`**.

### `WebImagePickerConfiguration` properties

#### Network, limits, and extraction

| Property | Role |
|----------|------|
| `selectionLimit` | Max images the user may select; **`1`** = single-select (tap downloads and completes immediately). |
| `maximumConcurrentImageLoads` | Parallel image downloads when confirming a multi-select (minimum `1` after init clamping). |
| `requestTimeout` | Per-request timeout for HTML and image fetches. |
| `allowedURLSchemes` | Schemes allowed for **both** page URLs and discovered image URLs; default **`["https"]`**. |
| `userAgent` | Optional `User-Agent` for HTML and image requests. |
| `maximumHTMLDownloadBytes` | Upper bound on HTML response size. |
| `maximumImageDownloadBytes` | Upper bound on each image response. |
| `extractionMode` | **`WebImageExtractionMode`**; see above. |
| `urlSession` | **`URLSession`** for HTML fetches and image downloads; default **`URLSession.shared`**. Intentionally excluded from `Equatable` / `Hashable` on the configuration struct. |

#### Multi-page and discovery

| Property | Role |
|----------|------|
| `initialURLString` | Optional text pre-filled in the URL field when the picker appears (whitespace trimmed); `nil` or empty = blank field. |
| `additionalPageURLs` | Extra page URLs to load in order and merge into one grid (with deduplication); host can pre-seed several pages. |
| `maximumDiscoveredImagesPerPage` | Optional cap on candidates **per page** after deduplication and **`discoveredImageSort`**; `nil` = unlimited. Applies per page in multi-URL mode before cross-page merge. |
| `discoveredImageSort` | Order applied per page before the per-page cap (default preserves extractor order). |
| `similarImageDeduplication` | How aggressively to collapse URLs that may name the same asset (e.g. cache-busting query pairs). |

#### Dimensions, types, and selection output

| Property | Role |
|----------|------|
| `minimumImageDimensions` | Optional minimum pixel width/height; `<= 0` on an axis means no minimum there. Uses ranged GET probes; applied after sort and before **`maximumDiscoveredImagesPerPage`**. |
| `maximumImageDimensions` | Optional maximum pixel width/height; same axis rule as minimum. |
| `allowedImageTypeIdentifiers` | Optional `UTType` identifier allowlist (e.g. JPEG id); `nil` or empty disables type filtering at discovery/download. |
| `unknownImageTypePolicy` | When the allowlist is active, how to treat types that cannot be inferred from URL or `Content-Type`. |
| `selectionOutputMode` | Whether **`WebImageSelection`** is filled with **`data`** only (default), or a **`temporaryFileURL`** with typically empty **`data`**. |

#### Vision (faces, in-image text)

| Property | Role |
|----------|------|
| `maximumFaceCountAnalysisImages` | When using face-count sort orders, max images **per page** (in discovery order) to analyze with on-device Vision; `0` skips face-based reordering. |
| `isImageTextSearchEnabled` | When `true`, runs **`VNRecognizeTextRequest`** on up to **`maximumImageTextSearchImages`** discovered URLs so the browsing search can match text inside rasters. Off by default (privacy/performance). |
| `maximumImageTextSearchImages` | Cap on OCR’d images when **`isImageTextSearchEnabled`** is `true`; `0` skips OCR. |
| `imageTextRecognitionLanguages` | Optional BCP-47 tags for Vision (e.g. `"en-US"`); `nil`/empty uses Vision defaults. |
| `maximumConcurrentImageTextRecognition` | Parallelism for ranged GET + Vision while building the in-image text index (minimum `1` after init clamping). |

#### Metadata blocklist

| Property | Role |
|----------|------|
| `excludedImageMetadataSubstrings` | Case-insensitive substrings; images matching **any** entry on URL, path, alt, `title`, or OCR text (when indexed) are hidden before the user’s search filter. |
| `excludedImageMetadataRegularExpressionPatterns` | **`NSRegularExpression`** patterns (case-insensitive) against the same haystacks; invalid patterns ignored—keep the list short for CPU cost. |

Defaults: see `WebImagePickerConfiguration.init` in `Packages/WebImagePicker/Sources/WebImagePicker/WebImagePickerConfiguration.swift`.

## Using the result (`WebImageSelection`)

Each selection includes:

- `data: Data` — raw bytes (often empty when **`selectionOutputMode`** is **`.temporaryFileURL`**)  
- `contentType: String?` — MIME type when available  
- `sourceURL: URL` — absolute URL of the downloaded image  
- `temporaryFileURL: URL?` — when **`selectionOutputMode`** is **`.temporaryFileURL`**, path in the temp directory; platform image helpers read from the file. Copy or move soon; the file may be removed by the system.

Platform helpers (import still `WebImagePicker`):

- **iOS / tvOS / visionOS:** `selection.makeUIImage() -> UIImage?`
- **macOS:** `selection.makeNSImage() -> NSImage?`

## Localization

- **Tables:** `Packages/WebImagePicker/Sources/WebImagePicker/Resources/<locale>.lproj/Localizable.strings` (keys prefixed with `webimage.`). The package declares `defaultLocalization: "en"` and ships **English** plus **Spanish** as reference locales.
- **Runtime:** Strings resolve from **WebImagePicker’s resource bundle** (`Bundle.module` inside the library). The host app does not need to copy those files; system language / locale drives which translation loads when available.
- **Contributors:** Add locales by adding a new `.lproj` folder with `Localizable.strings` (or extending an existing one) and submitting a PR. For one-off custom copy, wrap or fork the UI; there is no public string-replacement API.

## Behavioral constraints (tell the user / product owner)

1. **Extraction mode:** With default **`.staticHTML`**, images that exist only after JavaScript runs may be **missing** (common on SPAs). Set **`extractionMode`** to **`.webView`** to discover from the rendered DOM via **`WKWebView`**. Expect higher resource use than static parsing; your app may need accurate App Store privacy disclosures and manifest consideration when enabling WebKit-backed flows (see README “Privacy and `PrivacyInfo.xcprivacy`”).
2. **HTTPS-only by default:** `http` pages/images are rejected unless `allowedURLSchemes` includes `"http"`.
3. **Bare domains in the URL field:** If the user omits a scheme (e.g. `example.com/article`), the picker **prepends a scheme** when possible: **`https://`** first if allowed, then **`http://`**, then other entries in `allowedURLSchemes`. This is **best-effort** (invalid hosts still fail); users should use an explicit `http://` or `https://` when they need a specific scheme.
4. **Errors** surface as user-visible strings in the picker UI; thrown errors use **`WebImagePickerError`** for programmatic handling in your own wrappers.

## Verification checklist (agent should confirm)

- [ ] Host target links SPM product **`WebImagePicker`** (not only SwiftSoup).
- [ ] `import WebImagePicker` compiles.
- [ ] Deployment targets ≥ package minimums.
- [ ] macOS sandbox **Outgoing Connections** enabled if sandboxed.
- [ ] Path dependency points at the directory whose **`Package.swift`** you intend to use (**repository root** or **`Packages/WebImagePicker`**); remote URL dependencies use the root manifest automatically.
- [ ] Run app: open picker, load a known-good **HTTPS** page and confirm grid and selection callback (for example a page with `<img>` tags using default **`.staticHTML`**, or a JavaScript-rendered gallery with **`extractionMode: .webView`**).

## Reference implementation in this repo

- Demo app: **`SwiftUI Web Image Picker/`** (sources) + **`SwiftUI Web Image Picker.xcodeproj`** — see `ContentView.swift` for `webImagePicker` usage.
- Library sources: **`Packages/WebImagePicker/Sources/WebImagePicker/`**

## Running library tests (sanity)

From **repository root**:

```bash
swift test
```

Or from the nested package directory:

```bash
cd Packages/WebImagePicker && swift test
```

---

*End of integration spec.*
