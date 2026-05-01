# Privacy manifests (`PrivacyInfo.xcprivacy`) and distribution

This document explains how **SwiftUI Web Image Picker** relates to Apple’s **privacy manifest** requirements, and what maintainers should do when the project moves from **source-only SwiftPM** to **binary** distribution (for example an **XCFramework**).

## Current distribution (Swift Package, source)

The library is consumed as **source** through Swift Package Manager. In that model:

- Xcode builds the package into the host app; there is **no separate precompiled SDK bundle** from this repository that must carry its own `PrivacyInfo.xcprivacy` today.
- **App developers** remain responsible for their app’s **App Store privacy questionnaire**, **nutrition labels**, and any **privacy manifests** their **own** code or **other** binary dependencies require.

The package **does** use platform capabilities that have privacy implications for **end-user apps**:

- **Outbound network access** — fetches HTML and image bytes (for example via `URLSession`-style APIs in Foundation).
- **`WKWebView`** (optional **`.webView`** extraction mode) — loads and executes web content in WebKit; behavior follows WebKit and the hosting app’s entitlements / App Sandbox settings.

Those capabilities affect **your app’s** disclosures and policies; they do not by themselves force this repo to ship a manifest **until** we distribute the library as a **binary** product that must include one.

## When a `PrivacyInfo.xcprivacy` is required

Apple expects a privacy manifest on **third-party SDKs distributed as binaries** (and updates the list of affected APIs and SDK types over time). If this project publishes an **XCFramework** or other **precompiled** artifact meant to be embedded in apps, that artifact should include a **`PrivacyInfo.xcprivacy`** that accurately reflects:

- **`NSPrivacyAccessedAPITypes`** — any [**Required Reason APIs**](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api) used directly or indirectly by the shipped binary.
- **`NSPrivacyCollectedDataTypes`** — data collected from users (if applicable), per Apple’s taxonomy.
- **`NSPrivacyTracking`** and related tracking domains — only if the library engages in tracking as Apple defines it.

**WebImagePicker today** does not use common “required reason” surface areas such as `UserDefaults`, file timestamp APIs, or disk space APIs in its own sources; a future audit should repeat this check before any binary release, because dependencies or refactors can change the picture.

## Future binary / XCFramework packaging

Before tagging a release that includes **binary** artifacts:

1. **Regenerate an API audit** — search the package and its **linked** dependencies for Required Reason APIs and for any new data collection.
2. **Author `PrivacyInfo.xcprivacy`** — place it so it is **copied into the XCFramework bundle** (or equivalent) following Apple’s layout rules for that product type.
3. **Validate in a sample app** — archive and run through App Store Connect validation or Xcode’s privacy report to catch missing declarations.
4. **Document the manifest** in release notes so integrators know which version introduced or changed privacy metadata.

Until binary distribution exists, this repository may **omit** the file while still meeting Apple’s expectations for **source-only** SPM consumers.

## Maintainer release checklist (privacy)

Use this before any release that changes distribution format, linked system APIs, or data handling:

- [ ] Confirm distribution model for the release (**source SPM only** vs **binary / XCFramework** included).
- [ ] If **binary** is included: `PrivacyInfo.xcprivacy` is present, accurate, and bundled in the artifact.
- [ ] Re-run a Required Reason API / collection audit on **this package’s** sources (and note dependency behavior if statically linked into the binary).
- [ ] Update this document if new modes (for example new extraction backends) change privacy-relevant behavior.

For general contribution and testing expectations, see [CONTRIBUTING.md](../CONTRIBUTING.md).
