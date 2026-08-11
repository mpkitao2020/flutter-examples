# Lunarabi release gates runbook

This runbook describes how to prepare a shippable Lunarabi release. It does
not close any production gate by itself. Gates close only when
`docs/evidence/release_gates.manifest.json` has `status: "closed"` plus
non-empty `evidence`, `owner`, `date`, and `signOff` for every gate.

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
- a specific evidence pointer, such as a URL, file path, command log, or ticket
- an owner
- a date
- a sign-off string

Docs and runbooks are instructions. They are not evidence. In particular,
docs/runbook alone does not close production gates.

## Preflight

Run the single release preflight from the app root:

```bash
bash tool/verify_release_inputs.sh
```

The current repository still contains placeholders and open gates, so this
command must fail until real production inputs and evidence are supplied.

When every gate is closed and inputs are real, build with matching dart-defines:

```bash
fvm flutter build appbundle \
  --flavor prod \
  --dart-define=FLAVOR=prod \
  --dart-define=LUNARABI_WEB_BASE_URL="$LUNARABI_WEB_BASE_URL" \
  --dart-define=LUNARABI_API_BASE_URL="$LUNARABI_API_BASE_URL" \
  --dart-define=LUNARABI_DEEP_LINK_HOST="$LUNARABI_DEEP_LINK_HOST"
```

If Gradle is not available in the runner, record that as a local environment
gap. Do not mark the production signing gate closed from Flutter tests alone.
