# FindKey Architecture

## Overview

FindKey is a single-process macOS AppKit application that coordinates four stages:

1. GitHub target parsing
2. Repository enumeration
3. Local clone and scanner execution
4. Result normalization and presentation

## Layers

### App

- `AppDelegate`
- `MainWindowController`
- `AppController`
- `Theme`

This layer owns the window, controls, state projection, and user-facing messaging.

### Application

- `ScanOrchestrator`

This layer owns the scan workflow across repositories and emits progress updates.

### Domain

- `GitHubTarget`
- `RepositoryRecord`
- `ScanFinding`
- `RawReport`

These types define stable inputs and outputs for the workflow.

### Infrastructure

- `GitHubURLParser`
- `GitHubRepositoryService`
- `ExternalToolLocator`
- `ProcessRunner`
- `RepositoryCloneService`
- `GitleaksRunner`
- `TruffleHogRunner`
- `TemporaryWorkspace`

These components do the side-effecting work: network requests, process execution, repository cloning, and scanner parsing.

### SelfTest

- `ContractTestRunner`

This layer provides executable logic checks for environments where SwiftPM test frameworks are unavailable.

## Data Flow

```text
GitHub URL input
  -> GitHubURLParser
  -> GitHubRepositoryService
  -> [RepositoryRecord]
  -> ScanOrchestrator
      -> RepositoryCloneService
      -> GitleaksRunner
      -> TruffleHogRunner
  -> [ScanFinding] + [RawReport]
  -> AppController
  -> MainWindowController
```

## Security Posture

- Tokens are optional and session-only.
- Tokens are applied to GitHub API requests and temporary git environment configuration, not persisted in config files.
- Gitleaks output is collected without forced redaction so selected findings can be inspected in the desktop UI.
- TruffleHog runs without active verification and the stored raw report is preserved for the detail sheet and raw report view.
- Temporary clones and reports are deleted after the scan completes.

## Packaging Strategy

- `scripts/build-app.sh` compiles the release binary, assembles `FindKey.app`, and applies an ad-hoc signature.
- `scripts/build-dmg.sh` wraps the `.app` in an unsigned DMG and creates a stable `FindKey.dmg` alias for Homebrew Cask installation.
- `Casks/findkey.rb` installs the latest published DMG through Homebrew.
- GitHub Actions release workflow uploads the DMGs on version tags.
