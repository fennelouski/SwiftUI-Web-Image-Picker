# Contributing

Thanks for helping improve **SwiftUI Web Image Picker**.

## Quick start

1. **Clone** this repository.
2. **Library tests** (no Xcode signing required):

   ```bash
   cd Packages/WebImagePicker && swift test
   ```

   From the **repository root** (same manifests consumers use for remote SPM):

   ```bash
   swift test
   ```

3. **Demo app** — open **`SwiftUI Web Image Picker.xcodeproj`** in Xcode, choose the **SwiftUI Web Image Picker** scheme, and run on your Mac or a simulator.

### Code signing (demo target)

The Xcode project **does not** pin a `DEVELOPMENT_TEAM`. After opening the project:

1. Select the **SwiftUI Web Image Picker** app target.
2. Open **Signing & Capabilities**.
3. Enable **Automatically manage signing** and choose **Team** (your Apple Developer team, or “Personal Team” for local runs).

Do **not** commit personal team IDs or provisioning changes. If you need persistent local overrides, use an **xcconfig** file that stays **untracked** (e.g. add it to `.git/info/exclude` or your global gitignore), or adjust signing only in your working copy.

## License (MPL-2.0)

This project is under the [Mozilla Public License 2.0](LICENSE).

- Keep **copyright and license notices** on files you touch.
- If you distribute **modified** versions of **covered source files**, those modifications must be made available under MPL-2.0 as described in the license.

## Pull requests

- Keep changes **focused** on one concern when possible.
- Run **`swift test`** (root or `Packages/WebImagePicker`) before opening a PR and note any platform-only checks you could not run.
- Describe **what** changed and **why** in the PR body.

## Release readiness (maintainers)

Before a release—especially one that introduces **binary** artifacts (XCFramework, etc.)—complete the privacy and manifest checklist in **[docs/PRIVACY_MANIFEST.md](docs/PRIVACY_MANIFEST.md)** so `PrivacyInfo.xcprivacy` and distribution expectations stay accurate.

## Questions

Open a [GitHub issue](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/issues) for bugs or design discussion before very large refactors.
