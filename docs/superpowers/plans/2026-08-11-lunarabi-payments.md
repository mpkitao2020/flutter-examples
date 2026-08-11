# Lunarabi payments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 都度課金 3 手段（Store IAP consumable、GMO リンクトイプ、あおぞらバーチャル振込）のネイティブ導線とバックエンド port を実装する。

**Architecture:** Payment sheet → 各サービス。GMO 完了は `DeepLinkBus` の `gmoComplete`。振込は手動確認 1 回ずつ。秘密はアプリに入れない。

**Tech Stack:** `in_app_purchase`, `url_launcher`, existing `DeepLinkBus` / `AppNavigator` / `HostGuard`

**Branch:** `cursor/lunarabi-payments-c3bc`（base: deeplink マージ後の `develop`）

## Global Constraints

- Product id: `lunarabi.credit.100`（**consumable**）。復元 UI なし
- GMO complete URL 契約: `https://app.lunarabi.example/pay/gmo/complete?paymentId=<id>`
- PSP 秘密鍵・GMO ショップ認証情報をアプリ／`--dart-define` に入れない
- Aozora: 自動連続ポーリング禁止。ボタン 1 押下 = API 1 回
- 成功ナビ: `config.webBaseUrl.replace(path: '/pay/done')`
- Spec: `docs/superpowers/specs/2026-08-11-lunarabi-webview-design.md`

---

### Task 1: Domain + backend ports

**Files:**
- Create: `lunarabi/lib/features/payments/payment_models.dart`
- Create: `lunarabi/lib/features/payments/payment_backend_client.dart`
- Create: `lunarabi/test/features/payments/fake_payment_backend_test.dart`

**Interfaces:**

```dart
enum PaymentMethod { storeIap, gmoLink, aozoraTransfer }
enum PaymentStatus { idle, pending, success, failure }

class ProductRef {
  const ProductRef({required this.id, required this.displayName});
  final String id;
  final String displayName;
}

class GmoLinkSession {
  const GmoLinkSession({required this.paymentId, required this.checkoutUrl});
  final String paymentId;
  final Uri checkoutUrl;
}

class AozoraTransferSession {
  const AozoraTransferSession({
    required this.paymentId,
    required this.accountDisplay,
    required this.expiresAt,
  });
  final String paymentId;
  final String accountDisplay;
  final DateTime expiresAt;
}

abstract interface class PaymentBackendClient {
  Future<List<ProductRef>> listProducts();
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source, // app_store | google_play
  });
  Future<GmoLinkSession> createGmoLink({required String productId});
  Future<void> confirmGmo({required String paymentId});
  Future<AozoraTransferSession> createAozoraTransfer({required String productId});
  Future<PaymentStatus> checkBankTransfer({required String paymentId});
}

class FakePaymentBackendClient implements PaymentBackendClient {
  // listProducts → [ProductRef(id: 'lunarabi.credit.100', displayName: 'Credit 100')]
  // createGmoLink checkoutUrl:
  //   https://app.lunarabi.example/mock-gmo-checkout?paymentId=<id>
  // createAozoraTransfer accountDisplay: 'あおぞら銀行 999 支店 普通 1234567'
  // checkBankTransfer: first call pending, second success per paymentId
}
```

- [ ] **Step 1: Tests for fake sequencing and product id**
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

```bash
git add lunarabi/lib/features/payments lunarabi/test/features/payments
git commit -m "feat(lunarabi): add payment domain and backend ports"
```

---

### Task 2: Payment sheet UI

**Files:**
- Create: `lunarabi/lib/features/payments/payment_sheet.dart`
- Create: `lunarabi/test/features/payments/payment_sheet_test.dart`
- Modify: `lunarabi/lib/features/webview/webview_shell.dart` — AppBar action「購入」

**Interfaces:**
- Sheet lists product then three labels: `ストアで購入`, `クレジットカード (GMO)`, `銀行振込 (あおぞら)`

- [ ] **Step 1: Widget test asserts three method labels**
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

```bash
git add lunarabi/lib lunarabi/test
git commit -m "feat(lunarabi): add payment method sheet"
```

---

### Task 3: Store IAP (consumable)

**Files:**
- Create: `lunarabi/lib/features/payments/iap_purchase_service.dart`
- Create: `lunarabi/test/features/payments/iap_purchase_service_test.dart`
- Modify: `lunarabi/pubspec.yaml`

**Interfaces:**

```dart
class IapPurchaseService {
  Future<PaymentStatus> buy({
    required ProductRef product,
    required PaymentBackendClient backend,
  });
}
```

Behavior:
1. Query store product id == `product.id`
2. `buyConsumable`
3. On `purchased` only（not restore）: `confirmIap` then `completePurchase`
4. Errors → `PaymentStatus.failure`

- [ ] **Step 1: Test wrapper/fake purchase stream → confirm called; error → failure; no restore path**
- [ ] **Step 2: Implement**
- [ ] **Step 3: README** — Play/App Store に consumable `lunarabi.credit.100` を登録。復元ボタン無し。サンドボックス手順。iOS で GMO/振込も出すためガイドライン 3.1.1 リスクあり（合意済み）
- [ ] **Step 4: Commit**

```bash
git add lunarabi
git commit -m "feat(lunarabi): wire store IAP consumable purchase flow"
```

---

### Task 4: GMO link + deeplink complete

**Files:**
- Create: `lunarabi/lib/features/payments/gmo_link_payment.dart`
- Create: `lunarabi/test/features/payments/gmo_link_payment_test.dart`
- Modify: bootstrap in `main.dart` / shell to start GMO completer listening to bus
- Modify: `pubspec.yaml`（`url_launcher`）

**Interfaces:**

```dart
class GmoLinkPayment {
  Future<void> startCheckout({required String productId, required PaymentBackendClient backend});
  // listens:
  // bus.stream.where((l) => l.kind == DeepLinkKind.gmoComplete)
  Future<void> attachCompleter({
    required DeepLinkBus bus,
    required PaymentBackendClient backend,
    required AppNavigator navigator,
    required AppConfig config,
  });
}
```

Behavior:
1. `createGmoLink` → `launchUrl(checkoutUrl, mode: LaunchMode.externalApplication)`
2. On gmoComplete: `paymentId = uri.queryParameters['paymentId']`
3. If missing/empty → failure, **no** `confirmGmo`, no navigation
4. Else `confirmGmo` → `navigator.openDeepLink(config.webBaseUrl.replace(path: '/pay/done'))`

- [ ] **Step 1: Tests** — happy path; missing paymentId; bus event before attach still works if deeplink replay bus retained event（coordinate with DeepLinkBus semantics）
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

```bash
git add lunarabi
git commit -m "feat(lunarabi): add GMO link-type payment + deeplink complete"
```

---

### Task 5: Aozora virtual transfer (manual confirm)

**Files:**
- Create: `lunarabi/lib/features/payments/aozora_transfer_payment.dart`
- Create: `lunarabi/lib/features/payments/aozora_transfer_page.dart`
- Create: `lunarabi/test/features/payments/aozora_transfer_page_test.dart`

**Interfaces:**
- Page shows `accountDisplay` + button「入金を確認」
- Each tap → exactly one `checkBankTransfer`
- pending → stay on page with message
- success → open `/pay/done`
- failure → error message
- dispose cancels in-flight Future if any（no timer loops）

- [ ] **Step 1: Widget tests** — (a) first tap pending, second tap success navigates; (b) when fake returns `failure`, error message is shown and navigator is **not** called
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

```bash
git add lunarabi
git commit -m "feat(lunarabi): add Aozora virtual transfer manual confirm flow"
```

---

## Self-review checklist

- consumable only, GMO paymentId contract, no secrets, manual Aozora, deeplink bus subscription exact, README Store + guideline notes
