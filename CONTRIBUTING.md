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

3. **Visual regression (macOS)** — the package includes a small [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) check for the URL-entry screen. Baselines live under `Packages/WebImagePicker/Tests/WebImagePickerTests/__Snapshots__/`. CI runs these on `macos-latest` together with the rest of `swift test`.

   When you intentionally change that UI, refresh the reference image from macOS:

   ```bash
   cd Packages/WebImagePicker
   SNAPSHOT_TESTING_RECORD=all swift test --filter WebImagePickerSnapshotTests
   ```

   The first run will fail with a message that recording finished; run the same command again without `SNAPSHOT_TESTING_RECORD` (or with `SNAPSHOT_TESTING_RECORD=never`) to confirm the new PNG matches. Commit the updated file under `__Snapshots__/`.

   On iOS, tvOS, or visionOS destinations, snapshot tests are skipped (`XCTSkip`) because baselines are macOS PNGs.

4. **Demo app** — open **`SwiftUI Web Image Picker.xcodeproj`** in Xcode, choose the **SwiftUI Web Image Picker** scheme, and run on your Mac, a simulator, or visionOS. Use **Try a sample page** in the demo for pre-filled URLs, or type your own. The root README **Quick try** section is the onboarding path for new contributors.

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

- **Visual changelog** — opening a PR against `main` runs [PR visual changelog](.github/workflows/pr-visual-changelog.yml), which uploads macOS snapshot PNGs and links them in a sticky comment. See **[docs/pr-visual-changelog.md](docs/pr-visual-changelog.md)** for scope (SwiftPM vs. Xcode demo) and how this differs from required CI checks.
- Keep changes **focused** on one concern when possible.
- Run **`swift test`** (root or `Packages/WebImagePicker`) before opening a PR and note any platform-only checks you could not run.
- Describe **what** changed and **why** in the PR body.
- Use the PR template so reviewers get **summary**, **test plan**, and **linked issues**.

## Labels (triage)

Maintainers use labels to sort work. Typical meanings:

| Label | When to use |
| --- | --- |
| `bug` | Incorrect behavior, regression, or spec violation |
| `enhancement` | New capability, API, or meaningful improvement |
| `documentation` | README, DocC, guides, or contributor-facing docs |
| `good first issue` | Small, well-scoped task suitable for a first contribution |
| `needs-repro` | Report is plausible but missing steps, environment, or a minimal repro |

Issue templates apply **`bug`** and **`enhancement`** automatically when you pick those forms; other labels are added during triage.

## Release readiness (maintainers)

For **versioning, changelog, tagging, and the automated GitHub Release workflow**, follow **[docs/RELEASE.md](docs/RELEASE.md)**.

Before a release—especially one that introduces **binary** artifacts (XCFramework, etc.)—complete the privacy and manifest checklist in **[docs/PRIVACY_MANIFEST.md](docs/PRIVACY_MANIFEST.md)** so `PrivacyInfo.xcprivacy` and distribution expectations stay accurate.

## Questions

Open a [GitHub issue](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/issues) for bugs or design discussion before very large refactors.
