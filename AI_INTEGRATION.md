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

Use a **version requirement** that matches a **tag** on the default branch (e.g. `from: "1.0.0"`).

```swift
.package(
    name: "WebImagePicker",
    url: "https://github.com/fennelouski/SwiftUI-Web-Image-Picker.git",
    from: "1.0.0"
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
3. For a **remote** dependency: enter **https://github.com/fennelouski/SwiftUI-Web-Image-Picker.git** and a **version rule** (e.g. **Up to Next Major** from **1.0.0**).
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

| Property | Role |
|----------|------|
| `selectionLimit` | Max images; **`1`** = single-select (tap downloads and completes immediately). |
| `maximumConcurrentImageLoads` | Parallel downloads when confirming multi-select. |
| `requestTimeout` | Per-request timeout (HTML + images). |
| `allowedURLSchemes` | Default **`["https"]`**; page and image URLs must match. |
| `userAgent` | Optional HTTP User-Agent. |
| `maximumHTMLDownloadBytes` | Cap for HTML download. |
| `maximumImageDownloadBytes` | Cap per image. |
| `extractionMode` | Currently **`.staticHTML`** only; selects extractor via `makeExtractor()`. |

Defaults: see `WebImagePickerConfiguration.init` in `Packages/WebImagePicker/Sources/WebImagePicker/WebImagePickerConfiguration.swift`.

## Using the result (`WebImageSelection`)

Each selection includes:

- `data: Data` — raw bytes  
- `contentType: String?` — MIME type when available  
- `sourceURL: URL` — image URL that was fetched  

Platform helpers (import still `WebImagePicker`):

- **iOS / tvOS / visionOS:** `selection.makeUIImage() -> UIImage?`
- **macOS:** `selection.makeNSImage() -> NSImage?`

## Behavioral constraints (tell the user / product owner)

1. **Static HTML only** in v1: images that appear only after JavaScript runs may be **missing**. This is expected for many SPAs.
2. **HTTPS-only by default:** `http` pages/images are rejected unless `allowedURLSchemes` includes `"http"`.
3. **Errors** surface as user-visible strings in the picker UI; thrown errors use **`WebImagePickerError`** for programmatic handling in your own wrappers.

## Verification checklist (agent should confirm)

- [ ] Host target links SPM product **`WebImagePicker`** (not only SwiftSoup).
- [ ] `import WebImagePicker` compiles.
- [ ] Deployment targets ≥ package minimums.
- [ ] macOS sandbox **Outgoing Connections** enabled if sandboxed.
- [ ] Path dependency points at the directory whose **`Package.swift`** you intend to use (**repository root** or **`Packages/WebImagePicker`**); remote URL dependencies use the root manifest automatically.
- [ ] Run app: open picker, enter a known-good **HTTPS** page with `<img>` tags, confirm grid and selection callback.

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
