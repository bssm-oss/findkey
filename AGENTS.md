# AGENTS.md

## Project Purpose

FindKey is a defensive macOS AppKit application for scanning GitHub repositories with Gitleaks and TruffleHog to detect exposed credentials.

## Quick Start

```bash
brew install gitleaks trufflehog
swift build
swift run FindKey
```

## Install / Run / Verify Commands

- Build: `swift build`
- Run app: `swift run FindKey`
- Contract tests: `swift run FindKey -- --self-test`
- Build ad-hoc signed app bundle: `bash scripts/build-app.sh <version>`
- Build unsigned DMG: `bash scripts/build-dmg.sh <version>`
- Inspect local Homebrew cask metadata: `brew tap bssm-oss/findkey "$(pwd)" && brew info --cask bssm-oss/findkey/findkey`
- Install published Homebrew cask after the first release exists: `brew tap bssm-oss/findkey https://github.com/bssm-oss/findkey && brew install --cask bssm-oss/findkey/findkey`

## Default Work Order

1. Inspect current source and docs.
2. Keep changes scoped to the requested behavior.
3. Update implementation.
4. Update verification commands or contract tests if logic changes.
5. Update `README.md`, `AGENTS.md`, and relevant docs.
6. Run build and contract tests.
7. If packaging changed, run the packaging scripts.

## Definition of Done

A change is complete only when:

- requested behavior is implemented,
- `swift build` succeeds,
- `swift run FindKey -- --self-test` succeeds,
- relevant docs match reality,
- packaging scripts still work if packaging was touched.

## Code Style Principles

- Keep AppKit UI code in `Sources/FindKey/App/`.
- Keep pure logic in `Domain/`, `Infrastructure/`, and `Application/`.
- Use explicit errors instead of silent failure.
- Avoid hidden global state.
- Prefer redacted or minimal scanner output in user-facing surfaces.

## File Structure Principles

- `App/`: window, UI composition, theme, app state
- `Application/`: orchestration
- `Domain/`: stable data models
- `Infrastructure/`: network, git, process, scanner integrations
- `SelfTest/`: executable contract-test logic
- `Shared/`: common error types

## Documentation Principles

- Keep README user-focused and accurate.
- Record architecture or workflow changes in `docs/`.
- Document environment constraints instead of hiding them.

## Testing Principles

- Use the built-in contract-test mode for logic validation in this repository.
- Add or update assertions in `Sources/FindKey/SelfTest/ContractTestRunner.swift` when parser, API, or normalization behavior changes.
- Do not claim scanner end-to-end verification unless the commands were actually run.

## Branch / Commit / PR Rules

- Work on a non-default branch.
- Use atomic commits.
- Prefer commit messages like:
  - `feat(app): add repository scan workflow because users need one-pass scanning`
  - `ci(release): publish dmg assets on version tags`
  - `docs(readme): document external scanner requirements`

## Sensitive Paths / Caution Areas

- Do not commit tokens, secrets, or raw unredacted findings.
- Be careful when changing clone/auth behavior in `RepositoryCloneService`.
- Be careful when changing process execution in scanner runners.

## Before-Change Checklist

- Read the affected source files.
- Confirm whether docs or scripts already reference the behavior.
- Check whether the change affects packaging or release automation.

## After-Change Checklist

- Run `swift build`.
- Run `swift run FindKey -- --self-test`.
- Run packaging scripts if release behavior changed.
- Update docs.

## Never Do This

- Never fake verification results.
- Never store GitHub tokens on disk.
- Never expand scope into unrelated refactors.
- Never suppress type or concurrency errors.
- Never say releases are signed or notarized when they are not.
