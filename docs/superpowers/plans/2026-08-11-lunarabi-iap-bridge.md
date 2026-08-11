# Lunarabi IAP Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web が表示した決済手段から IAP のみを Bridge 経由で開始し、検証は Web/API、成功後に Flutter が completePurchase する。Android auto-consume 禁止。durable pending recovery。

**Architecture:** `IapBridgeController` registers on BridgeHost command router, runs store purchase with `autoConsume: false`, emits `iap.purchaseUpdated`, waits for `iap.confirmResult`, then completes and emits `iap.finished`. App-lifetime purchase stream + durable pending store recover after process death and Web reload. Native allowlist: `lunarabi.credit.100` only this phase.

**Tech Stack:** in_app_purchase, BridgeHost, existing IapPurchaseService (refactor)

**Branch:** `cursor/lunarabi-iap-bridge-c3bc`  
**Base:** after fcm-web-register

## Global Constraints

- Native allowlist: only `lunarabi.credit.100` (reject others before Store sheet)
- Consumable only; no restore UI
- `completePurchase` **and** consume only after `iap.confirmResult.ok == true` **and** live Store `PurchaseDetails` matched
- On ok:false / timeout / cancel / error: **never** complete or consume; leave unfinished for recovery
- `iap.start`, `iap.confirmResult`, and emits of `iap.purchaseUpdated` / `iap.finished` require TrustedBridgeOrigin
- Spec §4

---

### Task 1: Bridge message types for IAP

**Files:**
- Modify: `lunarabi/lib/features/bridge/bridge_message.dart`
- Test: `lunarabi/test/features/bridge/bridge_contract_surface_test.dart`
- Update: frontend contract doc (iap section)

```dart
static const iapStart = 'iap.start';
static const iapPurchaseUpdated = 'iap.purchaseUpdated';
static const iapConfirmResult = 'iap.confirmResult';
static const iapFinished = 'iap.finished';
```

- [ ] **Step 1: Extend `BridgeTypes.all` and failing contract test**
- [ ] **Step 2: Commit** `feat(lunarabi): add IAP bridge message types`

---

### Task 2: IapStore autoConsume:false + allowlist + controller state machine

**Files:**
- Modify: `lunarabi/lib/features/payments/iap_purchase_service.dart` (`IapStore.buyConsumable` gains `autoConsume: false` default for Android path)
- Create: `lunarabi/lib/features/payments/iap_bridge_controller.dart`
- Create: `lunarabi/lib/features/payments/iap_pending_store.dart` (durable pending records)
- Test: `lunarabi/test/features/payments/iap_bridge_controller_test.dart`
- Test: `lunarabi/test/features/payments/iap_pending_store_test.dart`

**Interfaces:**

```dart
abstract interface class IapStore {
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = false, // MUST remain false for verify-before-consume
  });
  Future<void> completePurchase(PurchaseDetails purchase);
  Stream<List<PurchaseDetails>> get purchaseStream;
  // ...
}

class IapPendingRecord {
  final String purchaseKey; // purchaseID ?? '$platform:$productId:$verificationData'
  final String? purchaseId;
  final String productId;
  final String platform;
  final String verificationData;
  final bool waitingConfirm;
  final DateTime updatedAt;
}

abstract interface class IapPendingStore {
  Future<void> upsert(IapPendingRecord record);
  Future<IapPendingRecord?> getByKey(String purchaseKey);
  Future<List<IapPendingRecord>> allWaiting();
  Future<void> remove(String purchaseKey);
}

class IapBridgeController {
  IapBridgeController({
    required IapPurchaseService iap,
    required BridgeHost bridge,
    required IapPendingStore pending,
    required Uri? Function() committedWebUri,
    required Uri webBaseUrl,
    this.allowedProductIds = const {'lunarabi.credit.100'},
    this.confirmTimeout = const Duration(minutes: 2),
  });

  Future<void> handleFromJs(BridgeMessage message);
  Future<void> startPurchaseStream(); // app lifetime
  Future<void> onAppResumed();
  Future<void> onBridgeReady(); // re-emit waiting purchased txs if trusted
}
```

Behavior:
1. On `iap.start`: require TrustedBridgeOrigin; reject unknown productId before Store
2. Begin buy with `autoConsume: false`
3. On store purchased: compute purchaseKey; persist pending (`waitingConfirm: true`); emit purchaseUpdated **only if trusted**; wait for matching confirmResult (timeout e.g. 2 min)
4. ok true + live PurchaseDetails matched by purchaseKey → completePurchase exactly once → remove pending → finished completed
5. ok false / timeout → **do not** completePurchase / consume; keep pending; finished failed
6. canceled/error → finished canceled/failed without waiting confirm; no complete
7. confirmResult rules: duplicate ok after complete → error; stale/unknown key → error never complete; confirm before waiting → error; late ok after timeout only if still `waitingConfirm` + live tx
8. Rehydration: if durable pending exists without live Store tx, re-emit for Web but delay complete until Store re-emits matching tx
9. Tests assert fake store: zero complete/consume before ok:true; unknown product never buyConsumable; deepLinkHost cannot start/confirm or receive receipt events

- [ ] **Step 1: Failing tests** happy path, cancel, confirm false, timeout, unknown product, no-complete-before-ok, duplicate/stale/unknown confirm, deepLinkHost forbidden, rehydrate-without-live-tx-no-complete
- [ ] **Step 2: Implement store flag + pending store + controller**
- [ ] **Step 3: Commit** `feat(lunarabi): add IapBridgeController with gated complete`

---

### Task 3: Lifetime observer, recovery, BridgeHost registration (no cycles)

**Files:**
- Modify: `iap_purchase_service.dart` — app-lifetime listen API (not per-buy cancel in finally that drops recovery)
- Modify: `bridge_host.dart` — `registerHandler` / command router for `iap.*` (no cyclic `BridgeHost` requiring `IapBridgeController` in constructor)
- Modify: `app_services.dart` / `main.dart`:
  1. construct BridgeHost
  2. construct IapBridgeController
  3. `bridge.registerHandler('iap.', controller.handleFromJs)`
  4. `controller.startPurchaseStream()`
  5. wire resume → `onAppResumed`; ready → `onBridgeReady`
- Remove unused PaymentCoordinator sheet path / Fake-only UX if still present for IAP entry
- README: Web verify API + bridge handlers = **external gate**; backend allowlist still required

Recovery tests:
- Startup with durable pending ⇒ emits purchaseUpdated
- bridge.ready while waiting ⇒ re-emits purchaseUpdated (deduped)
- After ok:true path, complete called once

- [ ] **Step 1: Test** pending on startup / resume / ready re-emit
- [ ] **Step 2: Test** iap.start JS message reaches controller; non-iap messages unaffected
- [ ] **Step 3: Wire**
- [ ] **Step 4: Full test suite**
- [ ] **Step 5: Commit** `feat(lunarabi): wire Web-started IAP with verify handoff`

---

### Task 4: Frontend contract update (iap + external gates)

**Files:**
- Update: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`

Include example JS for:
- getStoredToken after ready
- push.setToken handler → API register
- iap.start / purchaseUpdated / confirmResult / finished
- External gates list (frame policy, verify API)

- [ ] **Step 1: Write contract sections**
- [ ] **Step 2: Commit** `docs: update bridge contract for auth, FCM, IAP`

---

## Self-review checklist

- [ ] No native payment sheet required for IAP
- [ ] autoConsume false; complete gated on Web ok + live PurchaseDetails
- [ ] Durable pending recovery + rehydration contract
- [ ] confirmResult stale/duplicate/unknown rules
- [ ] TrustedBridgeOrigin on start/confirm/emits
- [ ] Native product allowlist
- [ ] No BridgeHost ↔ IapBridgeController constructor cycle
- [ ] Spec §4 covered
