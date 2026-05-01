# PR visual changelog (automation)

## What runs

The workflow [`.github/workflows/pr-visual-changelog.yml`](../.github/workflows/pr-visual-changelog.yml) runs on **pull requests** targeting `main`.

1. **Checkout** and run **`swift test`** under `Packages/WebImagePicker` on **`macos-latest`** (same stack as the main CI SwiftPM job).
2. **Copy** every `*.png` under `Tests/WebImagePickerTests/__Snapshots__/` into a bundle.
3. **Upload** that bundle as the **`pr-screenshots`** workflow artifact.
4. **Post or update** a **sticky bot comment** on the PR with a link to the workflow run so reviewers can download the PNGs.

This gives reviewers **automatic visual evidence** of the URL-entry (and any future) snapshot screens **without building locally**.

## Required checks vs. this workflow

- **Required:** [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — `swift build` + `swift test` (including macOS snapshots).
- **Informational:** **PR visual changelog** — must not block merges if it is flaky or if commenting is unavailable (e.g. some fork PR token limits). The sticky comment step uses `continue-on-error: true` so those cases do not fail the job.

## macOS vs. iOS / demo app

| Surface | In this workflow |
|--------|-------------------|
| **macOS** | SwiftPM tests render `WebImagePicker` in an `NSHostingView` and assert against PNG baselines in `__Snapshots__/`. Those PNGs are what we attach as artifacts. |
| **iOS / tvOS / visionOS** | Snapshot tests **skip** on non-macOS destinations (see `WebImagePickerSnapshotTests`); CI does not produce simulator PNGs here. |
| **Xcode demo** (`SwiftUI Web Image Picker.xcodeproj`) | **Not** built in GitHub Actions (signing / team setup). Run the demo locally per [CONTRIBUTING.md](../CONTRIBUTING.md) for full-app previews. |

## Fork pull requests

Artifact upload uses the default `contents: read` workflow token. Posting a sticky comment needs `pull-requests: write`, which is **not** granted to workflows from forked repos in the same way. The comment step may no-op or warn; snapshots may still appear under **Actions** artifacts for that run when uploads succeed.
