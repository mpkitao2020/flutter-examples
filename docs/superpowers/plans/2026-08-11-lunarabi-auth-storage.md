# Lunarabi auth Secure Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sanctum Bearer token を Flutter Secure Storage に保存し、**trusted bridge origin**（`webBaseUrl.host` のみ）からのみ復元可能にする。

**Architecture:** `SecureAuthTokenStore` wraps `flutter_secure_storage`. Bridge exposes set/clear/getStoredToken. Arbitrary `auth.getBearerToken` is removed or always errors. Token returned only when **committed main-frame URL** (from branch 1) is a trusted bridge origin — **not** merely HostGuard-allowed / `deepLinkHost`.

**Tech Stack:** `flutter_secure_storage`, existing BridgeHost / HostGuard / committed URL state

**Branch:** `cursor/lunarabi-auth-storage-c3bc`  
**Base:** after webview-guard

## Global Constraints

- Single Sanctum token (no refresh token)
- Trusted bridge origin = `config.webBaseUrl.host` (https only). Distinct `deepLinkHost` must **not** receive token
- Web must not put token in localStorage — **external gate** (README + contract)
- SPA must forbid untrusted frames that can reach the JS channel — **external release gate**
- Spec §2

---

### Task 1: SecureAuthTokenStore

**Files:**
- Create: `lunarabi/lib/features/bridge/secure_auth_token_store.dart`
- Modify: `lunarabi/lib/features/bridge/token_stores.dart` (keep mask helper; deprecate in-memory as sole store)
- Test: `lunarabi/test/features/bridge/secure_auth_token_store_test.dart`

**Interfaces:**

```dart
abstract interface class AuthTokenRepository {
  Future<void> save(String token);
  Future<String?> read();
  Future<void> clear();
}

class SecureAuthTokenStore implements AuthTokenRepository {
  SecureAuthTokenStore({FlutterSecureStorage? storage});
  static const storageKey = 'lunarabi.sanctum.bearer';
}
```

Use in-memory fake storage in tests.

- [ ] **Step 1: Failing tests** save/read/clear
- [ ] **Step 2: Implement**
- [ ] **Step 3: Add `flutter_secure_storage` to `pubspec.yaml`**
- [ ] **Step 4: Commit** `feat(lunarabi): add SecureAuthTokenStore`

---

### Task 2: Bridge auth.getStoredToken + trusted-origin gate

**Files:**
- Modify: `lunarabi/lib/features/bridge/bridge_message.dart`
- Modify: `lunarabi/lib/features/bridge/bridge_host.dart`
- Modify: `lunarabi/lib/core/app_services.dart`
- Modify: shell wiring to pass **committed URL provider** from branch 1 state (not raw WebViewController sync)
- Create/Update: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md` (**first** contract landing: auth types + external frame/CSP gate)
- Test: `lunarabi/test/features/bridge/bridge_host_auth_test.dart`
- Update: `lunarabi/test/features/bridge/bridge_contract_surface_test.dart`

**Interfaces:**

```dart
// BridgeTypes
static const authGetStoredToken = 'auth.getStoredToken';
// Remove authGetBearerToken from all set OR respond error 'forbidden'

class BridgeHost {
  BridgeHost({
    required AuthTokenRepository authRepo,
    required Uri? Function() committedWebUri, // from WebViewCommittedUrl
    required String trustedBridgeHost, // webBaseUrl.host
    ...
  });
}

bool isTrustedBridgeOrigin(Uri? uri, String trustedHost) {
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == trustedHost;
}
```

Dispatch:
- `auth.setBearerToken` → `authRepo.save`
- `auth.clearBearerToken` → `authRepo.clear`
- `auth.getStoredToken` → if `isTrustedBridgeOrigin(committedWebUri(), trustedBridgeHost)` return token; else `{ok:false,error:'forbidden_origin'}`
- Null / in-flight (cleared) committed URI ⇒ forbidden

- [ ] **Step 1: Tests** webBaseUrl returns token; distinct deepLinkHost forbidden; null committed forbidden; clear works; getBearerToken forbidden
- [ ] **Step 2: Implement**
- [ ] **Step 3: Write frontend contract (auth) + README external gates**
- [ ] **Step 4: Commit** `feat(lunarabi): bridge auth restore via Secure Storage`

---

### Task 3: Wire AppServices + Android/iOS storage options if required

**Files:**
- Modify Android/iOS manifests only if package requires
- README: Web call getStoredToken after bridge.ready; on 401 clear — labeled **external gate**

- [ ] **Step 1: Integrate into AppServices**
- [ ] **Step 2: Full test suite**
- [ ] **Step 3: Commit** `chore(lunarabi): wire secure auth into AppServices`

---

## Self-review checklist

- [ ] No arbitrary getBearerToken leak
- [ ] Trusted-origin check (not HostGuard-only) before return
- [ ] deepLinkHost ≠ webBaseUrl cannot read token
- [ ] Frontend contract created on this branch
- [ ] Spec §2 covered
