# APK Release Assurance

This note documents the YumeBox Study APK release assurance layer.

The goal is to make every GitHub Release APK easy to verify after download, not just after local build.

## Checks

`scripts/apk-installability-report.ps1` downloads APK assets from a GitHub Release and creates Markdown plus JSON reports.

It checks:

- Release asset SHA-256 against GitHub asset digest metadata.
- `zipalign -c -p 4`.
- `aapt dump badging`.
- `apksigner verify --verbose --print-certs`.
- Package name, version name, version code, and expected native ABI from `gradle.properties`.

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apk-installability-report.ps1 -Tag v0.5.4-study.8
```

Default outputs:

```text
docs/apk-installability-report-v0.5.4-study.8.md
docs/apk-installability-report-v0.5.4-study.8.json
```

Use `verify-installable-apk.ps1 -Install` only when a real Android device or emulator is connected.

## Release Discipline

For each release:

1. Build APKs with `scripts/build-apk-strict.ps1`.
2. Upload APK assets with `scripts/publish-apk-assets.ps1`.
3. Run `scripts/verify-installable-apk.ps1 -FromRelease -Tag <tag>`.
4. Run `scripts/apk-installability-report.ps1 -Tag <tag>`.
5. Upload the generated Markdown report as a release asset.

This keeps the release auditable even when the APK is downloaded later on another machine.
