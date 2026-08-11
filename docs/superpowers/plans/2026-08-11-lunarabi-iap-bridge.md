# Lunarabi IAP Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web が表示した決済手段から IAP のみを Bridge 経由で開始し、検証は Web/API、成功後に Flutter が completePurchase する。

**Architecture:** `IapBridgeController` listens for `iap.start`, runs store purchase, emits `iap.purchaseUpdated`, waits for `iap.confirmResult`, then completes and emits `iap.finished`. App-lifetime purchase stream recovers pending txs. GMO/Aozora stay Web-only; remove native payment sheet entry (already removed in guard branch).

**Tech Stack:** in_app_purchase, BridgeHost, existing IapPurchaseService (refactor)

**Branch:** `cursor/lunarabi-iap-bridge-c3bc`  
**Base:** after fcm-web-register

## Global Constraints

- Product id from Web (`lunarabi.credit.100` typical)
- Consumable only; no restore UI
- completePurchase only after `iap.confirmResult.ok == true`
- Spec §4

---

### Task 1: Bridge message types for IAP

**Files:**
- Modify: `lunarabi/lib/features/bridge/bridge_message.dart`
- Test: `lunarabi/test/features/bridge/bridge_contract_surface_test.dart`
- Update: frontend contract doc

```dart
static const iapStart = 'iap.start';
static const iapPurchaseUpdated = 'iap.purchaseUpdated';
static const iapConfirmResult = 'iap.confirmResult';
static const iapFinished = 'iap.finished';
```

- [ ] **Step 1: Extend `BridgeTypes.all` and failing contract test**
- [ ] **Step 2: Commit** `feat(lunarabi): add IAP bridge message types`

---

### Task 2: IapBridgeController state machine

**Files:**
- Create: `lunarabi/lib/features/payments/iap_bridge_controller.dart`
- Test: `lunarabi/test/features/payments/iap_bridge_controller_test.dart`

**Interfaces:**

```dart
class IapBridgeController {
  IapBridgeController({
    required IapPurchaseService iap,
    required BridgeHost bridge,
  });

  Future<void> handleFromJs(BridgeMessage message);
  Future<void> startPurchaseStream(); // app lifetime
}

// iap.start payload: { productId: String }
// iap.purchaseUpdated: { productId, purchaseId, platform, verificationData, status }
// iap.confirmResult: { purchaseId, ok: bool, error?: String }
// iap.finished: { purchaseId, status: completed|failed|canceled }
```

Behavior:
1. On `iap.start`, begin buy for productId
2. On store purchased, emit purchaseUpdated and wait for matching confirmResult (timeout e.g. 2 min)
3. ok true → completePurchase → finished completed
4. ok false / timeout → do not complete (or complete only if store requires; prefer leave unfinished for retry) → finished failed
5. canceled/error → finished canceled/failed without waiting confirm

- [ ] **Step 1: Failing tests** happy path, cancel, confirm false, timeout
- [ ] **Step 2: Implement controller (refactor IapPurchaseService to expose stream events if needed)**
- [ ] **Step 3: Commit** `feat(lunarabi): add IapBridgeController`

---

### Task 3: Lifetime purchase observer + wire main/bridge

**Files:**
- Modify: `iap_purchase_service.dart` to support app-lifetime listen API
- Modify: `bridge_host.dart` dispatch `iap.*`
- Modify: `main.dart` start observer after app start
- Remove unused PaymentCoordinator sheet path / Fake-only UX if still present for IAP entry
- README: Web must implement verify API + bridge handlers

- [ ] **Step 1: Test** pending purchase on startup emits purchaseUpdated
- [ ] **Step 2: Wire**
- [ ] **Step 3: Full test suite**
- [ ] **Step 4: Commit** `feat(lunarabi): wire Web-started IAP with verify handoff`

---

### Task 4: Frontend contract update

**Files:**
- Create/Update: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md` (merge prior + auth/fcm/iap)

Include example JS for:
- getStoredToken after ready
- push.setToken handler → API register
- iap.start / purchaseUpdated / confirmResult / finished

- [ ] **Step 1: Write contract sections**
- [ ] **Step 2: Commit** `docs: update bridge contract for auth, FCM, IAP`

---

## Self-review checklist

- [ ] No native payment sheet required for IAP
- [ ] completePurchase gated on Web ok
- [ ] Pending recovery present
- [ ] Spec §4 covered
