# Lunarabi bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter ネイティブのボトムナビゲーションと、WebView 内フロントとの双方向 JS ブリッジを実装する。

**Architecture:** ボトムナビ UI は Flutter が描画（方針 A）。Web は `window.LunarabiBridge`（JS→Flutter）と `window.__LUNARABI_NATIVE_EVENT__`（Flutter→JS）で制御・通知する。契約の正本はフロント向け資料 `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`。

**Tech Stack:** `webview_flutter`（既存）+ `JavaScriptChannel` / `runJavaScript`、単一 `main.dart` は維持しつつ feature 配下に橋渡しコードを置く

**Branch:** `cursor/lunarabi-bridge-c3bc`  
**Base:** scaffold マージ後の `develop`

## Global Constraints

- ボトムナビは **Flutter ネイティブ**（Web は描画しない）
- メッセージは JSON 1 オブジェクト。`type` + `payload` + `requestId?`
- 許可ホストのみブリッジ有効（`HostGuard`）
- Bearer トークンはメモリ保持のみ。ログに生値を出さない（mask）
- テストは日本語の詳しいコメント付き
- package: `com.wandit.lunarabi`
- Spec / 契約:  
  - `docs/superpowers/specs/2026-08-11-lunarabi-webview-design.md`  
  - `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`

---

### Task 1: Bridge message models + codec

**Files:**
- Create: `lunarabi/lib/features/bridge/bridge_message.dart`
- Create: `lunarabi/test/features/bridge/bridge_message_test.dart`

**Interfaces:**

```dart
class BridgeMessage {
  const BridgeMessage({required this.type, required this.payload, this.requestId});
  final String type;
  final Map<String, dynamic> payload;
  final String? requestId;

  Map<String, dynamic> toJson();
  static BridgeMessage fromJson(Map<String, dynamic> json);
}
```

Supported `type` values（契約書と同一）:

| type | 方向 | 意味 |
|---|---|---|
| `nav.setVisible` | JS→Flutter | ボトムナビ表示／非表示 |
| `nav.setBadge` | JS→Flutter | アイコンバッジ数字 |
| `nav.setActive` | JS→Flutter | アクティブタブ |
| `nav.tabSelected` | Flutter→JS | アイコン押下通知 |
| `auth.setBearerToken` | JS→Flutter | ログイン Bearer 設定 |
| `auth.clearBearerToken` | JS→Flutter | ログアウト |
| `auth.getBearerToken` | JS→Flutter（request/response） | Bearer 取得 |
| `push.setToken` | Flutter→JS | FCM トークン通知 |
| `push.getToken` | JS→Flutter（request/response） | トークン要求 |
| `bridge.ready` | Flutter→JS | ブリッジ初期化完了 |
| `bridge.response` | Flutter→JS | requestId 付き応答 |

- [ ] **Step 1: 失敗する encode/decode テストを書く（コメント多め）**
- [ ] **Step 2: 実装して GREEN**
- [ ] **Step 3: Commit**

```bash
git add lunarabi/lib/features/bridge lunarabi/test/features/bridge
git commit -m "feat(lunarabi): add bridge message codec"
```

---

### Task 2: AuthTokenStore + PushTokenStore

**Files:**
- Create: `lunarabi/lib/features/bridge/auth_token_store.dart`
- Create: `lunarabi/lib/features/bridge/push_token_store.dart`
- Create: `lunarabi/test/features/bridge/token_store_test.dart`

**Interfaces:**

```dart
class AuthTokenStore {
  String? get bearerToken; // raw, never log
  String get maskedForLog; // *** + last 4
  void setToken(String? token);
}

class PushTokenStore {
  String? get token;
  String get maskedForLog;
  void setToken(String? token);
  final ValueNotifier<String?> listenable; // bridge watches to push to JS
}
```

- [ ] **Step 1: テスト（set/get/mask/clear）**
- [ ] **Step 2: 実装**
- [ ] **Step 3: Commit**

```bash
git commit -m "feat(lunarabi): add auth and push token stores"
```

---

### Task 3: Bottom navigation controller + UI

**Files:**
- Create: `lunarabi/lib/features/bridge/bottom_nav_controller.dart`
- Create: `lunarabi/lib/features/bridge/bottom_nav_bar.dart`
- Create: `lunarabi/test/features/bridge/bottom_nav_controller_test.dart`
- Modify: `lunarabi/lib/features/webview/webview_shell.dart`（ナビを下に合成）

**Interfaces:**

```dart
enum NavTabId { home, search, notify, account } // 契約の id と一致

class BottomNavController extends ChangeNotifier {
  bool visible;
  NavTabId active;
  Map<NavTabId, int> badges; // 0 = 非表示
  void setVisible(bool value);
  void setActive(NavTabId id);
  void setBadge(NavTabId id, int count); // count < 0 → 0
}
```

タブラベル／アイコンは仮（Icons.home 等）。契約の `id` 文字列と enum を相互変換。

- [ ] **Step 1: Controller 単体テスト（visible/badge/active）コメント付き**
- [ ] **Step 2: UI + Shell 合成。`visible==false` でバー非表示**
- [ ] **Step 3: Widget テストでバッジ数字と非表示を確認**
- [ ] **Step 4: Commit**

```bash
git commit -m "feat(lunarabi): add native bottom navigation"
```

---

### Task 4: BridgeHost (JS channel + event dispatch)

**Files:**
- Create: `lunarabi/lib/features/bridge/bridge_host.dart`
- Create: `lunarabi/test/features/bridge/bridge_host_test.dart`
- Modify: `webview_shell.dart` / `main.dart` で Host を配線
- Modify: README にフロント契約へのリンクを追加

**Interfaces:**

```dart
class BridgeHost {
  Future<void> attach(WebViewController controller);
  Future<void> emitToJs(BridgeMessage message);
  Future<void> handleFromJs(String rawJson);
}
```

Behavior:
1. `addJavaScriptChannel('LunarabiBridgeNative', onMessageReceived: ...)`
2. 初期化後に injection:

```js
window.LunarabiBridge = {
  post: (msg) => LunarabiBridgeNative.postMessage(JSON.stringify(msg))
};
window.__LUNARABI_NATIVE_EVENT__ = window.__LUNARABI_NATIVE_EVENT__ || function(msg) {};
```

3. Flutter→JS は `runJavaScript('window.__LUNARABI_NATIVE_EVENT__(...)')`
4. `nav.*` は `BottomNavController` を更新。タブ押下で `nav.tabSelected` を emit
5. `auth.*` / `push.getToken` は Store 経由。`requestId` がある場合は `bridge.response` で返す
6. 未知 type は `bridge.response` で `{ ok:false, error:"unknown_type" }`

- [ ] **Step 1: Fake WebViewController 相当のポートで Host 単体テスト**
- [ ] **Step 2: 実装・配線**
- [ ] **Step 3: Commit**

```bash
git commit -m "feat(lunarabi): wire JS bridge host to WebView"
```

---

### Task 5: Frontend contract checklist test

**Files:**
- Create: `lunarabi/test/features/bridge/bridge_contract_surface_test.dart`

契約書に載っている type 文字列が、Dart 側の定数と 1:1 であることを固定するテスト（コメントで「フロント資料との同期」と明記）。

- [ ] **Step 1: テスト作成・GREEN**
- [ ] **Step 2: Commit**

```bash
git commit -m "test(lunarabi): lock bridge type surface to frontend contract"
```

---

## Self-review checklist

- 表示／非表示、タップ通知、バッジ、アクティブ、FCM トークン、Bearer 取得が契約と一致
- 許可ホスト外でチャンネルを不用意に広げない
- トークン生値を log／テスト期待値に出さない
