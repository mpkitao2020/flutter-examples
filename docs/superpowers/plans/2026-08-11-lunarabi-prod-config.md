# Lunarabi prod config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** release ビルドが `.example` ドメインで起動せず、実 URL を `--dart-define` で注入できるようにする。

**Architecture:** `AppConfig.fromFlavor` は開発用デフォルト（`.example`）を残す。`AppConfig.resolve` が dart-define を優先し、`kReleaseMode` では host が `.example` で終わる／空なら起動時に失敗する。テストは define の優先順位と release 拒否を固定する。

**Tech Stack:** Flutter `String.fromEnvironment`, existing `AppConfig` / `Flavor`

**Branch:** `cursor/lunarabi-prod-config-c3bc`  
**Base:** `cursor/lunarabi-nav-icons-ios-caps-c3bc`

## Global Constraints

- Dart-define keys (exact):
  - `LUNARABI_WEB_BASE_URL` — absolute `https` URI string
  - `LUNARABI_API_BASE_URL` — absolute `https` URI string
  - `LUNARABI_DEEP_LINK_HOST` — host only, no scheme (e.g. `app.lunarabi.jp`)
- Release must refuse hosts ending with `.example` or equal to `localhost`
- Debug/profile may keep `.example` defaults for offline unit tests
- Spec: `docs/superpowers/specs/2026-08-11-lunarabi-prod-readiness-design.md`

---

### Task 1: AppConfig resolve + release guard

**Files:**
- Modify: `lunarabi/lib/core/env/app_config.dart`
- Test: `lunarabi/test/core/env/app_config_test.dart`
- Modify: `lunarabi/README.md` (dart-define 表)

**Interfaces:**

```dart
class AppConfig {
  static AppConfig resolve({
    required Flavor flavor,
    required bool isRelease,
    String webBaseUrlDefine = const String.fromEnvironment('LUNARABI_WEB_BASE_URL'),
    String apiBaseUrlDefine = const String.fromEnvironment('LUNARABI_API_BASE_URL'),
    String deepLinkHostDefine = const String.fromEnvironment('LUNARABI_DEEP_LINK_HOST'),
  });

  /// Throws [StateError] when [isRelease] and any host is placeholder-like.
  static void assertReleaseHosts(AppConfig config, {required bool isRelease});
}

bool isPlaceholderHost(String host) {
  final h = host.toLowerCase();
  return h.isEmpty ||
      h == 'localhost' ||
      h.endsWith('.example') ||
      h.endsWith('.invalid');
}
```

Rules:
- If a dart-define is non-empty, parse/use it; else fall back to `fromFlavor(flavor)`
- After merge, if `isRelease`, call `assertReleaseHosts`
- `main.dart` uses `AppConfig.resolve(flavor: flavor, isRelease: kReleaseMode)` instead of `fromFlavor` alone

- [ ] **Step 1: Write failing tests**

```dart
test('resolve prefers dart-define over flavor defaults', () {
  final config = AppConfig.resolve(
    flavor: Flavor.prod,
    isRelease: false,
    webBaseUrlDefine: 'https://www.lunarabi.jp',
    apiBaseUrlDefine: 'https://api.lunarabi.jp',
    deepLinkHostDefine: 'app.lunarabi.jp',
  );
  expect(config.webBaseUrl.host, 'www.lunarabi.jp');
  expect(config.apiBaseUrl.host, 'api.lunarabi.jp');
  expect(config.deepLinkHost, 'app.lunarabi.jp');
});

test('assertReleaseHosts throws on .example in release', () {
  final config = AppConfig.fromFlavor(Flavor.prod);
  expect(
    () => AppConfig.assertReleaseHosts(config, isRelease: true),
    throwsA(isA<StateError>()),
  );
});

test('assertReleaseHosts allows real hosts in release', () {
  final config = AppConfig(
    flavor: Flavor.prod,
    webBaseUrl: Uri.parse('https://www.lunarabi.jp'),
    apiBaseUrl: Uri.parse('https://api.lunarabi.jp'),
    deepLinkHost: 'app.lunarabi.jp',
  );
  expect(
    () => AppConfig.assertReleaseHosts(config, isRelease: true),
    returnsNormally,
  );
});
```

- [ ] **Step 2: Run** `cd lunarabi && fvm flutter test test/core/env/app_config_test.dart` → FAIL
- [ ] **Step 3: Implement `isPlaceholderHost`, `resolve`, `assertReleaseHosts`; update `main.dart`**
- [ ] **Step 4: Run tests → PASS**
- [ ] **Step 5: README に dart-define 例を追加**

```bash
fvm flutter run --release --dart-define=FLAVOR=prod \
  --dart-define=LUNARABI_WEB_BASE_URL=https://www.lunarabi.jp \
  --dart-define=LUNARABI_API_BASE_URL=https://api.lunarabi.jp \
  --dart-define=LUNARABI_DEEP_LINK_HOST=app.lunarabi.jp
```

- [ ] **Step 6: Commit** `feat(lunarabi): inject prod URLs via dart-define and refuse .example`

---

### Task 2: Associated Domains / Android intent host stay in sync docs

**Files:**
- Modify: `lunarabi/README.md`
- Modify: `lunarabi/ios/Runner/Runner.entitlements` は **まだ placeholder のまま可**（実ホスト差し替えは secrets-signing プラン）。ここでは README に「entitlements の `applinks:` と `LUNARABI_DEEP_LINK_HOST` を一致させる」チェックを書く
- Test: `lunarabi/test/core/env/app_config_test.dart` に README 言及不要の単体追加なしでよい。代わりに tool スクリプトは Task なし

- [ ] **Step 1: README「ドメイン一致チェックリスト」** — web / api / deeplink / applinks / assetlinks package の対応表テンプレ
- [ ] **Step 2: Commit** `docs(lunarabi): document domain dart-define and applinks sync`

---

## Self-review checklist

- [ ] Release cannot boot on `.example`
- [ ] Debug unit tests still use flavor defaults without defines
- [ ] Exact dart-define key names match Global Constraints
