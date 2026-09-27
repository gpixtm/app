# Localization delivery validation

Validated on 2026-09-27.

- Flutter analyzer: no issues.
- Flutter tests: 67 passed; one real-API integration test skipped because its environment was not configured.
- Regression coverage includes auth/settings switching, preserved form state, translated existing errors, persistent offline preference, device fallback, catalog parity/plurals and legacy French approach-cache compatibility.
- Android ARM64 Dev and Prod debug builds: successful, using `lib/main.dart`.
- The separate API passed its isolated CI, including authenticated HTTP flows, account isolation, PostgreSQL persistence, English/French reset emails captured by Mailpit and language selection for approach directions.
- No personal-device installation, field navigation test or production deployment was performed for this delivery.
- Existing provider instructions remain in their original language until recalculation; active GPS notification text changes when the location stream restarts.

## Local build checksums

These debug artifacts and local configuration are excluded from Git. The checksums identify local builds, not published store releases.

| Artifact | SHA-256 |
| --- | --- |
| `app-arm64-v8a-dev-debug.apk` | `35312d06def6cbbfe30e94c14a417edff2049384e760b92605b526318f11bff4` |
| `app-arm64-v8a-prod-debug.apk` | `707e075efac3522bc6054418e7a2a2ac8a185d3d11fa9201f9d02a2424bdaaee` |
