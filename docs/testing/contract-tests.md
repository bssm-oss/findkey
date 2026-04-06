# Contract Test Strategy

## Why FindKey Uses Contract Tests

The current CLI environment for this repository does not provide SwiftPM access to `XCTest` or the Swift `Testing` module. Instead of claiming unavailable test infrastructure works, FindKey includes an executable contract-test mode in the application target.

## Command

```bash
swift run FindKey -- --self-test
```

## What It Validates

- GitHub URL parsing
- lookalike-host rejection for GitHub URLs
- Owner resolution behavior for root GitHub URLs
- Repository enumeration decoding
- Gitleaks JSON parsing
- TruffleHog NDJSON parsing

## What It Does Not Validate

- Full AppKit UI automation
- Live GitHub API calls
- Real scanner process execution against installed tools

## When to Update It

Update `Sources/FindKey/SelfTest/ContractTestRunner.swift` whenever:

- URL parsing rules change
- GitHub API decoding changes
- finding normalization changes
- parser behavior changes
