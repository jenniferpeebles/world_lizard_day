# Public repository publication audit

Audit date: 2026-08-12

## Decision

The project code and documentation are suitable for a public repository after the safeguards below. Raw and generated record-level data should not be committed.

## Findings

- No `.env`, `.Renviron`, password file, API key or login credential was found inside the project.
- The original configuration contained a personal Windows username and employer-specific OneDrive path. It now resolves the repository root dynamically.
- Timestamped logs contain the same local path and are excluded.
- EDDMapS record-level data contains reporter names, phone numbers, email addresses, detailed free-text comments and precise coordinates.
- Derived clean CSV and GeoJSON files preserve many source attributes, so they inherit that disclosure risk.
- Interactive and static maps are generated artifacts and may disclose precise occurrence coordinates. They are excluded pending an editorial decision about appropriate geographic precision.
- The Leaflet dependency bundle contains generic placeholder strings for third-party API keys. These are library templates, not actual credentials, but the generated bundle is excluded regardless.
- The Georgia Southern metadata states CC0; EDDMapS reuse terms were not established from the supplied ZIP alone.
- The EDDMapS website describes query records as publicly available and supports downloads, but an explicit redistribution license was not located. Sanitized release candidates remain ignored pending confirmation.

## Safeguards implemented

- Added a deny-by-default `.gitignore` for secrets, R state, raw data, intermediate data, clean data, spatial exports, outputs and logs.
- Added explicit ignore patterns for `.env*`, `.Renviron*`, key files and credential/secret files.
- Replaced the hard-coded personal project path with runtime repository-root detection.
- Added local data-acquisition and provenance documentation.
- Documented the public-repository data policy in the main README.
- Added an allowlist-based public-release script that removes personal/free-text fields and rounds coordinates to 0.01 degree.

## Pre-push checklist

Run these checks immediately before the first push and after any future change to ignored paths:

```text
git status --short
git ls-files
git check-ignore -v <sensitive-file>
```

Review every file listed by `git ls-files`. Confirm that no raw or derived record-level data, environment file, credential, personal filesystem path, phone number or private email address is tracked.

## Remaining editorial decision

If maps or aggregate outputs will eventually be published, decide whether exact tegu and museum coordinates are necessary. Consider aggregation, jittering or coordinate removal only as an explicit publication transformation—never as a substitute for preserving the original local analytical data.
