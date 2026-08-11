# IAP bridge tasks report

Branch: `cursor/lunarabi-iap-bridge-c3bc`

## Commits

- `c6ab3b4` `feat(lunarabi): add IAP bridge message types`
- `3629975` `feat(lunarabi): add IapBridgeController with gated complete`
- `990cc7a` `feat(lunarabi): wire Web-started IAP with verify handoff`
- Final docs commit message: `docs: update bridge contract for auth, FCM, IAP`

## Verification

- Task 1 red: `fvm flutter test test/features/bridge/bridge_contract_surface_test.dart` failed because `BridgeTypes.all` did not contain `iap.start`.
- Task 1 green: `fvm flutter test test/features/bridge/bridge_contract_surface_test.dart` passed, `1` test.
- Task 2 red: focused pending/controller tests failed on missing `iap_pending_store.dart` and `iap_bridge_controller.dart`.
- Task 2 green: `fvm flutter test test/features/payments/iap_pending_store_test.dart test/features/payments/iap_bridge_controller_test.dart` passed, `11` tests.
- Task 2 regression: `fvm flutter test test/features/payments/iap_purchase_service_test.dart` passed, `11` tests.
- Task 3 red: focused tests failed on missing `BridgeHost.registerHandler` and the old native Store IAP sheet entry.
- Task 3 green: `fvm flutter test test/features/bridge/bridge_host_test.dart test/features/payments/payment_sheet_test.dart test/features/payments/iap_bridge_controller_test.dart` passed, `21` tests.
- Task 3 full suite: `fvm flutter test` passed, `137` tests.
- Final full suite before docs commit: `fvm flutter test` passed, `137` tests.

## Self-review checklist

- No native payment sheet required for IAP: yes, Store IAP sheet entry and coordinator branch removed.
- `autoConsume:false`; complete gated on Web `ok:true` plus live `PurchaseDetails`: yes.
- Durable pending recovery and rehydration contract: yes.
- Stale/duplicate/unknown confirm rules: yes, bridge errors and no second complete.
- TrustedBridgeOrigin on start/confirm/emits: yes.
- Native product allowlist: yes, only `lunarabi.credit.100`.
- No `BridgeHost` <-> `IapBridgeController` constructor cycle: yes, registerHandler wiring.
- Spec section 4 contract docs: updated with auth, FCM, IAP, and external gates.

## Concerns

- Backend/Web verify API and frame-policy gates remain external release artifacts; this branch documents and enforces native-side handoff only.
- Existing legacy `IapPurchaseService.buy(...backend...)` remains for regression coverage but is no longer reachable from the native payment sheet.
