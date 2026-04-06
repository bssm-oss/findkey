# FindKey

FindKey is a macOS AppKit desktop app for scanning GitHub organization and user repositories for exposed credentials with **Gitleaks** and **TruffleHog**. It is designed for defensive internal use: you paste a GitHub repositories URL, the app resolves the repositories, clones them locally into a temporary workspace, runs both scanners, and shows the combined findings in one interface.

## Problem

GitHub organizations and personal accounts often accumulate many repositories over time, which makes manual secret-scanning repetitive and easy to skip. FindKey turns that into one repeatable macOS workflow for checking whether API keys, tokens, or other credentials have leaked into repository history.

## Core Features

- Accepts GitHub org and user repository URLs such as:
  - `https://github.com/orgs/bssm-oss/repositories`
  - `https://github.com/heodongun?tab=repositories`
  - `https://github.com/<owner>`
- Uses the GitHub REST API to enumerate repositories.
- Supports an optional GitHub token to improve rate limits and access protected repositories.
- Clones repositories into a temporary workspace and scans them with:
  - `gitleaks git`
  - `trufflehog git --json --no-verification`
- Merges findings into one AppKit UI and exposes raw scanner output.
- Builds an unsigned `.app` and `.dmg` from CI for tagged releases.
- Includes a built-in contract-test mode that validates URL parsing, repository enumeration, and parser behavior in environments where XCTest is unavailable.

## Technology Stack

- Swift 6.2
- AppKit
- Swift Package Manager
- GitHub Actions
- External scanners: Gitleaks, TruffleHog

## Requirements

- macOS 13+
- Xcode Command Line Tools or Xcode 15+
- `gitleaks` installed locally
- `trufflehog` installed locally

Recommended installation:

```bash
brew install gitleaks trufflehog
```

## Local Development

### Build

```bash
swift build
```

### Run the App

```bash
swift run FindKey
```

### Run Contract Tests

```bash
swift run FindKey -- --self-test
```

This command exercises the non-UI logic that is safe to validate without live GitHub/network dependencies.

## Packaging

### Build an unsigned `.app`

```bash
bash scripts/build-app.sh 0.1.0
```

Output:

- `dist/FindKey.app`

### Build an unsigned `.dmg`

```bash
bash scripts/build-dmg.sh 0.1.0
```

Output:

- `dist/FindKey-0.1.0.dmg`

## GitHub Token Behavior

- The token field is optional.
- The app uses the token for GitHub API requests.
- When a token is present, repository cloning uses temporary git environment configuration for the HTTP authorization header instead of embedding the token into the clone URL or persisting it on disk.
- The app does **not** persist the token to disk.

## How Scanning Works

1. Parse the GitHub URL into an organization, user, or owner lookup.
2. Enumerate repositories through the GitHub REST API.
3. Clone each repository into a temporary workspace.
4. Run Gitleaks and TruffleHog against the local clone.
5. Normalize the findings into one table.
6. Surface sanitized JSON/NDJSON scanner output in the raw report pane.
7. Clean up the temporary workspace when the scan completes.

## Folder Structure

```text
.
├── .github/workflows/
├── docs/
│   ├── architecture/
│   ├── changes/
│   └── testing/
├── scripts/
└── Sources/FindKey/
    ├── App/
    ├── Application/
    ├── Domain/
    ├── Infrastructure/
    ├── SelfTest/
    └── Shared/
```

## Architecture Overview

- **App**: `AppDelegate`, `MainWindowController`, visual theme, and UI state wiring.
- **Application**: `ScanOrchestrator` coordinates clone → scan → aggregate.
- **Domain**: repository, target, and finding models.
- **Infrastructure**: GitHub API client, URL parser, process runner, tool discovery, clone service, scanner runners.
- **SelfTest**: executable contract-test mode for repeatable non-UI validation.

More detail is documented in `docs/architecture/findkey-architecture.md`.

## Development Principles

- Prefer small, auditable changes over broad refactors.
- Do not log or persist secrets.
- Keep raw reports redacted or sanitized where the scanner supports it.
- Match docs to the real implementation and verification commands.
- Treat missing tooling or credentials as explicit user-facing errors.

## CI Overview

- `ci.yml`
  - Runs `swift build`
  - Runs the built-in contract tests
  - Verifies that the unsigned `.app` bundle can be assembled
  - Verifies that the unsigned `.dmg` can be assembled before PR merge
- `release.yml`
  - Triggers on version tags like `v0.1.0`
  - Runs build + contract tests
  - Produces an unsigned `.dmg`
  - Uploads the `.dmg` to the GitHub Release

## Known Limitations

- Releases are **unsigned** and **not notarized**. Gatekeeper warnings are expected until Apple signing credentials are added.
- TruffleHog runs in `--no-verification` mode to avoid active credential verification side effects.
- The app currently scans repository git history/content only. It does not scan issues, PR comments, deleted commit discovery, or wiki/discussion surfaces.
- The built-in contract tests validate core logic, not live end-to-end scanner execution against real repositories.

## Roadmap

- Signed and notarized releases
- Better export/report persistence controls
- Optional filtering for archived or forked repositories
- Richer scan progress metadata

## Contributing

1. Create a feature branch.
2. Run `swift build`.
3. Run `swift run FindKey -- --self-test`.
4. Update docs when behavior changes.
5. Open a pull request with verification evidence.
