# Lunarabi payments adversarial follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 敵対的レビュー 2 回目で残った Important / Minor を閉じ、GMO attach 競合・ID セット肥大・release 時 Fake 課金・あおぞらナビ失敗テストを修正する。

**Architecture:** payments ブランチ上の follow-up。`LunarabiApp` で GMO dispose→attach を単一 Future チェーンに串刺しし、IAP/GMO の handled 集合は FIFO 上限付き。release は fail-closed backend。あおぞら navigate 失敗は Widget テストで固定。

**Tech Stack:** 既存 Flutter / FVM 3.44.9、`DeepLinkBus`、`PaymentBackendClient`

**Branch:** `cursor/lunarabi-payments-followups-c3bc`（base: `cursor/lunarabi-payments-c3bc`）

## Global Constraints

- 既存 payments 契約を壊さない（consumable ID、GMO URL、手動あおぞら、秘密をアプリに入れない）
- Fake backend は debug/profile のみ。release は confirm / session 作成を失敗させる
- 二重 GMO listener を作らない
- テストは日本語コメント方針を維持

## Scope（レビュー残件 → 本プラン）

| レビュー指摘 | 対応 |
|---|---|
| GMO attach が `_ensurePayments` 返却前に未完了 | Task 1: attach Future を await 可能に |
| flavor 切替で listener 二重の余地 | Task 1: 直列キュー |
| `_handledPurchaseKeys` 無制限増加 | Task 2: FIFO cap |
| GMO `_handledPaymentIds` 同様 | Task 2: 同じ util |
| release でも Fake confirm no-op | Task 3: fail-closed |
| あおぞら `openDeepLink` 失敗で `_busy` 解除が未テスト | Task 4: Widget テスト |

既に payments hardening で閉じたもの（本プラン対象外）:
- purchased 二重 confirm / backlog 誤成功 / paymentId trim・dup / navigate 後の re-confirm / DeepLinkBus buffer

## File map

| File | Role |
|---|---|
| `lunarabi/lib/features/payments/handled_id_set.dart` | FIFO 上限付き ID 集合 |
| `lunarabi/lib/features/payments/iap_purchase_service.dart` | handled を cap 付きに |
| `lunarabi/lib/features/payments/gmo_link_payment.dart` | 同上 |
| `lunarabi/lib/features/payments/payment_backend_client.dart` | `FailClosedPaymentBackendClient` |
| `lunarabi/lib/core/app_services.dart` | release → fail-closed |
| `lunarabi/lib/main.dart` | GMO rebind 直列 Future |
| `lunarabi/test/features/payments/*` | 単体・Widget |
| `lunarabi/README.md` | fail-closed 注記 |

---

### Task 1: Serialize GMO dispose → attach

**Files:**
- Modify: `lunarabi/lib/main.dart`
- Create: `lunarabi/test/features/payments/gmo_rebind_serialization_test.dart`（純 Dart で Future チェーン検証が難しければ GmoLinkPayment + bus の attach 完了待機ヘルパを main から抽出）

**Approach:**
- `_gmoAttachChain`（`Future<void>`）をフィールドに持ち、rebind は常に  
  `_gmoAttachChain = _gmoAttachChain.then((_) async { await previous?.dispose(); await next.attachCompleter(); })`
- `_ensurePayments` は coordinator を返すが、`openPurchase` / `_onNavigatorReady` は `await _gmoAttachChain` してから GMO 依存処理へ
- 抽出が必要なら `GmoCompleterBinder` 小さなクラスに閉じる

- [ ] **Step 1:** 失敗するテスト — dispose 完了前に第二 listener が付かないこと（bus 経由で confirm が 1 回）
- [ ] **Step 2:** `_gmoAttachChain` 実装
- [ ] **Step 3:** `fvm flutter test` 対象テスト
- [ ] **Step 4:** Commit `fix(lunarabi): serialize GMO completer rebind`

---

### Task 2: Cap handled ID sets

**Files:**
- Create: `lunarabi/lib/features/payments/handled_id_set.dart`
- Modify: `iap_purchase_service.dart`, `gmo_link_payment.dart`
- Create: `lunarabi/test/features/payments/handled_id_set_test.dart`

**Interface:**

```dart
class HandledIdSet {
  HandledIdSet({this.maxSize = 64});
  final int maxSize;
  bool contains(String id);
  void add(String id); // FIFO drop oldest when over max
  bool remove(String id);
}
```

- [ ] **Step 1:** maxSize 超過で最古が消えるテスト
- [ ] **Step 2:** 実装して IAP/GMO に差し替え
- [ ] **Step 3:** Commit `fix(lunarabi): cap payment handled-id sets`

---

### Task 3: Fail-closed backend in release

**Files:**
- Modify: `payment_backend_client.dart`, `app_services.dart`, `README.md`
- Create: `lunarabi/test/features/payments/fail_closed_payment_backend_test.dart`

**Behavior:**
- `FailClosedPaymentBackendClient`
  - `listProducts` → 空リスト（UI で購入不可）
  - `confirmIap` / `confirmGmo` / `createGmoLink` / `createAozoraTransfer` → `StateError('PaymentBackendClient not configured')`
  - `checkBankTransfer` → `PaymentStatus.failure`
- `AppServices.paymentBackend`: `kReleaseMode ? FailClosed... : Fake...`
- テストでは Fake / FailClosed を明示注入（AppServices に依存しない）

- [ ] **Step 1:** FailClosed 契約テスト
- [ ] **Step 2:** AppServices + README
- [ ] **Step 3:** Commit `fix(lunarabi): fail-closed payment backend in release`

---

### Task 4: Aozora navigate-failure test

**Files:**
- Modify: `lunarabi/test/features/payments/aozora_transfer_page_test.dart`

**Case:** Fake navigator `openDeepLink` throws → message `完了画面を開けませんでした`、ボタン再有効（`_busy` clear）

- [ ] **Step 1:** 失敗する Widget テスト
- [ ] **Step 2:** 既存実装で通ることを確認（足りなければ page 修正）
- [ ] **Step 3:** Commit `test(lunarabi): cover Aozora navigate failure busy reset`

---

## Self-review checklist

- [ ] GMO listener が同時に 2 本立たない
- [ ] release で Fake confirm no-op にならない
- [ ] handled set が無制限に増えない
- [ ] `fvm flutter analyze` / `fvm flutter test` green
