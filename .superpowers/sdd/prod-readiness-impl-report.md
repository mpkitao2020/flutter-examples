# Lunarabi production-readiness implementation report

Branch: `cursor/lunarabi-prod-readiness-impl-c3bc`

## Commits

- `a7c9864` `feat(lunarabi): inject prod URLs via dart-define and refuse placeholders`
- `455ce8a` `feat(android): deepLinkHost placeholder + fail release without signing/host`
- `2d71959` `chore(lunarabi): add verify_release_inputs preflight and iOS host materialize`
- `4577c6c` `feat(lunarabi): HttpPaymentBackendClient for release payments`
- `0c654e9` `docs(lunarabi): release gates runbook + evidence manifest`

## Verification

- `fvm flutter test`: passed, 166 tests.
- `bash tool/verify_release_inputs.sh`: failed as expected on the current placeholder tree.

Preflight blockers reported:

- missing `LUNARABI_WEB_BASE_URL`, `LUNARABI_API_BASE_URL`, and `LUNARABI_DEEP_LINK_HOST`
- prod Firebase placeholders in Android and iOS files
- iOS entitlement applinks still using `.example`
- missing Android release signing inputs
- every release evidence gate still open or missing required fields

## Notes

- The evidence manifest starts with all gates `open`; docs and runbooks do not close production gates.
- `HttpPaymentBackendClient.confirmIap` throws `UnsupportedError`; release GMO and Aozora flows use HTTP, while IAP receipt verification remains on the Web bridge.
- Android release no longer falls back to debug signing.
- Gradle release build was not run here. The runbook documents that Gradle/SDK environment gaps are not release evidence.

## 2026-08-11 critical review r1 fixes

- Commit `6e6ec95` wires Gradle release assemble/bundle tasks to `verifyLunarabiReleaseInputs`, adds `tool/build_release.sh`, includes Dart FirebaseOptions detection in the single preflight, and checks the Android store file is readable.
- `tool/verify_release_gates_manifest.sh` now only accepts existing non-markdown artifacts under `docs/evidence/artifacts/`, rejects runbook/superpowers paths, enforces 32-byte minimum artifacts, and validates date/owner/signOff shape.
- `fvm flutter test`: passed, 179 tests.
- `bash tool/verify_release_inputs.sh`: failed as expected on the current tree because prod env, Firebase files, iOS entitlements, signing inputs, and evidence gates are still absent/open.
- Gradle configuration could not be executed locally: no `gradlew` is present and `gradle` is not installed.
