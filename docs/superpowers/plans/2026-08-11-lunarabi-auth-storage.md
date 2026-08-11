# Lunarabi auth Secure Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sanctum Bearer token を Flutter Secure Storage に保存し、許可ホスト上の Web からのみ復元可能にする。

**Architecture:** `SecureAuthTokenStore` wraps `flutter_secure_storage`. Bridge exposes set/clear/getStoredToken. Arbitrary `auth.getBearerToken` is removed or always errors. Token returned only when current WebView URI passes HostGuard.

**Tech Stack:** `flutter_secure_storage`, existing BridgeHost / HostGuard

**Branch:** `cursor/lunarabi-auth-storage-c3bc`  
**Base:** after webview-guard

## Global Constraints

- Single Sanctum token (no refresh token)
- Web must not put token in localStorage
- Return token only for allowed https hosts
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

### Task 2: Bridge auth.getStoredToken + remove free getBearerToken

**Files:**
- Modify: `lunarabi/lib/features/bridge/bridge_message.dart`
- Modify: `lunarabi/lib/features/bridge/bridge_host.dart`
- Modify: `lunarabi/lib/core/app_services.dart`
- Modify: `lunarabi/lib/main.dart` / shell to pass current URI provider if needed
- Test: `lunarabi/test/features/bridge/bridge_host_auth_test.dart`
- Update frontend contract doc on this branch or design branch: `docs/superpowers/frontend/...`

**Interfaces:**

```dart
// BridgeTypes
static const authGetStoredToken = 'auth.getStoredToken';
// Remove authGetBearerToken from all set OR respond error 'forbidden'

class BridgeHost {
  BridgeHost({
    required AuthTokenRepository authRepo,
    required Uri? Function() currentWebUri, // from WebViewController
    ...
  });
}
```

Dispatch:
- `auth.setBearerToken` → `authRepo.save`
- `auth.clearBearerToken` → `authRepo.clear`
- `auth.getStoredToken` → if current URI allowed, return token; else `{ok:false,error:'forbidden_origin'}`

- [ ] **Step 1: Tests** allowed origin returns token; evil origin forbidden; clear works
- [ ] **Step 2: Implement**
- [ ] **Step 3: Update README + frontend contract snippet**
- [ ] **Step 4: Commit** `feat(lunarabi): bridge auth restore via Secure Storage`

---

### Task 3: Wire AppServices + Android/iOS storage options if required

**Files:**
- Modify Android/iOS manifests only if package requires
- README note for Web: call getStoredToken after bridge.ready; on 401 clear

- [ ] **Step 1: Integrate into AppServices**
- [ ] **Step 2: Full test suite**
- [ ] **Step 3: Commit** `chore(lunarabi): wire secure auth into AppServices`

---

## Self-review checklist

- [ ] No arbitrary getBearerToken leak
- [ ] Origin check before return
- [ ] Spec §2 covered
