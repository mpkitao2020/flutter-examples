# Lunarabi deeplink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** HTTPS Universal Links / App Links のみで起動・再開し、許可ホスト URI を `AppNavigator` / `DeepLinkBus` へ渡す。

**Architecture:** `app_links` で初期リンクとストリームを購読。`HostGuard` 必須。GMO 完了は bus のみ（Web 遷移しない）。bus は cold start replay 付き。

**Tech Stack:** `app_links`、Android App Links intent-filter、iOS Associated Domains

**Branch:** `cursor/lunarabi-deeplink-c3bc`（base: scaffold マージ後の `develop`）

## Global Constraints

- HTTPS のみ。custom scheme / http → `DeepLinkKind.unknown`
- ホスト allowlist: `AppConfig.deepLinkHost` **または** `AppConfig.webBaseUrl.host`（`HostGuard.isAllowed`）
- GMO 完了で deeplink 層は WebView を動かさない
- Scaffold 契約: `lunarabi/lib/core/navigation/app_navigator.dart` の `HostGuard`, `AppNavigator.openDeepLink`
- package: `com.wandit.lunarabi`
- Spec: `docs/superpowers/specs/2026-08-11-lunarabi-webview-design.md`

---

### Task 1: Parser + replay bus

**Files:**
- Create: `lunarabi/lib/features/deeplink/deep_link_parser.dart`
- Create: `lunarabi/lib/features/deeplink/deep_link_bus.dart`
- Create: `lunarabi/test/features/deeplink/deep_link_parser_test.dart`
- Create: `lunarabi/test/features/deeplink/deep_link_bus_test.dart`

**Interfaces:**

```dart
enum DeepLinkKind { webPath, gmoComplete, unknown }

class ParsedDeepLink {
  const ParsedDeepLink({required this.kind, required this.uri});
  final DeepLinkKind kind;
  final Uri uri;
}

ParsedDeepLink parseDeepLink(Uri uri, HostGuard guard) {
  if (!guard.isAllowed(uri)) return ParsedDeepLink(kind: DeepLinkKind.unknown, uri: uri);
  if (uri.path == '/pay/gmo/complete') {
    return ParsedDeepLink(kind: DeepLinkKind.gmoComplete, uri: uri);
  }
  return ParsedDeepLink(kind: DeepLinkKind.webPath, uri: uri);
}

/// Broadcast bus that retains the latest event until the first listener
/// arrives (cold start), then behaves as a normal broadcast stream.
class DeepLinkBus {
  Stream<ParsedDeepLink> get stream;
  void publish(ParsedDeepLink link);
  Future<void> dispose();
}
```

- [ ] **Step 1: Failing tests**

Cases: https deep host webPath; https `/pay/gmo/complete` → gmoComplete; `http://...` unknown; `myapp://app.lunarabi.example/...` unknown; evil host unknown; bus publishes before listen then listener receives replay once.

- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

```bash
git add lunarabi/lib/features/deeplink lunarabi/test/features/deeplink
git commit -m "feat(lunarabi): add deep link parser and replay bus"
```

---

### Task 2: Wire app_links listener

**Files:**
- Create: `lunarabi/lib/features/deeplink/deep_link_listener.dart`
- Create: `lunarabi/test/features/deeplink/deep_link_listener_test.dart`
- Modify: `lunarabi/lib/main.dart`
- Modify: `lunarabi/pubspec.yaml`（`app_links`）

**Interfaces:**

```dart
class DeepLinkListener {
  Future<void> start({
    required AppNavigator navigator,
    required HostGuard guard,
    required DeepLinkBus bus,
    required AppLinks appLinks,
  });
}
```

Behavior:
1. Wait until navigator is ready（caller starts after `WebViewShell` creates navigator; pass via callback/completer from shell）
2. `getInitialLink` + `uriLinkStream`
3. parse → `bus.publish`
4. if `webPath` → `navigator.openDeepLink(uri)`
5. if `gmoComplete` → **do not** call navigator
6. if `unknown` → log only

- [ ] **Step 1: Fake AppLinks + Fake navigator tests for branches above**
- [ ] **Step 2: Implement + wire main**
- [ ] **Step 3: Commit**

```bash
git add lunarabi/lib lunarabi/test lunarabi/pubspec.yaml lunarabi/pubspec.lock
git commit -m "feat(lunarabi): wire app_links to AppNavigator"
```

---

### Task 3: Native HTTPS link placeholders

**Files:**
- Modify: `lunarabi/android/app/src/main/AndroidManifest.xml`
  - intent-filter: `android:autoVerify="true"`
  - actions `VIEW`, categories `DEFAULT` + `BROWSABLE`
  - data `android:scheme="https"` `android:host="app.lunarabi.example"`
- Modify: `lunarabi/ios/Runner/Runner.entitlements`
  - `applinks:app.lunarabi.example`
- Create: `lunarabi/docs/well-known/assetlinks.json.example`（package `com.wandit.lunarabi`, fingerprint `REPLACE_WITH_CERT_SHA256`）
- Create: `lunarabi/docs/well-known/apple-app-site-association.example`

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAMID.com.wandit.lunarabi",
      "paths": ["*"]
    }]
  }
}
```

- Modify: `lunarabi/README.md` with verification commands:

```bash
# Android (device)
adb shell pm get-app-links com.wandit.lunarabi
# iOS: open https://app.lunarabi.example/test on device and check Console for swcd / universal link
```

Note: package/bundle は全 flavor 同一。証明書指紋は debug/release で異なるため example に REPLACE を残す。

- [ ] **Step 1: Native config + examples + README**
- [ ] **Step 2: Commit**

```bash
git add lunarabi/android lunarabi/ios lunarabi/docs lunarabi/README.md
git commit -m "feat(lunarabi): add HTTPS App/Universal Link placeholders"
```

---

## Self-review checklist

- HTTPS enforced, HostGuard required, GMO no web nav, cold-start replay, native autoVerify + applinks
