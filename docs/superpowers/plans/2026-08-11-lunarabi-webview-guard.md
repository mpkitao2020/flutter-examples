# Lunarabi WebView guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** WebView の通常遷移に HostGuard を強制し、外部リンク起動・Bridge 再注入・システム戻るを実装する。AppBar「購入」を削除する。

**Architecture:** `NavigationDelegate.onNavigationRequest` が唯一の遷移判定。許可ホストのみ WebView 継続。それ以外の http(s)/mailto/tel は外部起動。JS channel は初回前登録、許可ページ完了ごとに bootstrap 再注入。

**Tech Stack:** Flutter WebView, `url_launcher`, existing `HostGuard`

**Branch:** `cursor/lunarabi-webview-guard-c3bc`  
**Base:** `cursor/lunarabi-payments-followups-c3bc`

## Global Constraints

- Allowed hosts: `config.webBaseUrl.host` and `config.deepLinkHost`, scheme `https` only for in-app
- No AppBar back button
- No AppBar「購入」
- Android back / iOS swipe: WebView history then system exit
- Spec: `docs/superpowers/specs/2026-08-11-lunarabi-prod-hardening-design.md` §1

---

### Task 1: Navigation policy helper

**Files:**
- Create: `lunarabi/lib/features/webview/webview_navigation_policy.dart`
- Test: `lunarabi/test/features/webview/webview_navigation_policy_test.dart`

**Interfaces:**

```dart
enum WebViewNavAction { allow, openExternal, block }

class WebViewNavigationPolicy {
  WebViewNavigationPolicy(this.guard);
  final HostGuard guard;
  WebViewNavAction decide(Uri uri);
}
```

Rules:
- `https` + `guard.isAllowed` → allow
- `http`/`https` other → openExternal
- `mailto`/`tel` → openExternal
- else → block

- [ ] **Step 1: Write failing tests** for allow / external https / mailto / tel / custom scheme
- [ ] **Step 2: Run** `fvm flutter test test/features/webview/webview_navigation_policy_test.dart` → FAIL
- [ ] **Step 3: Implement policy**
- [ ] **Step 4: Run tests → PASS**
- [ ] **Step 5: Commit** `feat(lunarabi): add WebView navigation policy`

---

### Task 2: Wire onNavigationRequest + external launch

**Files:**
- Modify: `lunarabi/lib/features/webview/webview_shell.dart`
- Test: `lunarabi/test/features/webview/webview_shell_navigation_test.dart` (injectable launch fn / policy; avoid pumping real platform WebView if flaky — unit-test shell helper or controller fake)

**Behavior:**
- Inject `Future<bool> Function(Uri,{LaunchMode}) launchUrlFn` defaulting to `launchUrl`
- `onNavigationRequest`: switch on policy; `NavigationDecision.navigate` / `prevent`
- External: `LaunchMode.externalApplication`

- [ ] **Step 1: Failing test** — evil host calls launchUrlFn and prevents navigation
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit** `feat(lunarabi): enforce HostGuard on WebView navigations`

---

### Task 3: Bridge channel before load + reinject every page

**Files:**
- Modify: `lunarabi/lib/features/bridge/bridge_host.dart`
- Modify: `lunarabi/lib/features/webview/webview_shell.dart`
- Test: `lunarabi/test/features/bridge/bridge_host_test.dart`

**Behavior:**
- Split `attach` into `ensureChannel` (once) + `injectBootstrap` (every allowed page finish)
- Call `ensureChannel` before first `loadRequest`
- On each `onPageFinished`, reinject bootstrap + `bridge.ready`
- Remove `_bridgeAttached` early-return that blocks reinject

- [ ] **Step 1: Test** injectBootstrap can run twice without requiring second addJavaScriptChannel
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit** `fix(lunarabi): reinject bridge bootstrap on each page`

---

### Task 4: System back + remove purchase AppBar action

**Files:**
- Modify: `lunarabi/lib/features/webview/webview_shell.dart`
- Modify: `lunarabi/lib/main.dart` (remove onPurchasePressed wiring)
- Modify: `lunarabi/README.md`

**Behavior:**
- Wrap shell with `PopScope` / `WillPopScope` equivalent for Flutter 3.12+: if `await controller.canGoBack()` then `goBack()` and prevent pop; else allow pop
- Delete「購入」button and `onPurchasePressed` from shell API if unused
- Keep payment coordinator code for later IAP bridge branch (or leave dead until branch 4 cleans)

- [ ] **Step 1: Widget/unit test** for back decision helper if extracted
- [ ] **Step 2: Implement PopScope + remove purchase UI**
- [ ] **Step 3: `fvm flutter analyze lib test` + `fvm flutter test`**
- [ ] **Step 4: Commit** `feat(lunarabi): system-back WebView history; remove purchase AppBar`

---

## Self-review checklist

- [ ] Spec §1 navigation matrix covered
- [ ] Bridge reinject covered
- [ ] Purchase AppBar removed
- [ ] No AppBar back button added
