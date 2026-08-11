# Lunarabi 本番硬化デザイン（2026-08-11）

対象アプリ: `com.wandit.lunarabi`  
基準ブランチ: `cursor/lunarabi-payments-followups-c3bc`  
実装方式: 依存順の複数ブランチ（案2）

## Goal

敵対的検証で判明した本番阻止事項のうち、合意した範囲を閉じる。  
FCMはWeb登録、IAPはWeb起点、認証はSanctum BearerのSecure Storage復元、WebView境界を強制する。

## Non-goals（今回やらない）

- GMO／あおぞらのStore審査対応（日本向けExternal Purchases entitlement、開示、取引報告）
- 実Firebase／APNs鍵／実ドメイン差し替え作業そのもの
- Laravelバックエンド本体の実装
- Sanctum Cookie認証への移行
- AppBar「戻る」ボタン
- AppBar「購入」ボタン（削除する）

## Agreed product decisions

| 項目 | 決定 |
|---|---|
| 配信地域 | 日本のみ |
| 決済手段UI | Webが表示 |
| Store IAP | Webが`productId`を送りFlutterがStore画面を開く |
| 購入検証 | WebがAPIを呼ぶ。Flutterはレシート通知と`completePurchase` |
| GMO／あおぞら | Web完結。Flutter対象外（審査対応は別フェーズ） |
| FCM登録 | Flutter→Webへtoken通知。WebがAPI登録 |
| 認証 | Sanctum Bearer維持。Secure Storageへ保存 |
| token復元 | Webが`auth.getStoredToken`を要求 |
| 401 | Webが再ログイン＋Flutterへclear |
| 外部リンク | 許可ホスト以外のhttp(s)とmailto/telは外部起動 |
| システム戻る | Android: WebView履歴があれば戻る。なければ終了／バックグラウンド。iOS: AppBar戻るは無し。WebView の戻るジェスチャは WebKit 側に任せ、ネイティブシェルの interactive pop 要件は持たない |
| ナビアイコン | 仮SVG4つ。差し替え可能パス |

## Architecture overview

```text
Web (SPA)
  ├─ 決済手段UI / GMO / あおぞら / FCM登録API / 購入検証API
  └─ Bridge post/get

Flutter
  ├─ WebView + HostGuard navigation + committed main-frame URL state
  ├─ Secure Storage (Sanctum token) — trusted bridge origin only
  ├─ FCM token → push.setToken (PushService owns replay)
  ├─ Store IAP only (autoConsume:false; durable pending recovery)
  └─ Bottom nav (SVG)
```

## Branch plan

| 順 | Branch | Deliverable |
|---|---|---|
| 1 | `cursor/lunarabi-webview-guard-c3bc` | navigation allowlist, external links, bridge reinject, committed URL state, Android system back |
| 2 | `cursor/lunarabi-auth-storage-c3bc` | Secure Storage auth persistence + trusted-origin gate |
| 3 | `cursor/lunarabi-fcm-web-register-c3bc` | FCM to Web only + ready replay ownership |
| 4 | `cursor/lunarabi-iap-bridge-c3bc` | Web-started IAP + verify handoff + durable recovery |
| 5 | `cursor/lunarabi-nav-icons-ios-caps-c3bc` | nav SVG placeholders, iOS capabilities wiring |

Base: each branch stacks on the previous after merge, starting from `cursor/lunarabi-payments-followups-c3bc`.

---

## 1. WebView boundary and Bridge

### Navigation rules

`NavigationDelegate.onNavigationRequest` evaluates every **top-level** navigation request observable by `webview_flutter`:

| URI | Action |
|---|---|
| https and host in `{webBaseUrl.host, deepLinkHost}` | allow in WebView |
| other http/https | cancel + open external browser |
| `mailto:` / `tel:` | cancel + open external app |
| other schemes | cancel + log |

Deep links / push still use `HostGuard` + `AppNavigator`.

**Policy split (required):**

| Concern | Allowed set |
|---|---|
| In-WebView **top-level** navigation / deep-link input (observable by `webview_flutter`) | `{webBaseUrl.host, deepLinkHost}` via HostGuard |
| Trusted bridge origin (privileged bridge) | **Full origin from `webBaseUrl`**: scheme + host + effective port. `deepLinkHost` is **not** trusted unless identical to that origin |

Do **not** claim coverage of every subresource, iframe navigation, or POST that the platform may not surface to `onNavigationRequest`. Requirement is every **top-level** navigation the plugin reports.

### TrustedBridgeOrigin

```dart
bool isTrustedBridgeOrigin(Uri? committed, Uri webBaseUrl) {
  if (committed == null) return false;
  if (committed.scheme != webBaseUrl.scheme) return false;
  if (committed.host != webBaseUrl.host) return false;
  return committed.hasPort == webBaseUrl.hasPort
      ? committed.port == webBaseUrl.port
      : committed.port == webBaseUrl.port; // compare effective ports
}
```

**Privileged Web→Flutter** (must call `requireTrustedBridgeOrigin()` first; else `{ok:false,error:'forbidden_origin'}`):

- `auth.setBearerToken`, `auth.clearBearerToken`, `auth.getStoredToken`
- `push.getToken` (if exposed)
- `iap.start`, `iap.confirmResult`

**Privileged Flutter→Web** (emit only when committed URL is trusted; otherwise skip/log):

- `push.setToken` (including ready replay)
- `iap.purchaseUpdated`, `iap.finished`

**Bridge inject policy:** On non-trusted allowed pages (`deepLinkHost ≠ webBaseUrl` origin), either:

1. **Preferred:** do not inject bootstrap / do not emit `bridge.ready`, **or**
2. Inject a **reduced** bridge that cannot reach auth / push token / IAP handlers

Branch 1 must expose the committed-URL + `isTrustedBridgeOrigin` helper so branches 2–4 share one gate. Tests: `deepLinkHost != webBaseUrl.host` and same-host different-port both fail every privileged command and receive no sensitive events.

### Committed main-frame URL state

Branch 1 owns a navigation state object used by later privileged bridge:

- Clear committed URL on main-frame page start / navigation begin
- Set committed URL only after an **allowed** main-frame navigation is finished (`onPageFinished` for allowed https hosts)
- All privileged handlers read this object — not an ad-hoc `WebViewController` sync call
- Stale URL during in-flight navigation ⇒ treat as untrusted

### Back navigation

- No AppBar back button
- **Android** system back (`PopScope`): if WebView `canGoBack` → `goBack()` and prevent pop; else allow pop (exit / background)
- **iOS:** native shell does **not** claim interactive-pop parity. No AppBar back. Optional WebKit back-forward gestures may be enabled where supported, but acceptance is Android PopScope + no AppBar back

### Bridge lifecycle

1. Register JS channel before first `loadRequest` (`ensureChannel` once)
2. On every **trusted** main-frame `onPageFinished`, reinject full bootstrap + emit `bridge.ready` (or reinject reduced bridge on non-trusted allowed pages — see TrustedBridgeOrigin)
3. Do not load non-allowed documents in WebView (navigation already blocked)

### Bridge sender-origin limitation (release gate)

`webview_flutter` JavaScript channels do **not** expose a reliable per-message sender frame origin. Therefore:

1. Native applies **TrustedBridgeOrigin** to all privileged commands and sensitive events (not only token read)
2. **External release blocker (Web owner):** SPA must forbid untrusted third-party frames that can reach the native channel (no untrusted iframes; CSP / `frame-ancestors` as appropriate). Closing evidence required in checklist (CSP snippet or header dump + owner sign-off) — **not** marked done by Flutter tests alone

### External launch failure

- If `launchUrl` fails for external http(s)/mailto/tel, log and do not navigate in WebView
- Platform notes (Android package visibility / iOS URL schemes) documented in README

### Remove

- AppBar「購入」entry and native payment sheet launch from shell

### Frontend contract timing

- Create or import `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md` on the **first** branch that changes BridgeTypes (branch 2), then keep it current on branches 3–4
- Contract updates are part of each branch's testable deliverable; `bridge_contract_surface_test.dart` remains the Dart lock (manually aligned with the markdown)

---

## 2. Sanctum Bearer persistence

### Storage

- Package: `flutter_secure_storage`
- Key: single Sanctum personal access token string
- Memory cache optional; source of truth is Secure Storage

### Bridge types

| type | direction | purpose |
|---|---|---|
| `auth.setBearerToken` | Web → Flutter | persist token after login |
| `auth.clearBearerToken` | Web → Flutter | delete on logout / 401 |
| `auth.getStoredToken` | Web → Flutter | request restore after `bridge.ready` |
| `auth.getBearerToken` | remove or reject | no arbitrary readback |

`auth.getStoredToken` response (`bridge.response`):

```json
{ "ok": true, "token": "<token or null>" }
```

Forbidden origin:

```json
{ "ok": false, "error": "forbidden_origin" }
```

### Security rules

- **All** auth bridge commands (set / clear / getStored) require TrustedBridgeOrigin
- Tests must assert: trusted `webBaseUrl` origin may set/clear/read; distinct `deepLinkHost` and same-host different-port must not
- Web keeps token in memory only (not localStorage) — **external Web gate** (acceptance: manual steps + owner sign-off)
- Masked logs only
- Laravel must revoke token on logout; Web then clears native storage — **external gates**

### Startup

1. Web loads
2. Flutter emits `bridge.ready`
3. Web calls `auth.getStoredToken`
4. If token present, Web uses `Authorization: Bearer`
5. On 401, Web clears native token and shows login

---

## 3. FCM → Web registration

### Native responsibilities

- request permission
- getToken / onTokenRefresh
- foreground local notifications
- notification open routing via HostGuard
- notify Web via bridge

### Web responsibilities (external gate)

- receive `push.setToken`
- call backend registration API with auth when logged in
- optionally call `push.getToken` if missed

### Payload

```json
{
  "type": "push.setToken",
  "payload": {
    "token": "...",
    "platform": "ios"
  }
}
```

### Ownership: ready replay

- **PushService** owns publishing `push.setToken` (including platform)
- **BridgeHost** emits `bridge.ready` only on trusted pages (or after full bootstrap) and exposes `onReady`
- PushService registers for ready and, if token stored **and** committed URL is TrustedBridgeOrigin, publishes again
- Never replay token to `deepLinkHost`-only pages
- BridgeHost must **not** silently own token replay after branch 3 (single owner)
- Test: two trusted injectBootstraps ⇒ two ready + two push.setToken; non-trusted page ⇒ zero push.setToken

### Changes

- Remove production use of `LoggingPushBackendClient.register` as backend registration
- Keep latest token in `PushTokenStore`
- Do not block Web notification if a local logging helper fails

### iOS note

Capability wiring is in branch 5. Without it, token acquisition may fail on device.

---

## 4. Web-started Store IAP

### Scope

- Flutter handles Store IAP only
- GMO / Aozora remain Web-only for this phase
- **Native product allowlist (this phase):** only `lunarabi.credit.100`. Unknown `productId` ⇒ reject before opening Store sheet (tests required)
- Backend still enforces allowlist / package ids (out of app scope, release blocker)

### Bridge types

| type | direction | payload |
|---|---|---|
| `iap.start` | Web → Flutter | `{ productId }` |
| `iap.purchaseUpdated` | Flutter → Web | `{ productId, purchaseId, platform, verificationData, status }` |
| `iap.confirmResult` | Web → Flutter | `{ purchaseId, ok, error? }` |
| `iap.finished` | Flutter → Web | `{ purchaseId, status: completed\|failed\|canceled }` |

`status` in `purchaseUpdated`: `purchased` | `error` | `canceled`  
`platform`: `app_store` | `google_play`  
`verificationData`: Store `serverVerificationData`

### IAP store abstraction

- Extend `IapStore.buyConsumable` to pass **`autoConsume: false`** on Android (or equivalent plugin API) so the Store cannot consume before Web verification
- Tests assert: no `completePurchase` and no consume before matching `iap.confirmResult.ok == true`
- On `ok:false` / timeout / cancel / error: **do not** `completePurchase` and **do not** consume; leave transaction unfinished for recovery (no “complete if store requires” ambiguity)

### Flow

1. Web shows methods; user picks IAP
2. Web posts `iap.start`
3. Flutter allowlists productId, queries store product, starts consumable with auto-consume disabled
4. On purchased, Flutter persists pending state, emits `iap.purchaseUpdated`, waits for `iap.confirmResult`
5. Web calls Laravel verify API with Sanctum Bearer
6. Backend verifies with Apple/Google APIs, grants entitlement idempotently
7. Web posts `iap.confirmResult { ok: true }`
8. Flutter `completePurchase`, clears pending, emits `iap.finished { completed }`
9. On cancel/error/confirm failure/timeout: emit finished failed/canceled, keep unfinished purchased txs for recovery, do not grant

### Durable pending recovery

Persisted pending record (Secure Storage or equivalent durable store):

| Field | Purpose |
|---|---|
| `purchaseKey` | Stable key: `purchaseID` if non-null, else `{platform}:{productId}:{serverVerificationData}` |
| `purchaseId` | Store purchaseID when present (may be null historically) |
| `productId` | Store product |
| `platform` | `app_store` / `google_play` |
| `verificationData` | serverVerificationData |
| `status` | last known (`purchased` waiting confirm, etc.) |
| `waitingConfirm` | bool |
| `updatedAt` | diagnostics |

**PurchaseDetails rehydration:**

- `completePurchase` requires a live Store `PurchaseDetails`
- On restart: match durable pending to unfinished Store stream txs by `purchaseKey`
- If only durable record exists (Store has not re-emitted yet): re-emit `iap.purchaseUpdated` for Web verify, but **do not** complete until a live Store transaction is matched
- Dedupe emits by `purchaseKey`

**confirmResult rules:**

- Matching `ok:true` → complete exactly once, then remove pending
- Duplicate `ok:true` after completion → bridge error; no second complete
- Stale confirm (pending removed / unknown key) → bridge error; never complete
- Late `ok` after timeout → if pending still waiting and live Store tx present, treat as first ok; if already finished failed and pending kept, documented: accept ok only while `waitingConfirm` and live tx matched; else error
- Confirm before waiting-confirm state → error; never complete

Behavior:

- App-lifetime purchase stream observer starts at app start (not per-buy)
- On **startup** and **resume**: load durable pending + unfinished Store txs; emit `iap.purchaseUpdated` again (dedupe by purchaseKey)
- After Web reload: when trusted `bridge.ready` fires while waiting confirm, re-emit for pending purchased txs
- `iap.start` / `iap.confirmResult` / receipt emits require TrustedBridgeOrigin
- Never `completePurchase` until Web confirms ok **and** live Store tx is available

### Bridge dispatch wiring (no cyclic globals)

Construction order:

1. Build `BridgeHost` without IAP controller
2. Build `IapBridgeController` with `BridgeHost` + IAP services
3. Register IAP handler via `BridgeHost.registerHandler(prefix: 'iap.', handler: controller.handleFromJs)` (or equivalent command router)
4. Start lifetime observer from `main` / AppServices after construction

Tests: `iap.start` JS message reaches controller; non-IAP messages still use existing handlers.

### Backend expectations (out of app scope, required for prod)

- Verify receipt/purchase token with Apple/Google
- Bind to authenticated user
- Enforce product allowlist and package/bundle id
- Idempotent grant by purchase token / original transaction id
- Handle refunds/revocations later

---

## 5. Nav SVG and iOS capabilities

### Bottom nav icons

Tabs: `home`, `search`, `notify`, `account`

Placeholder SVGs:

```text
lunarabi/branding/nav/home.svg
lunarabi/branding/nav/search.svg
lunarabi/branding/nav/notify.svg
lunarabi/branding/nav/account.svg
```

Use a Flutter SVG loader (`flutter_svg` or equivalent). README documents replacement.  
Tests assert pubspec asset registration + each `NavTabId` maps to a declared path.

Existing placeholders remain:

- `branding/app_icon.png`
- `branding/splash.png` / `splash_dark.png`
- `branding/notification_icon.png`

### iOS capabilities

- Set `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`
- Keep Associated Domains entry
- `aps-environment`:
  - Debug/Profile → `development`
  - Release → `production` via config-specific entitlements **or** xcconfig substitution
  - If only a single entitlements file is practical in this branch, attach `development` for device testing and list **production APNs entitlements** as an explicit **external release blocker** in the final checklist (do not claim production push is wired)
- Add `UIBackgroundModes` → `remote-notification` if required for FCM background data

Android release signing and real Firebase files remain configuration tasks, not this design's code deliverable beyond removing debug-only assumptions where practical.

---

## External release gates (not satisfied by Flutter-only tests)

Owner: Web / DevOps / Store compliance (outside this repo's Flutter branches)

Each gate needs an **acceptance artifact** in the final checklist (not just a label): evidence field + owner + date.

| Gate | Acceptance artifact |
|---|---|
| SPA forbids untrusted frames / CSP for bridge page | CSP header dump or `frame-ancestors` / iframe policy snippet + owner sign-off |
| Web: token memory-only; getStoredToken after ready; clear on 401 | Manual test steps logged + owner sign-off |
| Web: FCM registration API on `push.setToken` | Endpoint name + manual or staging log + owner sign-off |
| Web/Laravel: IAP verify API + idempotent grant | Endpoint name + sandbox verify log + owner sign-off |
| Real Firebase / APNs / domains / AASA / assetlinks / release signing | Config checklist ticks |
| Production `aps-environment` if not config-switched in branch 5 | Entitlements screenshot or pbxproj Release value |
| Japan GMO/Aozora Store compliance | Separate phase tracker |

## Testing strategy

- Unit/widget: navigation allow/deny matrix (incl. launch failure), secure storage roundtrip + trusted-origin split, FCM bridge payload + double ready replay, IAP allowlist + autoConsume false + complete gated + durable recovery + ready re-emit
- Contract tests: new BridgeTypes locked
- Manual / external checklist in README — labeled **external gates**, not “passed”

## Risks

- Bearer in Web memory is still XSS-sensitive; trusted-origin gate + no untrusted frames reduce native exfiltration
- Without real backend verify API, IAP cannot ship
- Japan external payment compliance for GMO/Aozora remains a release blocker until later phase
- iOS signing/team still required for real device push

## Success criteria

- Untrusted origins cannot stay in WebView; stored token readable only from trusted bridge origin (`webBaseUrl`)
- Cold start restores Sanctum token only under that gate
- FCM token reaches Web without native backend register; ready replay owned by PushService
- Web can start IAP with allowlisted productId; no complete/consume before verify ok; durable recovery across process death and Web reload
- Nav uses swappable SVG placeholders with asset registration tests
- iOS entitlements are attached to the Runner target; production APNs status is honest in the checklist
