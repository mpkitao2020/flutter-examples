# Lunarabi release gates runbook

This runbook describes how to prepare a shippable Lunarabi release. It does
not close any production gate by itself. Gates close only when
`docs/evidence/release_gates.manifest.json` has `status: "closed"` plus
non-empty `evidence`, `owner`, `date`, and `signOff` for every gate.
`date` must be a real calendar date (`YYYY-MM-DD`, not `2026-99-99`).
`evidence` must be a file under `docs/evidence/artifacts/` of at least 32 bytes.

GitHub Actions runs `flutter test` on pull requests. The same preflight as
this runbook is a `workflow_dispatch` job named `release-preflight`; it is
not required to pass on placeholder PRs.

## Required release inputs

Set these before building or running preflight:

```bash
export LUNARABI_WEB_BASE_URL=https://www.lunarabi.jp
export LUNARABI_API_BASE_URL=https://api.lunarabi.jp
export LUNARABI_DEEP_LINK_HOST=app.lunarabi.jp
```

The Web and API values must be absolute `https` URLs. The deep link value is
host-only. Do not include a scheme, port, slash, or path.

Android release signing must come from environment variables or
`android/keystore.properties`:

```bash
export LUNARABI_ANDROID_STORE_FILE=/secure/path/lunarabi-release.jks
export LUNARABI_ANDROID_STORE_PASSWORD=...
export LUNARABI_ANDROID_KEY_ALIAS=...
export LUNARABI_ANDROID_KEY_PASSWORD=...
```

`android/keystore.properties` uses the standard keys:

```properties
storeFile=/secure/path/lunarabi-release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

## Native deep link host

Android reads `LUNARABI_DEEP_LINK_HOST` through Gradle manifest placeholders.
Release Gradle tasks fail when the host is missing or still points at
`.example`, `.invalid`, or localhost.

iOS entitlements are materialized before release:

```bash
bash tool/materialize_ios_deeplink_host.sh
```

That command writes `applinks:$LUNARABI_DEEP_LINK_HOST` into both
`ios/Runner/Runner.entitlements` and
`ios/Runner/Runner.Release.entitlements`.

## Firebase files

Replace these placeholder files with real production Firebase files:

- `android/app/src/prod/google-services.json`
- `ios/config/prod/GoogleService-Info.plist`

The release preflight runs `tool/forbid_release_placeholders.sh`; any
`placeholder`, `.example`, or `.invalid` marker in those production files
blocks release.

## Evidence manifest

Update `docs/evidence/release_gates.manifest.json` after each external gate is
verified. Each gate needs:

- `status: "closed"`
- `evidence` pointing at an existing file under `docs/evidence/artifacts/`
- `owner` with at least 3 characters
- `date` in `YYYY-MM-DD` format
- `signOff` with at least 2 characters

Docs and runbooks are instructions. They are not evidence. In particular,
docs/runbook alone does not close production gates. Do not point `evidence` at
runbooks, plans, specs, or markdown-only process docs.

## Release build preflight

Build releases through the wrapper from the app root. It runs the single
preflight before forwarding to `fvm flutter build`:

```bash
bash tool/build_release.sh appbundle \
  --flavor prod \
  --dart-define=FLAVOR=prod \
  --dart-define=LUNARABI_WEB_BASE_URL="$LUNARABI_WEB_BASE_URL" \
  --dart-define=LUNARABI_API_BASE_URL="$LUNARABI_API_BASE_URL" \
  --dart-define=LUNARABI_DEEP_LINK_HOST="$LUNARABI_DEEP_LINK_HOST"
```

The current repository still contains placeholders and open gates, so this
command must fail until real production inputs and evidence artifacts are
supplied.

To check without building, run the same preflight directly:

```bash
bash tool/verify_release_inputs.sh
```

If Gradle is not available in the runner, record that as a local environment
gap. Do not mark the production signing gate closed from Flutter tests alone.
