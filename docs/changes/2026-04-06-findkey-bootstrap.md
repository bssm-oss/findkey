# 2026-04-06 FindKey bootstrap

## Background

The repository started empty and needed a full greenfield implementation for a macOS desktop tool that scans GitHub repositories for leaked credentials.

## Goal

Create a maintainable Swift/AppKit application that resolves GitHub organization or user repository URLs, scans repositories with Gitleaks and TruffleHog, and produces DMG release artifacts from CI.

## What Changed

- Bootstrapped a Swift Package Manager AppKit application.
- Added a single-window AppKit UI for URL input, optional token input, repository enumeration, scan progress, findings, and raw reports.
- Added GitHub repository discovery, local clone workflow, external tool discovery, and scanner runners.
- Hardened runtime behavior so failed re-resolves do not leave stale repositories scannable, per-repository scan failures are skipped instead of aborting the full batch, and TruffleHog raw output is sanitized before presentation.
- Added an internal contract-test mode because standard Swift test frameworks are unavailable in the current CLI environment.
- Added packaging scripts for unsigned `.app` and `.dmg` creation.
- Added CI for build validation, DMG validation, and release publishing.
- Added a repository-local Homebrew Cask backed by the latest GitHub Release DMG alias.
- Added ad-hoc app signing and Homebrew postflight quarantine removal to reduce Gatekeeper launch failures after brew installation.

## Design Decisions

- **AppKit over SwiftUI** to match the requested macOS desktop stack.
- **SwiftPM over hand-authored Xcode project files** to keep greenfield bootstrapping reproducible and scriptable in CI.
- **Unsigned release pipeline** because no Apple signing credentials were provided.
- **TruffleHog `--no-verification`** to avoid active credential validation side effects.
- **Built-in contract tests** instead of XCTest because the current environment does not provide `XCTest` or `Testing` modules to SwiftPM.

## Impact

- The repository now has a functioning buildable codebase.
- Release automation exists for version-tagged DMG distribution.
- Documentation reflects real setup and known limitations.

## Verification

- `swift build`
- `swift run FindKey -- --self-test`
- `bash scripts/build-app.sh <version>`
- `bash scripts/build-dmg.sh <version>`

## Remaining Limitations

- Releases are unsigned and not notarized.
- Scanner end-to-end validation depends on local installation of Gitleaks and TruffleHog.
- The built-in tests validate logic and parsing, not live remote scans.

## Follow-up Work

- Add signed/notarized release support when Apple credentials are available.
- Add richer filtering or export options if needed.
- Add broader live smoke testing once scanner tooling is guaranteed in CI.
