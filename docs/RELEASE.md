# Releasing WebImagePicker

This document is for **maintainers** cutting versioned releases consumers can pin in SwiftPM.

## Versioning

- Use **Semantic Versioning** (`MAJOR.MINOR.PATCH`). Tags are the source of truth SwiftPM resolves against the repository URL.
- **Recommended tag form:** plain `MAJOR.MINOR.PATCH` (for example `1.2.0`), matching the examples in [README.md](../README.md). You may alternatively use a `v` prefix (`v1.2.0`) if you prefer; the release workflow accepts either form.
- **MAJOR** — incompatible API or behavior changes for consumers.
- **MINOR** — backward-compatible additions.
- **PATCH** — backward-compatible fixes.

Pre-release identifiers (for example `1.0.0-beta.1`) are not created automatically by the tag-based workflow; if you need them, add a workflow or manual release step later.

## Changelog

1. Under **`## [Unreleased]`** in [CHANGELOG.md](../CHANGELOG.md), add concise bullets under the right subsection (`Added`, `Changed`, `Fixed`, `Removed`).
2. When you tag a release, add a new section **`## [X.Y.Z] — YYYY-MM-DD`** above `[Unreleased]` and move the relevant bullets out of `[Unreleased]` into that section (leave empty subsections out or delete them).
3. Commit the changelog update on **`main`** (or merge a PR) **before** creating the tag so the tagged revision includes accurate notes.

## Release checklist

1. **`main` is green** — CI passes on the commit you intend to release.
2. **Changelog** — `[Unreleased]` updated; new `## [X.Y.Z]` section prepared as above.
3. **Privacy / distribution** — If the release introduces or changes binary artifacts or collection behavior, complete [PRIVACY_MANIFEST.md](PRIVACY_MANIFEST.md).
4. **Tag from the release commit:**

   ```bash
   git checkout main
   git pull --ff-only origin main
   git tag -a 1.2.0 -m "Release 1.2.0"
   git push origin 1.2.0
   ```

   Use an annotated tag (`-a`) so the tag message records the release intent.

5. **GitHub Release** — Pushing a valid SemVer tag triggers [.github/workflows/release.yml](../.github/workflows/release.yml), which creates a GitHub Release with generated notes. Edit the release on GitHub if you want a richer summary or links.

## Consumer integration

Apps should depend on the **repository root** URL with `from: "X.Y.Z"` (or an exact `exactVersion` / revision) as documented in the README. After pushing the tag, SwiftPM can resolve the new version once caches refresh.
