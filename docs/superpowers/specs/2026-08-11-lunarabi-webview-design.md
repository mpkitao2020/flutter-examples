# Lunarabi WebView app design

## Goal

`com.wandit.lunarabi` 向けの薄い Flutter WebView シェル。環境別の固定 URL を表示し、アプリ内デジタル商品の都度課金（Store IAP + GMO リンクトイプ + あおぞら銀行バーチャル振込）、HTTPS ディープリンク、FCM プッシュを配線する。購入確定は既存バックエンド API に委譲する。

## Product constraints (agreed)

- WebView アプリ。読み込み先は環境ごとに 1 つのベース URL（dev / stg / prod で異なる）
- 環境切替: 起動時は flavor / `--dart-define` で固定。debug / profile のみインアプリ切替メニュー
- `main.dart` は 1 ファイル
- Firebase はネイティブ設定のみ。Dart で `FirebaseOptions` / `firebase_options.dart` / `DefaultFirebaseOptions` / `Firebase.initializeApp(options: ...)` を禁止
- `.env` / `flutter_dotenv` は使わない。非機密は Dart 定数 + define。PSP 秘密鍵・GMO ショップ認証情報はアプリに入れない（バックエンドのみ）
- 決済: 全プラットフォームで IAP + GMO + 銀行振込（デジタルコンテンツ。iOS 審査リスクは承知）
- ディープリンク: Universal Links / App Links（HTTPS）のみ。ホスト `app.lunarabi.example`
- プッシュ: FCM（iOS も APNs を FCM 経由）
- バックエンド: 既存。アプリは呼び出しと状態表示まで（API 仕様は後渡し。口だけ先に用意）
- FVM で最新安定 Flutter を具体バージョンとして `.fvmrc` にピン留め
- iOS + Android
- リポジトリ内フォルダ名: `lunarabi/`

## Architecture

薄い WebView シェル。Flutter は殻、コンテンツは Web。

| Layer | Responsibility |
|---|---|
| `app` | 単一 `main.dart`。環境読込、依存組み立て、ルート初期化 |
| `core/env` | `AppConfig`（dev/stg/prod）。WebView URL・API base・ディープリンクホスト |
| `core/navigation` | `HostGuard` + `AppNavigator`。ディープリンクと通知タップの単一口 |
| `features/webview` | 単一 WebView。ベース URL 表示と許可 URI のロード |
| `features/payments` | IAP・GMO 起動・振込導線。完了後に `PaymentBackendClient` へ |
| `features/push` | FCM。トークン、タップ → navigator |
| `features/deeplink` | HTTPS リンク受信 → parser → bus / navigator |
| `platform` | 環境別 Firebase ファイル、Associated Domains、App Links |

### Navigation contract

```dart
/// Shared allowlist used by deeplink, push, and WebView loads.
class HostGuard {
  HostGuard(this.config);
  final AppConfig config;

  bool isAllowed(Uri uri) =>
      uri.scheme == 'https' &&
      (uri.host == config.deepLinkHost || uri.host == config.webBaseUrl.host);

  /// Maps deep-link host URLs onto the env web base, preserving path/query/fragment.
  /// Returns null if not allowed.
  Uri? resolveForWebView(Uri uri) {
    if (!isAllowed(uri)) return null;
    if (uri.host == config.webBaseUrl.host) return uri;
    return config.webBaseUrl.replace(
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    );
  }
}

abstract interface class AppNavigator {
  Future<void> openDeepLink(Uri uri);
  Future<void> openFromNotification(Uri uri);
}
```

両方の open メソッドは内部で `HostGuard.resolveForWebView` を通し、null なら no-op + log。

### Env

```dart
enum Flavor { dev, stg, prod }

class AppConfig {
  final Flavor flavor;
  final Uri webBaseUrl;
  final Uri apiBaseUrl;
  final String deepLinkHost; // app.lunarabi.example
}

Flavor parseFlavor(String raw, {required bool isRelease}) {
  return switch (raw) {
    'dev' => Flavor.dev,
    'stg' => Flavor.stg,
    'prod' => Flavor.prod,
    _ => isRelease ? Flavor.prod : Flavor.dev,
  };
}
```

URL 定数:

| Flavor | webBaseUrl | apiBaseUrl |
|---|---|---|
| dev | `https://dev.lunarabi.example` | `https://api-dev.lunarabi.example` |
| stg | `https://stg.lunarabi.example` | `https://api-stg.lunarabi.example` |
| prod | `https://www.lunarabi.example` | `https://api.lunarabi.example` |

`deepLinkHost` は全 flavor で `app.lunarabi.example`。

起動: `--dart-define=FLAVOR=dev|stg|prod`。未指定時は `parseFlavor('', isRelease: kReleaseMode)`。

debug/profile のみ環境メニュー。release では出さない。

### Firebase

- Android: product flavor dimension `env` = `dev`/`stg`/`prod`。各 `src/<flavor>/google-services.json`。Google Services Gradle plugin を適用
- iOS: configurations/schemes `dev`/`stg`/`prod`。Build Phase で対応 plist を `GoogleService-Info.plist` として Runner にコピー
- `Firebase.initializeApp()` は options なしのみ

## Screens

1. **Shell**: 最小 AppBar（戻る）+ 全面 WebView。debug/profile は環境バッジと切替
2. **Payment sheet**: 都度課金の手段選択（IAP / GMO / あおぞら）
3. **Aozora transfer page**: 口座表示と手動「入金を確認」
4. 購入エントリ: AppBar の「購入」（ネイティブ導線）。Web 内カートとは同期しない（Web はコンテンツ表示のみ）

履歴画面は作らない。

## Payment flows

### Shared

- 商品 ID: `lunarabi.credit.100`（Store 上も同 ID、**consumable**）
- `PaymentBackendClient` が list / confirm / create session / check を担当。実装は Fake → 後差し替え
- 成功時 WebView は `config.webBaseUrl.replace(path: '/pay/done')` をロード

### Store IAP

- `in_app_purchase`、consumable のみ
- 購入後レシート／トークンを `confirmIap` へ、その後 `completePurchase`
- **復元 UI は置かない**（consumable のため）

### GMO link type

- `createGmoLink` → 外部ブラウザで `checkoutUrl`
- 完了ディープリンク（必須契約）:  
  `https://app.lunarabi.example/pay/gmo/complete?paymentId=<backend-issued-id>`
- `paymentId` 欠落時は `confirmGmo` せず failure
- deeplink 層は Web 遷移しない。payments が bus を購読して confirm 後に `/pay/done` へ

### Aozora virtual transfer

- `createAozoraTransfer` → 口座文字列表示
- **自動連続ポーリングなし**。ユーザーが「入金を確認」を押したときだけ `checkBankTransfer` を 1 回呼ぶ
- Fake は 1 回目 pending、2 回目 success

## Deep links

- ホスト: `app.lunarabi.example`
- scheme は `https` のみ。それ以外は `unknown`
- 許可判定は常に `HostGuard`
- パス:
  - `/pay/gmo/complete` → `DeepLinkKind.gmoComplete`（bus へ。payments 専用）
  - その他 → `webPath` → `AppNavigator.openDeepLink`
- `DeepLinkBus` は cold start 対応: 購読者が付くまで初期リンクを保持し、最初の subscriber に replay

## Push

- `firebase_messaging` + ネイティブ Firebase
- データキー `link`（HTTPS）。`HostGuard` 通過後に `openFromNotification`
- フォアグラウンドは **local notification 固定**。タップも同じ parser + navigator
- Background handler: top-level、`@pragma('vm:entry-point')`、handler 内で options なし `Firebase.initializeApp()`、UI 遷移禁止
- トークン登録失敗は握りつぶさず log（token は mask）し、起動は継続。`onTokenRefresh` で再登録
- Dart 側 FirebaseOptions 禁止をテスト／スクリプトで静的検出

## Branch strategy

| Order | Branch | Plan | Base |
|---|---|---|---|
| 0 (docs) | `cursor/lunarabi-design-plans-c3bc` | design + plans + frontend bridge contract | `develop` |
| 1 | `cursor/lunarabi-scaffold-c3bc` | scaffold | `develop`（docs マージ後推奨） |
| 2 | `cursor/lunarabi-bridge-c3bc` | bridge（ボトムナビ + JS ブリッジ） | scaffold マージ後 |
| 3 | `cursor/lunarabi-deeplink-c3bc` | deeplink | bridge マージ後推奨（scaffold 後でも可） |
| 4 | `cursor/lunarabi-push-c3bc` | push | **bridge マージ後**（トークンを Web へ渡す） |
| 5 | `cursor/lunarabi-payments-c3bc` | payments | **deeplink マージ後** |

1 ブランチ = 1 PR。接尾辞は本エージェント指定の `-c3bc`。  
プラン一覧: `docs/superpowers/plans/README.md`  
フロント契約: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`

### Bottom navigation + JS bridge (agreed direction)

- ボトムナビ UI は Flutter ネイティブ
- Web は表示／非表示・バッジ・アクティブ・Bearer を送信
- Flutter はタブ押下と FCM トークンを Web へ通知
- 詳細メッセージ型はフロント契約書を正本とする


## Testing

- 単体: flavor parse（release fallback 含む）、HostGuard、resolveForWebView、deeplink parse（非 HTTPS / 悪ホスト）、通知 link、GMO paymentId 欠落、IAP エラー→failure、Aozora 手動確認の pending→success および failure→エラー表示（navigator 未呼出し）
- Widget: payment sheet、aozora page（WebView 本体は controller をモックし platform view を直接 pump しない）
- 静的: FirebaseOptions 禁止 grep
- 実機チェックリストは README（Store サンドボックス、FCM、App Links）

## Out of scope

- 実 GMO / あおぞら本番キーをアプリに埋め込むこと
- バックエンド本体
- 実ドメインへの AASA / assetlinks 設置
- サブスク、カスタムスキーム、`.env`

## Risks

- iOS デジタルコンテンツの外部決済はリジェクトされやすい（合意済み）。README に審査メモを書く
- Firebase / Store / ディープリンクは実アカウントなしでは結合試験できない
- ネイティブ購入シートと Web コンテンツの二重 UI。起動はネイティブ、表示は Web
