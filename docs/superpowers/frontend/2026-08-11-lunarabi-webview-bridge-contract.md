# Lunarabi WebView bridge contract

This contract is the shared surface between the Lunarabi SPA and the Flutter
WebView shell. Flutter locks the type list in
`lunarabi/test/features/bridge/bridge_contract_surface_test.dart`.

## Transport

Web calls Flutter with JSON:

```js
window.LunarabiBridge.post({
  type: "auth.getStoredToken",
  requestId: "req-1",
  payload: {}
});
```

Flutter calls Web with:

```js
window.__LUNARABI_NATIVE_EVENT__(msg);
```

Requests that need a reply must include `requestId`. Flutter replies with
`bridge.response` using the same `requestId`.

## Type list

| type | direction | notes |
|---|---|---|
| `nav.setVisible` | Web to Flutter | Show or hide native bottom nav. |
| `nav.setBadge` | Web to Flutter | Set a tab badge count. |
| `nav.setActive` | Web to Flutter | Mark the active native tab. |
| `nav.tabSelected` | Flutter to Web | User selected a native tab. |
| `auth.setBearerToken` | Web to Flutter | Save the Sanctum Bearer token. Trusted origin required. |
| `auth.clearBearerToken` | Web to Flutter | Clear the saved token on logout or 401. Trusted origin required. |
| `auth.getStoredToken` | Web to Flutter | Read the saved token after `bridge.ready`. Trusted origin required. |
| `push.setToken` | Flutter to Web | Native push token event with platform. Sensitive event, trusted origin required before release. |
| `push.getToken` | Web to Flutter | Optional missed-token request. Privileged if exposed. |
| `iap.start` | Web to Flutter | Start native IAP for an allowlisted product. Trusted origin required. |
| `iap.purchaseUpdated` | Flutter to Web | Native purchase receipt for Web verification. Trusted origin required before emit. |
| `iap.confirmResult` | Web to Flutter | Web verification result for a pending purchase. Trusted origin required. |
| `iap.finished` | Flutter to Web | Terminal native IAP result. Trusted origin required before emit. |
| `bridge.ready` | Flutter to Web | Full bridge bootstrap is ready on the trusted origin. |
| `bridge.response` | Flutter to Web | Reply envelope for request/response calls. |

`auth.getBearerToken` is not part of the frontend contract. If an older page
sends it, Flutter rejects it.

## Auth messages

`auth.setBearerToken`

```json
{
  "type": "auth.setBearerToken",
  "payload": { "token": "sanctum-token" }
}
```

`auth.clearBearerToken`

```json
{ "type": "auth.clearBearerToken", "payload": {} }
```

`auth.getStoredToken`

```json
{
  "type": "auth.getStoredToken",
  "requestId": "auth-restore-1",
  "payload": {}
}
```

Success response:

```json
{
  "type": "bridge.response",
  "requestId": "auth-restore-1",
  "payload": { "ok": true, "token": "sanctum-token-or-null" }
}
```

Forbidden origin response:

```json
{
  "type": "bridge.response",
  "requestId": "auth-restore-1",
  "payload": { "ok": false, "error": "forbidden_origin" }
}
```

## Push messages

`push.setToken`

```json
{
  "type": "push.setToken",
  "payload": {
    "token": "fcm-token",
    "platform": "ios"
  }
}
```

`platform` is `ios` or `android`.

After each trusted `bridge.ready`, Flutter replays any stored FCM token as
`push.setToken`. Allowed but non-trusted pages do not receive this replay.

## IAP messages

The native shell exposes Web-started IAP through bridge messages only. Web asks
Flutter to start an allowlisted product, Flutter emits the Store receipt to Web,
Web verifies it with the backend, then Web sends the verification result back to
Flutter before native completion/consume.

IAP message types:

- `iap.start`
- `iap.purchaseUpdated`
- `iap.confirmResult`
- `iap.finished`

All IAP messages are privileged. `iap.start`, `iap.confirmResult`, and every
Flutter emit of `iap.purchaseUpdated` / `iap.finished` require the committed
main-frame URL to match the trusted bridge origin.

## Trusted origin rule

Flutter treats a page as bridge-trusted only when the committed main-frame URL
matches `webBaseUrl` by scheme, host, and effective port. `deepLinkHost` may be
allowed for top-level WebView navigation, but it is not bridge-trusted unless it
is the same origin as `webBaseUrl`.

The committed URL is cleared during in-flight navigation. While it is null,
Flutter rejects privileged messages with `forbidden_origin`.

Privileged Web to Flutter messages must call the trusted-origin gate before any
payload handling:

- `auth.setBearerToken`
- `auth.clearBearerToken`
- `auth.getStoredToken`
- future `push.getToken`
- future `iap.start`
- future `iap.confirmResult`

Sensitive Flutter to Web messages must only be emitted to trusted pages:

- `bridge.ready` after full bootstrap
- `push.setToken`
- future IAP receipt or completion events

## Web release gates

The native channel cannot identify the sender frame for each JavaScript channel
message. The SPA must prevent untrusted frames from reaching the bridge.

Required artifacts before release:

| gate | acceptance artifact fields |
|---|---|
| No untrusted frames can reach the bridge page | `evidence` CSP header dump or frame policy snippet, `owner`, `date`, `signOff` |
| Token stays in memory only | `evidence` manual test steps or code review link, `owner`, `date`, `signOff` |
| Web calls `auth.getStoredToken` after `bridge.ready` | `evidence` manual or staging trace, `owner`, `date`, `signOff` |
| Web clears native token on logout and 401 | `evidence` manual or staging trace, `owner`, `date`, `signOff` |

