# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-22

### Added

- Initial release.
- `SKILL.md` with triggering description and pre-flight checklist covering API surface selection, SDK vs REST, version selection, auth, pagination, and failure handling.
- `references/auth-and-config.md` — PAT setup, three ranked secret storage options (env vars, `config.json`, SecretManagement), auth verification pattern, REST token helper.
- `references/patterns.md` — `Invoke-Paginate` usage, manual REST pagination loop, structured error capture, `Invoke-IscWithRetry` helper with exponential backoff honoring `Retry-After`, Elasticsearch search DSL, SCIM filter operator reference, batch operations guidance.
- `references/sdk-vs-rest.md` — decision tree, three rules for writing native-feeling REST helpers, side-by-side translation table for common operations.
- `references/coding-standards.md` — team PowerShell style guide covering naming, required preamble, parameter conventions, output streams, error handling, logging, formatting, destructive-op handling.
- `templates/new-script.ps1` — starter script with full preamble, auth check, retry wrapper, paginated call example, and `-WhatIf` support wired up.

[Unreleased]: https://github.com/CloudSec181/kilo-sailpoint-powershell-skill/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/CloudSec181/kilo-sailpoint-powershell-skill/releases/tag/v1.0.0
