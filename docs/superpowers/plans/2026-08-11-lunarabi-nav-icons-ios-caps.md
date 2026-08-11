# Lunarabi nav SVG + iOS capabilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ボトムナビを差し替え可能な仮SVGにし、iOS の Associated Domains / Push entitlements を Runner ターゲットへ実際に接続する。

**Architecture:** Assets under `branding/nav/*.svg` loaded via `flutter_svg`. Xcode project sets `CODE_SIGN_ENTITLEMENTS` and adds `aps-environment` (+ background remote-notification if needed). Production APNs honesty in checklist.

**Tech Stack:** flutter_svg, Xcode pbxproj/entitlements/Info.plist

**Branch:** `cursor/lunarabi-nav-icons-ios-caps-c3bc`  
**Base:** after iap-bridge

## Global Constraints

- Tabs: home, search, notify, account
- Spec §5
- Do not claim production push works without real APNs/Firebase files
- Prefer Debug/Profile=`development`, Release=`production` entitlements; if single file only, document production APNs as **external release blocker**

---

### Task 1: Placeholder SVGs + pubspec assets

**Files:**
- Create: `lunarabi/branding/nav/home.svg`
- Create: `lunarabi/branding/nav/search.svg`
- Create: `lunarabi/branding/nav/notify.svg`
- Create: `lunarabi/branding/nav/account.svg`
- Modify: `lunarabi/pubspec.yaml` assets + `flutter_svg`
- Modify: `lunarabi/branding/README.md`
- Test: assert each path is listed under `flutter.assets` in pubspec (string/file test)

Simple monochrome 24x24 path icons are fine.

- [ ] **Step 1: Add SVGs and asset entries**
- [ ] **Step 2: Document replacement**
- [ ] **Step 3: Test** pubspec contains all four asset paths
- [ ] **Step 4: Commit** `feat(lunarabi): add placeholder bottom nav SVGs`

---

### Task 2: Bottom nav uses SVG

**Files:**
- Modify: `lunarabi/lib/features/bridge/bottom_nav_bar.dart`
- Test: `lunarabi/test/features/bridge/bottom_nav_bar_test.dart`

Map:

```dart
const navIcons = {
  NavTabId.home: 'branding/nav/home.svg',
  NavTabId.search: 'branding/nav/search.svg',
  NavTabId.notify: 'branding/nav/notify.svg',
  NavTabId.account: 'branding/nav/account.svg',
};
```

- [ ] **Step 1: Update widget test to find SvgPicture / asset AND assert NavTabId→path map covers all tabs with pubspec-registered paths**
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit** `feat(lunarabi): render bottom nav with SVG assets`

---

### Task 3: iOS entitlements attached + push keys

**Files:**
- Modify: `lunarabi/ios/Runner/Runner.entitlements` (and optionally `Runner.Release.entitlements`)
- Modify: `lunarabi/ios/Runner.xcodeproj/project.pbxproj`
- Modify: `lunarabi/ios/Runner/Info.plist`
- Modify: `lunarabi/README.md` device checklist

Preferred:

| Config | aps-environment |
|---|---|
| Debug / Profile | `development` |
| Release | `production` |

If Release-specific entitlements file is impractical in this branch, use `development` in the attached file and add checklist item: **「Release の aps-environment=production は未完了（external release blocker）」**.

Associated Domains remain:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:app.lunarabi.example</string>
</array>
```

pbxproj Debug/Release/Profile Runner configs:

```
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```
(or Release points to Release entitlements)

Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```

- [ ] **Step 1: Grep test or script asserting CODE_SIGN_ENTITLEMENTS and aps-environment exist**
- [ ] **Step 2: Apply pbxproj/plist/entitlements edits**
- [ ] **Step 3: Commit** `fix(ios): attach entitlements and enable push background mode`

---

### Task 4: Final hardening README checklist

**Files:**
- Modify: `lunarabi/README.md`
- Modify: `docs/superpowers/plans/2026-08-11-lunarabi-prod-hardening-README.md` if needed for external gates clarity

Checklist must **separate**:

**Flutter branch deliverables (code):**
- HostGuard WebView + bridge reinject + committed URL
- Secure auth + trusted origin
- FCM → Web
- IAP bridge + gated complete + durable recovery
- Nav SVG + entitlements attached

**External release gates (not done by Flutter tests):**
- Replace Firebase placeholders
- Real domains + AASA/assetlinks
- Release signing
- SPA frame/CSP policy for bridge
- Web: auth restore, FCM register API, IAP verify bridge
- Production `aps-environment` if not config-switched
- Japan external payment compliance still open for GMO/Aozora

- [ ] **Step 1: Write checklist with explicit External release gates section**
- [ ] **Step 2: `fvm flutter test` full**
- [ ] **Step 3: Commit** `docs(lunarabi): add production hardening checklist`

---

## Self-review checklist

- [ ] SVG paths swappable via branding/ + asset registration tests
- [ ] CODE_SIGN_ENTITLEMENTS present for Runner
- [ ] Production push honesty in checklist
- [ ] Spec §5 covered
