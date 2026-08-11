# Lunarabi push notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FCM でトークン取得・登録口・通知タップからの HTTPS リンク遷移を実装する。Firebase はネイティブ設定のみ。

**Architecture:** `firebase_messaging` + local notifications。すべての遷移は `HostGuard` → `AppNavigator.openFromNotification`。

**Tech Stack:** `firebase_core`, `firebase_messaging`, `flutter_local_notifications`

**Branch:** `cursor/lunarabi-push-c3bc`（base: **deeplink マージ後**の `develop`。scaffold 直は不可）

## Global Constraints

- FirebaseOptions 系禁止（`tool/forbid_firebase_options.sh` を通す）
- `link` データ必須。欠落・非 https・HostGuard 拒否 → navigator 未呼び出し
- `PushBackendClient.register` は口のみ。失敗しても起動継続。token ログは末尾 6 文字以外 mask
- package: `com.wandit.lunarabi`
- Spec: `docs/superpowers/specs/2026-08-11-lunarabi-webview-design.md`

---

### Task 1: Parser + backend port

**Files:**
- Create: `lunarabi/lib/features/push/notification_link_parser.dart`
- Create: `lunarabi/lib/features/push/push_backend_client.dart`
- Create: `lunarabi/test/features/push/notification_link_parser_test.dart`

**Interfaces:**

```dart
Uri? parseNotificationLink(Map<String, dynamic> data, HostGuard guard) {
  final raw = data['link'];
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (!guard.isAllowed(uri)) return null;
  return uri;
}

abstract interface class PushBackendClient {
  Future<void> register(String token);
}

class LoggingPushBackendClient implements PushBackendClient {
  @override
  Future<void> register(String token) async {
    final masked = token.length <= 6 ? '***' : '***${token.substring(token.length - 6)}';
    // ignore: avoid_print
    print('PushBackendClient.register: $masked');
  }
}
```

- [ ] **Step 1: Tests** — good https host; http; evil host; missing link; non-string link → null
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

```bash
git add lunarabi/lib/features/push lunarabi/test/features/push
git commit -m "feat(lunarabi): add FCM link parser and push backend port"
```

---

### Task 2: FCM + local notification wiring

**Files:**
- Create: `lunarabi/lib/features/push/push_service.dart`
- Create: `lunarabi/test/features/push/push_service_test.dart`
- Modify: `lunarabi/lib/main.dart`
- Modify: `lunarabi/pubspec.yaml`
- Modify: iOS capabilities checklist in README（Push Notifications、Background Modes: remote-notification、APNs via Firebase）
- Modify: Android manifest / default notification channel as required by plugin docs

**Interfaces:**

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // NO options
  // no navigation
}

class PushService {
  Future<void> start({
    required AppNavigator navigator,
    required HostGuard guard,
    required PushBackendClient backend,
  });
}
```

Behavior:
1. Register background handler **before** `runApp`（and after WidgetsFlutterBinding）
2. Request notification permission（Apple + Android 13+）
3. Get token → `backend.register` inside try/catch（failure: masked log, continue）
4. `onTokenRefresh` → register again
5. `getInitialMessage` / `onMessageOpenedApp` → parse → `openFromNotification`
6. Foreground `onMessage` → **always** show local notification carrying `link` in payload; on tap → same parse → `openFromNotification`
7. No SnackBar fallback for navigation

- [ ] **Step 1: Unit tests with fakes** — opened-app good link calls navigator; evil host does not; register throw does not abort start; local-notification tap path calls navigator
- [ ] **Step 2: Implement**
- [ ] **Step 3: Run**

```bash
bash lunarabi/tool/forbid_firebase_options.sh
cd lunarabi && fvm flutter test test/features/push
fvm flutter analyze
```

- [ ] **Step 4: README** — Firebase Console data message sample `{"link":"https://app.lunarabi.example/promo"}`、iOS capability checklist、権限拒否時はトークン取得できず登録スキップ
- [ ] **Step 5: Commit**

```bash
git add lunarabi
git commit -m "feat(lunarabi): wire FCM push service to AppNavigator"
```

---

## Self-review checklist

- HostGuard on all links, local notification only, background handler pragma, masked token, base after deeplink
