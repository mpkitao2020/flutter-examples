# Lunarabi prod secrets + signing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** release が Firebase placeholder と debug 署名のまま出荷できないようにし、実ファイル差し替え手順と署名配線をコード／スクリプトで固定する。

**Architecture:** リポジトリ内の `*-placeholder` Firebase ファイルは残してよい（ローカル開発）。`tool/forbid_release_placeholders.sh` と Dart テストが、CI の release ジョブ／手動リリース前に placeholder 文字列と Android debug signing を拒否する。署名は環境変数から `signingConfigs.release` を構成（秘密はコミットしない）。

**Tech Stack:** Gradle Kotlin DSL, Xcode entitlements（既存）, bash + Flutter test

**Branch:** `cursor/lunarabi-prod-secrets-signing-c3bc`  
**Base:** after prod-config

## Global Constraints

- Do **not** commit real Firebase API keys or keystore passwords
- Placeholder markers that must fail release checks:
  - `lunarabi-*-placeholder`
  - `"current_key": "placeholder"`
  - `<string>placeholder</string>` in GoogleService-Info
- Android release must not use `signingConfigs.debug` when env `LUNARABI_UPLOAD_STORE_FILE` is set; when unset in local debug it's OK, but release CI must set it
- Spec: prod-readiness design

---

### Task 1: Forbid Firebase placeholders script + test

**Files:**
- Create: `lunarabi/tool/forbid_release_placeholders.sh`
- Create: `lunarabi/test/tool/forbid_release_placeholders_test.dart`
- Modify: `lunarabi/README.md`

**Script behavior:**

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() {
  local file="$1"
  if [[ ! -f "$file" ]]; then echo "missing $file"; fail=1; return; fi
  if grep -Eiq 'placeholder|lunarabi-.*-placeholder' "$file"; then
    echo "PLACEHOLDER_FOUND $file"
    fail=1
  fi
}
check "$root/android/app/src/prod/google-services.json"
check "$root/ios/config/prod/GoogleService-Info.plist"
# Optional: stg when RELEASE_ENV=stg
exit "$fail"
```

Test approach: copy fixtures into temp dir in test OR assert current repo **fails** the script (expected until secrets swapped). Dual mode:

```dart
test('forbid script exits non-zero while prod Firebase is placeholder', () async {
  final result = await Process.run('bash', ['tool/forbid_release_placeholders.sh'],
    workingDirectory: /* lunarabi root */);
  expect(result.exitCode, isNot(0));
  expect(result.stdout + result.stderr, contains('PLACEHOLDER_FOUND'));
});
```

After real files are installed locally, operators run the same script and expect exit 0 — document that CI release job requires exit 0.

- [ ] **Step 1: Write failing test** (script missing → fail)
- [ ] **Step 2: Add script + make executable**
- [ ] **Step 3: Test passes (exit != 0 on current placeholders)**
- [ ] **Step 4: README「Firebase 差し替え」手順** — console から prod/stg/dev をダウンロードして各 path に上書き → script → `fvm flutter test test/tool/forbid_release_placeholders_test.dart` は placeholder 中は red のままなので、**別テスト名**で「script exists and detects」に留め、release CI は script 直実行
- [ ] **Step 5: Commit** `chore(lunarabi): add Firebase placeholder forbid script`

---

### Task 2: Android release signing from env

**Files:**
- Modify: `lunarabi/android/app/build.gradle.kts`
- Modify: `lunarabi/README.md`
- Create: `lunarabi/android/keystore.properties.example`（パスワードなしのキー名だけ）

**Gradle shape:**

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            val storeFileProp = keystoreProperties["storeFile"] as String?
                ?: System.getenv("LUNARABI_UPLOAD_STORE_FILE")
            if (storeFileProp != null) {
                storeFile = file(storeFileProp)
                storePassword = keystoreProperties["storePassword"] as String?
                    ?: System.getenv("LUNARABI_UPLOAD_STORE_PASSWORD")
                keyAlias = keystoreProperties["keyAlias"] as String?
                    ?: System.getenv("LUNARABI_UPLOAD_KEY_ALIAS")
                keyPassword = keystoreProperties["keyPassword"] as String?
                    ?: System.getenv("LUNARABI_UPLOAD_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            val releaseSigning = signingConfigs.findByName("release")
            signingConfig = if (releaseSigning?.storeFile != null) {
                releaseSigning
            } else {
                // Keep debug only for local unsigned experiments; document as NOT shippable
                signingConfigs.getByName("debug")
            }
        }
    }
}
```

Add test or script `tool/forbid_debug_release_signing.sh` that greps `build.gradle.kts` is insufficient (dynamic). Instead README + CI checklist: 「AAB の cert SHA が upload key と一致」.

Optional Dart-less check in README manual.

- [ ] **Step 1: Add `keystore.properties.example`**
- [ ] **Step 2: Wire `signingConfigs.release` as above**
- [ ] **Step 3: README に env 変数表と `bundleProdRelease` 手順**
- [ ] **Step 4: Commit** `build(android): wire release signing from env or keystore.properties`

---

### Task 3: iOS applinks host note + Release entitlements sanity

**Files:**
- Modify: `lunarabi/README.md`
- Modify: `lunarabi/test/ios/runner_push_configuration_test.dart`（既存の aps-environment テストは維持）
- Optional Modify: entitlements の `applinks:app.lunarabi.example` を dart-define では変えられないので、README に「本番前に `applinks:<LUNARABI_DEEP_LINK_HOST>` へ手編集」を必須ゲート化

- [ ] **Step 1: README External gate 行を「差し替えコマンド＋証拠」付きに更新**
- [ ] **Step 2: Commit** `docs(ios): require real applinks host before production`

---

## Self-review checklist

- [ ] No real secrets committed
- [ ] Placeholder detection works on current tree
- [ ] Release signing path exists without forcing secrets into git
