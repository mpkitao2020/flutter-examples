# Lunarabi FCM Web registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FCM トークンをネイティブから Web へ渡し、Web が登録 API を呼ぶ。ネイティブの Logging backend 登録を本番経路から外す。

**Architecture:** PushService obtains token → PushTokenStore → BridgeHost.notifyPushToken including platform. On bridge.ready, resent if present. No HTTP register from Flutter.

**Tech Stack:** firebase_messaging, existing bridge

**Branch:** `cursor/lunarabi-fcm-web-register-c3bc`  
**Base:** after auth-storage

## Global Constraints

- Payload includes `token` and `platform` (`ios`|`android`)
- Web owns API registration
- Spec §3

---

### Task 1: Extend push.setToken payload with platform

**Files:**
- Modify: `lunarabi/lib/features/bridge/bridge_host.dart`
- Modify: `lunarabi/lib/features/push/push_service.dart`
- Test: `lunarabi/test/features/bridge/bridge_host_test.dart` / new push bridge test

```dart
Future<void> notifyPushToken(String token, {required String platform}) {
  push.setToken(token);
  return emitToJs(BridgeMessage(
    type: BridgeTypes.pushSetToken,
    payload: {'token': token, 'platform': platform},
  ));
}
```

- [ ] **Step 1: Failing test** payload contains platform
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit** `feat(lunarabi): include platform in push.setToken`

---

### Task 2: Remove native backend register from happy path

**Files:**
- Modify: `lunarabi/lib/features/push/push_service.dart`
- Modify: `lunarabi/lib/main.dart`
- Modify: `lunarabi/lib/features/push/notification_link_parser.dart` (deprecate or keep Logging client unused)
- Test: unit test PushService.register path with fake bridge emitter

**Behavior:**
```dart
Future<void> _publishToken(String token) async {
  await AppServices.bridgeHost.notifyPushToken(
    token,
    platform: Platform.isIOS ? 'ios' : 'android',
  );
}
```
- Do not call `backend.register`
- On bridge attach/ready, if store has token, resend

- [ ] **Step 1: Test** no backend.register call; bridge notified
- [ ] **Step 2: Implement**
- [ ] **Step 3: README** Web must register token via API
- [ ] **Step 4: Commit** `feat(lunarabi): hand FCM token to Web for API registration`

---

### Task 3: Resend token on bridge.ready

**Files:**
- Modify: `bridge_host.attach` / `injectBootstrap` path already emits ready — after ready, if push.token != null, emit push.setToken again (may already exist; ensure platform included)

- [ ] **Step 1: Test** existing token resent after ready
- [ ] **Step 2: Implement if missing**
- [ ] **Step 3: Commit** `fix(lunarabi): resend push token after bridge.ready`

---

## Self-review checklist

- [ ] No native API registration required for success
- [ ] Platform always present
- [ ] Spec §3 covered
