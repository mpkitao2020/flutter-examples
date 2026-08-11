# Lunarabi scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FVM ピン留めの新規 Flutter プロジェクト `lunarabi/` に、単一 `main.dart`・環境設定・WebView シェル・`HostGuard`/`AppNavigator`・ネイティブ Firebase 置き場を用意する。

**Architecture:** 薄いシェル。後続 deeplink / push / payments が同じ navigation 契約に差し込む。

**Tech Stack:** Flutter（FVM 具体バージョンピン）、`webview_flutter`、`firebase_core`（options なし）、Android product flavors、iOS schemes + plist copy

**Branch:** `cursor/lunarabi-scaffold-c3bc`（base: `develop`）  
**Index:** [README.md](./README.md)

## Global Constraints

- applicationId / bundle ID: `com.wandit.lunarabi`（flavor でも suffix なし）
- `main.dart` は 1 ファイルのみ
- `.env` / `flutter_dotenv` 禁止
- `FirebaseOptions` / `firebase_options.dart` / `DefaultFirebaseOptions` / `Firebase.initializeApp(options:` 禁止
- フォルダ: `/workspace/lunarabi`
- Spec: `docs/superpowers/specs/2026-08-11-lunarabi-webview-design.md`

---

### Task 1: FVM project bootstrap

**Files:**
- Create: `lunarabi/` via flutter create
- Create: `lunarabi/.fvmrc` with concrete version string (e.g. `3.x.y`, not the word `stable`)

**Interfaces:**
- Produces: runnable skeleton with package `lunarabi`, id `com.wandit.lunarabi`

- [ ] **Step 1: Create project with FVM**

```bash
dart pub global activate fvm
export PATH="$PATH:$HOME/.pub-cache/bin"
fvm install stable
# Resolve concrete version, e.g.:
STABLE_VER=$(fvm list | awk '/stable/ {print $1; exit}')
# Prefer reading the installed stable path version:
fvm flutter --version
cd /workspace
fvm spawn stable flutter create --org com.wandit --project-name lunarabi --platforms=android,ios lunarabi
cd lunarabi
fvm use <concrete-version-from-flutter --version>
# Ensure .fvmrc looks like: { "flutter": "3.24.5" }  (example numbers — use actual)
python3 - <<'PY'
import json, pathlib, re, subprocess
out = subprocess.check_output(["fvm", "flutter", "--version"], text=True)
m = re.search(r"Flutter\s+(\d+\.\d+\.\d+)", out)
assert m, out
pathlib.Path(".fvmrc").write_text(json.dumps({"flutter": m.group(1)}, indent=2) + "\n")
print(pathlib.Path(".fvmrc").read_text())
PY
rg "com\\.wandit\\.lunarabi" android ios
```

Expected: `.fvmrc` has digits; package id present.

- [ ] **Step 2: Commit**

```bash
git add lunarabi
git commit -m "feat(lunarabi): bootstrap FVM Flutter project"
```

---

### Task 2: AppConfig + flavor parse + single main

**Files:**
- Create: `lunarabi/lib/core/env/app_config.dart`
- Create: `lunarabi/test/core/env/app_config_test.dart`
- Modify: `lunarabi/lib/main.dart`

**Interfaces:**
- Produces: `Flavor`, `AppConfig.fromFlavor`, `parseFlavor(String raw, {required bool isRelease})`
- URL table exactly as in the design spec

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';

void main() {
  test('dev urls', () {
    final c = AppConfig.fromFlavor(Flavor.dev);
    expect(c.webBaseUrl.toString(), 'https://dev.lunarabi.example');
    expect(c.apiBaseUrl.toString(), 'https://api-dev.lunarabi.example');
    expect(c.deepLinkHost, 'app.lunarabi.example');
  });

  test('prod urls', () {
    final c = AppConfig.fromFlavor(Flavor.prod);
    expect(c.webBaseUrl.toString(), 'https://www.lunarabi.example');
    expect(c.apiBaseUrl.toString(), 'https://api.lunarabi.example');
  });

  test('empty define uses prod in release', () {
    expect(parseFlavor('', isRelease: true), Flavor.prod);
    expect(parseFlavor('', isRelease: false), Flavor.dev);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd /workspace/lunarabi && fvm flutter test test/core/env/app_config_test.dart
```

- [ ] **Step 3: Implement `app_config.dart` and `main.dart`**

`main.dart`:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `const raw = String.fromEnvironment('FLAVOR')`
3. `final flavor = parseFlavor(raw, isRelease: kReleaseMode)`
4. `runApp(LunarabiApp(config: AppConfig.fromFlavor(flavor)))`
5. Home temporarily shows `config.webBaseUrl` text until Task 3

- [ ] **Step 4: Tests PASS; commit**

```bash
fvm flutter test test/core/env/app_config_test.dart
git add lunarabi/lib lunarabi/test
git commit -m "feat(lunarabi): add AppConfig and single main entry"
```

---

### Task 3: HostGuard + WebView shell + AppNavigator

**Files:**
- Create: `lunarabi/lib/core/navigation/app_navigator.dart`（`HostGuard`, `AppNavigator`, `WebViewAppNavigator`）
- Create: `lunarabi/lib/features/webview/webview_shell.dart`
- Create: `lunarabi/test/core/navigation/host_guard_test.dart`
- Modify: `lunarabi/lib/main.dart`
- Modify: `lunarabi/pubspec.yaml`（`webview_flutter`）

**Interfaces:**
- Exact signatures from design spec (`isAllowed`, `resolveForWebView`, `openDeepLink`, `openFromNotification`)

- [ ] **Step 1: Failing HostGuard tests**

```dart
test('allowlist and resolve', () {
  final g = HostGuard(AppConfig.fromFlavor(Flavor.dev));
  expect(g.isAllowed(Uri.parse('http://app.lunarabi.example/x')), false);
  expect(g.isAllowed(Uri.parse('https://evil.example/x')), false);
  expect(g.isAllowed(Uri.parse('https://app.lunarabi.example/pay')), true);
  final resolved = g.resolveForWebView(Uri.parse('https://app.lunarabi.example/a?b=1'));
  expect(resolved.toString(), 'https://dev.lunarabi.example/a?b=1');
});
```

- [ ] **Step 2: Implement HostGuard + WebViewShell**

- AppBar + WebView（platform view を widget test で直接 pump しない）
- debug/profile: 環境切替メニュー → 新しい `AppConfig` で reload
- `WebViewAppNavigator` uses `resolveForWebView` then `controller.loadRequest`

- [ ] **Step 3: Verify**

```bash
fvm flutter test test/core/navigation/host_guard_test.dart
fvm flutter analyze
```

Expected: tests PASS; analyze reports no issues in project (fix pre-existing template infos if any, do not add new errors).

- [ ] **Step 4: Commit**

```bash
git add lunarabi/lib lunarabi/test lunarabi/pubspec.yaml lunarabi/pubspec.lock
git commit -m "feat(lunarabi): add WebView shell and AppNavigator"
```

---

### Task 4: Native Firebase placeholders + flavors

**Files:**
- Android: detect whether `android/app/build.gradle` or `build.gradle.kts` was generated; patch **that** file only
- Add product flavor dimension `env`: `dev`, `stg`, `prod`
- Apply Google Services plugin in root and app Gradle files per current Flutter Firebase docs for the generated DSL
- Create placeholder `google-services.json` under `android/app/src/{dev,stg,prod}/`（package_name `com.wandit.lunarabi`）
- iOS: add schemes/configs named so `${CONFIGURATION}` contains the flavor (e.g. `Debug-dev`, `Release-stg`, `Profile-prod`). Build Phase script:

```bash
# Extract flavor after the last '-' in CONFIGURATION
FLAVOR="${CONFIGURATION##*-}"
case "$FLAVOR" in
  dev|stg|prod) ;;
  *) echo "Unknown flavor in CONFIGURATION=$CONFIGURATION"; exit 1 ;;
esac
SRC="${PROJECT_DIR}/config/${FLAVOR}/GoogleService-Info.plist"
DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
cp "$SRC" "$DST"
```
- Placeholder plist minimum keys: `API_KEY`, `GCM_SENDER_ID`, `PLIST_VERSION`, `BUNDLE_ID`=`com.wandit.lunarabi`, `PROJECT_ID`, `GOOGLE_APP_ID`
- Add `firebase_core`; `main.dart` calls `await Firebase.initializeApp();` with **no** options
- Create `lunarabi/tool/forbid_firebase_options.sh` that fails if forbidden strings appear under `lib/`
- Create `lunarabi/README.md` with FVM run commands, flavor defines, Firebase replace instructions, iOS external-payment risk note pointer（詳細は payments README 節）

- [ ] **Step 1: Implement flavors + placeholders + plugin wiring**
- [ ] **Step 2: Run forbid script + analyze**

```bash
cd /workspace
bash lunarabi/tool/forbid_firebase_options.sh
cd /workspace/lunarabi && fvm flutter analyze
```

- [ ] **Step 3: Commit**

```bash
git add lunarabi
git commit -m "feat(lunarabi): add env flavors and native Firebase placeholders"
```

---

## Self-review checklist

- Spec coverage: FVM pin, single main, parseFlavor release fallback, HostGuard resolve, WebView, native Firebase + plugin + iOS copy, no FirebaseOptions
- Exact `git add` on every commit step
