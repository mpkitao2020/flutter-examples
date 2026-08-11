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
| システム戻る | WebView履歴があれば戻る。なければ終了／バックグラウンド |
| ナビアイコン | 仮SVG4つ。差し替え可能パス |

## Architecture overview

```text
Web (SPA)
  ├─ 決済手段UI / GMO / あおぞら / FCM登録API / 購入検証API
  └─ Bridge post/get

Flutter
  ├─ WebView + HostGuard navigation
  ├─ Secure Storage (Sanctum token)
  ├─ FCM token → push.setToken
  ├─ Store IAP only
  └─ Bottom nav (SVG)
```

## Branch plan

| 順 | Branch | Deliverable |
|---|---|---|
| 1 | `cursor/lunarabi-webview-guard-c3bc` | navigation allowlist, external links, bridge reinject, system back |
| 2 | `cursor/lunarabi-auth-storage-c3bc` | Secure Storage auth persistence |
| 3 | `cursor/lunarabi-fcm-web-register-c3bc` | FCM to Web only |
| 4 | `cursor/lunarabi-iap-bridge-c3bc` | Web-started IAP + verify handoff |
| 5 | `cursor/lunarabi-nav-icons-ios-caps-c3bc` | nav SVG placeholders, iOS capabilities |

Base: each branch stacks on the previous after merge, starting from `cursor/lunarabi-payments-followups-c3bc`.

---

## 1. WebView boundary and Bridge

### Navigation rules

`NavigationDelegate.onNavigationRequest` evaluates every request:

| URI | Action |
|---|---|
| https and host in `{webBaseUrl.host, deepLinkHost}` | allow in WebView |
| other http/https | cancel + open external browser |
| `mailto:` / `tel:` | cancel + open external app |
| other schemes | cancel + log |

Deep links / push still use `HostGuard` + `AppNavigator`.

### Back navigation

- No AppBar back button
- Android system back / iOS interactive pop:
  - if WebView `canGoBack` → `goBack()`
  - else → default app exit / background

### Bridge lifecycle

1. Register JS channel before first `loadRequest`
2. On every allowed main-frame `onPageFinished`, reinject bootstrap JS
3. Emit `bridge.ready` with `{ platform }` after each reinject
4. Do not expose bridge behavior on non-allowed documents (navigation already blocked)

### Remove

- AppBar「購入」entry and native payment sheet launch from shell

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

### Security rules

- Return token only when current WebView URL host is allowed by HostGuard
- Web keeps token in memory only (not localStorage)
- Masked logs only
- Laravel must revoke token on logout; Web then clears native storage

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

### Web responsibilities

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

### Changes

- Remove production use of `LoggingPushBackendClient.register` as backend registration
- Keep latest token in `PushTokenStore`
- On `bridge.ready`, if token exists, resend `push.setToken`
- Do not block Web notification if a local logging helper fails

### iOS note

Capability wiring is in branch 5. Without it, token acquisition may fail on device.

---

## 4. Web-started Store IAP

### Scope

- Flutter handles Store IAP only
- GMO / Aozora remain Web-only for this phase
- Product id remains `lunarabi.credit.100` consumable unless Web sends another id

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

### Flow

1. Web shows methods; user picks IAP
2. Web posts `iap.start`
3. Flutter queries store product and starts consumable purchase
4. On purchased, Flutter emits `iap.purchaseUpdated` and waits for `iap.confirmResult`
5. Web calls Laravel verify API with Sanctum Bearer
6. Backend verifies with Apple/Google APIs, grants entitlement idempotently
7. Web posts `iap.confirmResult { ok: true }`
8. Flutter `completePurchase`, emits `iap.finished { completed }`
9. On cancel/error/confirm failure, emit finished failed/canceled and do not grant

### Pending recovery

- App-lifetime purchase stream observer
- On startup/resume, unfinished purchased txs emit `iap.purchaseUpdated` again
- Deduplicate by purchaseId
- Do not `completePurchase` until Web confirms ok

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

Existing placeholders remain:

- `branding/app_icon.png`
- `branding/splash.png` / `splash_dark.png`
- `branding/notification_icon.png`

### iOS capabilities

- Set `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`
- Keep Associated Domains entry
- Add `aps-environment` (development/production as appropriate per build)
- Add `UIBackgroundModes` → `remote-notification` if required for FCM background data

Android release signing and real Firebase files remain configuration tasks, not this design's code deliverable beyond removing debug-only assumptions where practical.

---

## Testing strategy

- Unit/widget: navigation allow/deny matrix, secure storage roundtrip, FCM bridge payload, IAP bridge state machine, pending recovery
- Contract tests: new BridgeTypes locked
- Manual device checklist in README: external links, token restore, FCM to Web, IAP sandbox

## Risks

- Bearer in Web memory is still XSS-sensitive; HostGuard reduces native exfiltration
- Without real backend verify API, IAP cannot ship
- Japan external payment compliance for GMO/Aozora remains a release blocker until later phase
- iOS signing/team still required for real device push

## Success criteria

- Untrusted origins cannot stay in WebView or read stored token
- Cold start restores Sanctum token only to allowed Web origin
- FCM token reaches Web without native backend register
- Web can start IAP with productId and complete only after verify ok
- Nav uses swappable SVG placeholders
- iOS entitlements are actually attached to the Runner target
