# Lunarabi prod payment HTTP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** release の `FailClosedPaymentBackendClient` をやめ、GMO complete ディープリンクとあおぞら確認が実 API を叩ける `HttpPaymentBackendClient` を配線する。ネイティブ決済シートは復活させない。

**Architecture:** `PaymentBackendClient` に HTTP 実装を追加。Bearer は `AuthTokenRepository.read()`。ベース URL は `AppConfig.apiBaseUrl`。IAP の Store 検証は Web bridge のままなので、`confirmIap` は HTTP でも **呼ばない／呼んでもサーバが no-op** でよい（ネイティブ IAP 経路は `IapBridgeController`）。GMO/あおぞらはディープリンク完了と Web 起点フロー用。

**Tech Stack:** `http` package (add if missing), existing `PaymentBackendClient`, `AuthTokenRepository`

**Branch:** `cursor/lunarabi-prod-payment-http-c3bc`  
**Base:** after prod-secrets-signing

## Global Constraints

- Do not restore AppBar「購入」
- Product id for credits remains `lunarabi.credit.100` where listing is used
- Endpoint paths (exact, relative to `apiBaseUrl`):
  - `POST /v1/payments/gmo/sessions` → `{ paymentId, checkoutUrl }`
  - `POST /v1/payments/gmo/confirm` body `{ paymentId }`
  - `POST /v1/payments/aozora/sessions` → `{ paymentId, accountDisplay, expiresAt }`
  - `POST /v1/payments/aozora/check` body `{ paymentId }` → `{ status: pending|success|failure }`
  - `GET /v1/payments/products` → `{ products: [{ id, displayName }] }`
- Authorization header: `Authorization: Bearer <token>` when token non-null; if null, still call and let API 401
- Spec: prod-readiness design; IAP verify stays Web-owned

---

### Task 1: HttpPaymentBackendClient + tests

**Files:**
- Create: `lunarabi/lib/features/payments/http_payment_backend_client.dart`
- Test: `lunarabi/test/features/payments/http_payment_backend_client_test.dart`
- Modify: `lunarabi/pubspec.yaml`（`http` が無ければ追加）

**Interfaces:**

```dart
class HttpPaymentBackendClient implements PaymentBackendClient {
  HttpPaymentBackendClient({
    required Uri apiBaseUrl,
    required AuthTokenRepository authRepo,
    http.Client? client,
  });

  // confirmIap: throws UnsupportedError('IAP verify is owned by Web bridge')
}
```

Use `http.Client` fake / `MockClient` pattern:

```dart
test('confirmGmo posts paymentId with bearer', () async {
  http.Request? seen;
  final client = MockClient((request) async {
    seen = request;
    return http.Response('{}', 200);
  });
  final repo = _MemAuth()..token = 'tok';
  final backend = HttpPaymentBackendClient(
    apiBaseUrl: Uri.parse('https://api.lunarabi.jp'),
    authRepo: repo,
    client: client,
  );
  await backend.confirmGmo(paymentId: 'gmo-1');
  expect(seen!.url.path, '/v1/payments/gmo/confirm');
  expect(seen!.headers['Authorization'], 'Bearer tok');
});
```

- [ ] **Step 1: Failing tests** for confirmGmo, createGmoLink JSON parse, checkBankTransfer status map, confirmIap unsupported
- [ ] **Step 2: Implement client**
- [ ] **Step 3: Commit** `feat(lunarabi): add HttpPaymentBackendClient for GMO/Aozora API`

---

### Task 2: Wire AppServices for release

**Files:**
- Modify: `lunarabi/lib/core/app_services.dart`
- Modify: `lunarabi/lib/main.dart`（config を渡して backend を構築する必要があれば `LunarabiApp` 側で注入）
- Test: widget/unit that release path is not FailClosed when factory used — prefer pure factory test

**Wiring rule:**

```dart
static PaymentBackendClient createPaymentBackend({
  required AppConfig config,
  required AuthTokenRepository authRepo,
  required bool isRelease,
}) {
  if (!isRelease) {
    return FakePaymentBackendClient();
  }
  return HttpPaymentBackendClient(
    apiBaseUrl: config.apiBaseUrl,
    authRepo: authRepo,
  );
}
```

Replace static final `paymentBackend` with lazy/factory called from `_ensurePayments` using current `_config`, so flavor switch updates API base.

- [ ] **Step 1: Failing test** factory returns Http in release-like flag / Fake otherwise
- [ ] **Step 2: Implement wiring; update GmoLinkPayment construction sites**
- [ ] **Step 3: Full `fvm flutter test`**
- [ ] **Step 4: Commit** `feat(lunarabi): use HTTP payment backend in release`

---

### Task 3: Document Laravel contract + FailClosed retirement

**Files:**
- Modify: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`（payments HTTP 節を追加）
- Modify: `lunarabi/README.md` — FailClosed 記述を削除／「release は HttpPaymentBackendClient」に更新
- Keep `FailClosedPaymentBackendClient` class for tests that assert fail-closed behavior if still useful, or mark `@visibleForTesting` unused

- [ ] **Step 1: Write endpoint table in contract doc**
- [ ] **Step 2: README update**
- [ ] **Step 3: Commit** `docs: payment HTTP contract for GMO/Aozora`

---

## Self-review checklist

- [ ] Release GMO confirm no longer FailClosed
- [ ] No AppBar purchase restored
- [ ] IAP still Web-verified (confirmIap not used for Store path)
- [ ] Bearer from Secure Storage repo
