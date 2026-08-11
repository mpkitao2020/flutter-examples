# Lunarabi WebView ブリッジ契約（フロント実装用）

対象アプリ: `com.wandit.lunarabi`  
ネイティブ実装ブランチ: `cursor/lunarabi-bridge-c3bc`  
最終更新: 2026-08-11

この文書は **Web（フロント）側が実装するときに必要な契約** です。  
Flutter はボトムナビゲーションをネイティブ描画し、Web は下記 API でのみ制御・受信します。

---

## 1. 役割分担

| 領域 | 担当 |
|---|---|
| ボトムナビの見た目・配置 | Flutter |
| ボトムナビの表示／非表示 | Web → Flutter（`nav.setVisible`） |
| バッジ数字 | Web → Flutter（`nav.setBadge`） |
| アクティブアイコン | Web → Flutter（`nav.setActive`）またはユーザー操作 |
| アイコン押下の業務処理 | Flutter → Web（`nav.tabSelected`）を受けて Web がルーティング |
| FCM トークン | Flutter → Web（`push.setToken`）／Web から要求可 |
| ログイン Bearer | Web → Flutter へ保存。Flutter から取得可 |

Web 側にボトムナビ DOM を作らないでください（二重 UI になります）。

---

## 2. 通信の基本形

すべてのメッセージは JSON オブジェクトです。

```ts
type BridgeMessage = {
  type: string;
  payload: Record<string, unknown>;
  /** 要求／応答を紐づける ID。必要なときだけ付ける */
  requestId?: string;
};
```

### Web → Flutter

```js
// ネイティブが注入する
window.LunarabiBridge.post({
  type: 'nav.setVisible',
  payload: { visible: false },
});
```

`window.LunarabiBridge` が無い場合（ブラウザ単体デバッグ）は no-op ガードを推奨:

```js
function postToNative(message) {
  if (window.LunarabiBridge && typeof window.LunarabiBridge.post === 'function') {
    window.LunarabiBridge.post(message);
    return true;
  }
  console.warn('[LunarabiBridge] native bridge missing', message.type);
  return false;
}
```

### Flutter → Web

ネイティブは次を呼び出します。

```js
window.__LUNARABI_NATIVE_EVENT__({
  type: 'nav.tabSelected',
  payload: { id: 'notify' },
});
```

フロントはアプリ起動直後にハンドラを登録してください。

```js
window.__LUNARABI_NATIVE_EVENT__ = function (message) {
  // message.type で分岐
};
```

上書き登録前にネイティブが `bridge.ready` を送る可能性があります。  
取りこぼし防止のため、ハンドラ登録後に必要なら状態を再同期してください（後述）。

---

## 3. ボトムナビゲーション

### タブ ID（固定）

| id | 意味（仮） |
|---|---|
| `home` | ホーム |
| `search` | 検索 |
| `notify` | 通知 |
| `account` | アカウント |

ID 文字列は変更しないでください。ラベルやアイコン画像はネイティブ側の後日差し替え対象です。

### 3.1 表示／非表示

```js
postToNative({
  type: 'nav.setVisible',
  payload: { visible: false }, // true で表示
});
```

用途例: ログイン画面、決済フルスクリーン、モーダル中。

### 3.2 バッジ数字

```js
postToNative({
  type: 'nav.setBadge',
  payload: { id: 'notify', count: 3 },
});
```

ルール:

- `count === 0` … バッジ非表示
- `count > 99` … ネイティブは表示を `99+` にしてよい
- 負数は `0` 扱い

### 3.3 アクティブアイコン

```js
postToNative({
  type: 'nav.setActive',
  payload: { id: 'search' },
});
```

Web のルーティングと見た目を揃えるときに使います。  
ユーザーがタブを押したときもネイティブがアクティブを更新し、続けて `nav.tabSelected` を送ります。

### 3.4 アイコン押下通知（Flutter → Web）

```js
window.__LUNARABI_NATIVE_EVENT__ = function (message) {
  if (message.type === 'nav.tabSelected') {
    const id = message.payload.id; // 'home' | 'search' | 'notify' | 'account'
    // 例: ルーターで該当ページへ
  }
};
```

**重要:** 押下の「画面遷移」は Web が行います。ネイティブは通知するだけです。

---

## 4. プッシュ通知トークン

### 4.1 ネイティブからのプッシュ（推奨）

トークン取得／更新のたびに:

```js
// Flutter → Web
{
  type: 'push.setToken',
  payload: { token: '<fcm-token>' }
}
```

フロントは自社 API に登録してください。

### 4.2 Web から要求

```js
const requestId = crypto.randomUUID();
postToNative({
  type: 'push.getToken',
  payload: {},
  requestId,
});

// 応答
// {
//   type: 'bridge.response',
//   requestId,
//   payload: { ok: true, token: '<fcm-token>' | null }
// }
```

---

## 5. ログイン Bearer トークン

### 5.1 ログイン成功時にネイティブへ渡す

```js
postToNative({
  type: 'auth.setBearerToken',
  payload: { token: 'eyJhbGciOi...' },
});
```

### 5.2 ログアウト

```js
postToNative({
  type: 'auth.clearBearerToken',
  payload: {},
});
```

### 5.3 ネイティブから取得（必要な場合）

```js
const requestId = crypto.randomUUID();
postToNative({
  type: 'auth.getBearerToken',
  requestId,
  payload: {},
});

// 応答 payload: { ok: true, token: string | null }
```

注意:

- ネイティブは API 呼び出しの Authorization ヘッダ用途などで保持する
- トークンを URL クエリに載せない
- コンソールへ生トークンを出さない

---

## 6. ライフサイクル

1. WebView がページをロード
2. ネイティブが `LunarabiBridge` を注入
3. ネイティブが `bridge.ready` を送信

```js
{ type: 'bridge.ready', payload: { platform: 'ios' | 'android' } }
```

4. Web は `bridge.ready` 受信後に:
   - `auth.setBearerToken`（セッションがある場合）
   - `nav.setVisible` / `nav.setActive` / `nav.setBadge` で初期同期
5. 以降、通常の双方向通信

### 推奨: イベントバス

```js
const listeners = new Set();
window.__LUNARABI_NATIVE_EVENT__ = (msg) => {
  listeners.forEach((fn) => fn(msg));
};
export function onNativeEvent(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
```

---

## 7. エラー応答

`requestId` 付き要求が失敗した場合:

```json
{
  "type": "bridge.response",
  "requestId": "...",
  "payload": { "ok": false, "error": "unknown_type" }
}
```

主な `error`:

| code | 意味 |
|---|---|
| `unknown_type` | 未対応 type |
| `invalid_payload` | 必須フィールド不足 |
| `not_ready` | ブリッジ未初期化 |

---

## 8. TypeScript 型定義（フロント用コピー推奨）

```ts
export type NavTabId = 'home' | 'search' | 'notify' | 'account';

export type NativeToWeb =
  | { type: 'bridge.ready'; payload: { platform: 'ios' | 'android' } }
  | { type: 'nav.tabSelected'; payload: { id: NavTabId } }
  | { type: 'push.setToken'; payload: { token: string } }
  | { type: 'bridge.response'; requestId: string; payload: { ok: boolean; token?: string | null; error?: string } };

export type WebToNative =
  | { type: 'nav.setVisible'; payload: { visible: boolean } }
  | { type: 'nav.setBadge'; payload: { id: NavTabId; count: number } }
  | { type: 'nav.setActive'; payload: { id: NavTabId } }
  | { type: 'auth.setBearerToken'; payload: { token: string } }
  | { type: 'auth.clearBearerToken'; payload: Record<string, never> }
  | { type: 'auth.getBearerToken'; requestId: string; payload: Record<string, never> }
  | { type: 'push.getToken'; requestId: string; payload: Record<string, never> };
```

---

## 9. 受け入れチェックリスト（フロント）

- [ ] `LunarabiBridge` 欠如時に落ちない
- [ ] `bridge.ready` 後にナビ状態を同期できる
- [ ] `nav.tabSelected` で画面遷移できる
- [ ] バッジ 0 で非表示、正の数で表示
- [ ] ログイン／ログアウトで Bearer を set/clear
- [ ] FCM トークンを `push.setToken` または `push.getToken` で取得し API 登録できる
- [ ] トークンをログ／URL に出していない

---

## 10. 関連ファイル

| ファイル | 内容 |
|---|---|
| `docs/superpowers/plans/2026-08-11-lunarabi-bridge.md` | Flutter 実装プラン |
| `docs/superpowers/plans/README.md` | 全ブランチ一覧 |
| `docs/superpowers/plans/2026-08-11-lunarabi-push.md` | FCM 実装（トークン供給元） |
