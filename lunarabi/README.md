# Lunarabi

`com.wandit.lunarabi` 向けの薄い WebView シェル（環境別にアプリ ID を分離）。

## アプリ ID（環境別）

| 環境 | Android applicationId / iOS Bundle ID |
|---|---|
| dev | `com.wandit.lunarabi.dev` |
| stg | `com.wandit.lunarabi.stg` |
| prod | `com.wandit.lunarabi` |

Android は `applicationIdSuffix`、iOS は Debug→dev / Profile→stg / Release→prod。  
Firebase の `package_name` / `BUNDLE_ID` も同じ値に揃える。

iOS で stg ID を使うときは Profile（または将来の `*-stg` scheme）でビルドする。  
`flutter run --flavor stg` の Android は `com.wandit.lunarabi.stg` になる。

## 接続 URL（環境別）

| 環境 | Web | API |
|---|---|---|
| dev | `https://dev.lunarabi.example` | `https://api-dev.lunarabi.example` |
| stg | `https://stg.lunarabi.example` | `https://api-stg.lunarabi.example` |
| prod | `https://www.lunarabi.example` | `https://api.lunarabi.example` |

## 前提

- FVM で Flutter **3.44.9** をピン留め（`.fvmrc`）
- `main.dart` は 1 ファイル
- Firebase はネイティブ設定のみ（Dart の `FirebaseOptions` 禁止）
- `.env` は使わない。`--dart-define=FLAVOR=dev|stg|prod`

## セットアップ

```bash
cd lunarabi
fvm install
fvm flutter pub get
```

## 実行例

```bash
# Dart 側の環境（URL）
fvm flutter run --dart-define=FLAVOR=dev

# Android は product flavor も指定する
fvm flutter run --flavor dev --dart-define=FLAVOR=dev
fvm flutter run --flavor stg --dart-define=FLAVOR=stg
fvm flutter run --flavor prod --dart-define=FLAVOR=prod
```

debug / profile では AppBar メニューから環境切替が可能（release では非表示）。

## Firebase（ネイティブのみ）

プレースホルダを本物のファイルで置き換える:

| 環境 | Android | iOS |
|---|---|---|
| dev | `android/app/src/dev/google-services.json` | `ios/config/dev/GoogleService-Info.plist` |
| stg | `android/app/src/stg/google-services.json` | `ios/config/stg/GoogleService-Info.plist` |
| prod | `android/app/src/prod/google-services.json` | `ios/config/prod/GoogleService-Info.plist` |

iOS は Xcode の Configuration 名を `Debug-dev` / `Release-stg` のようにしてもよい。
Build Phase「Copy GoogleService-Info」が `ios/scripts/copy_google_service_info.sh` を実行する。

標準の `Debug` / `Profile` / `Release` のままでも動く（それぞれ dev / stg / prod の plist をコピー）。
将来 Configuration を `*-dev` 形式に増やした場合は、ハイフン以降が flavor になる。

Dart 側に `FirebaseOptions` を入れていないか確認:

```bash
bash tool/forbid_firebase_options.sh
```

## JS ブリッジ / ボトムナビ

ネイティブがボトムナビを描画し、Web と JSON で双方向通信します。

- Flutter→JS: `window.__LUNARABI_NATIVE_EVENT__(msg)`
- JS→Flutter: `window.LunarabiBridge.post(msg)`
- 契約書（フロント向け）: リポジトリの `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`（design-plans ブランチ）

対応 type 例: `nav.setVisible` / `nav.setBadge` / `nav.setActive` / `nav.tabSelected` / `auth.*` / `push.*`

## ブランディング（アイコン / スプラッシュ / 通知アイコン）

ソースは `branding/`。差し替え手順は `branding/README.md`。

```bash
# 画像を差し替えたあと
dart run flutter_launcher_icons
dart run flutter_native_splash:create
cp branding/notification_icon.png android/app/src/main/res/drawable/ic_stat_lunarabi.png
```

- アプリアイコン: Android mipmap / iOS AppIcon
- スプラッシュ: Native Splash（色 `#0B1F33`）
- プッシュ通知アイコン（Android）: `@drawable/ic_stat_lunarabi`（白＋透明。カラー不可）
- iOS 通知はアプリアイコンを使用

## テスト

```bash
fvm flutter test
```

テストコードには、初めて読む人向けの日本語コメントを付けている。

- `test/core/env/app_config_test.dart` … 環境 URL / FLAVOR パース
- `test/core/env/app_ids_test.dart` … 環境別アプリ ID
- `test/core/navigation/host_guard_test.dart` … 開いてよい URL の判定
- `test/tool/forbid_firebase_options_test.dart` … FirebaseOptions 禁止の回帰
- `test/features/bridge/` … JS ブリッジとボトムナビ
- `test/features/payments/` … IAP / GMO / あおぞら
- `test/branding/branding_assets_test.dart` … アイコン等の成果物パス

## 決済（都度課金）

AppBar「購入」から手段を選択する。商品 ID は **`lunarabi.credit.100`（consumable）**。

| 手段 | 挙動 |
|---|---|
| ストアで購入 | `in_app_purchase` の consumable。成功後 `confirmIap` → `completePurchase` → `/pay/done` |
| クレジットカード (GMO) | 外部ブラウザで checkout。完了 DL: `https://app.lunarabi.example/pay/gmo/complete?paymentId=...` |
| 銀行振込 (あおぞら) | 口座表示。「入金を確認」押下ごとに API 1 回（自動ポーリングなし） |

### Store 登録

- Google Play / App Store Connect に consumable `lunarabi.credit.100` を登録
- **復元 UI は置かない**（consumable のため）
- サンドボックス: iOS は Sandbox アカウント、Android はライセンステスター
- PSP 秘密鍵・GMO ショップ認証情報はアプリに入れない（バックエンドのみ）
- 現状の `AppServices.paymentBackend` は debug/profile では **Fake**、release では **FailClosed**（confirm / session 作成は `StateError`、商品一覧は空）。本番前に実 API クライアントへ差し替えること

### iOS ガイドライン

デジタルコンテンツ向けに Store 外決済（GMO / 振込）も出す。ガイドライン 3.1.1 のリスクはプロダクト側で合意済み。

## 審査メモ（先出し）

アプリ内デジタルコンテンツでも Store 外決済（GMO / 銀行振込）を出す。iOS ガイドライン 3.1.1 のリスクはプロダクト側で合意済み。

## ディープリンク

HTTPS のみ: `https://app.lunarabi.example/...`
- Android App Links / iOS Universal Links（`Runner.entitlements`）
- サンプル: `docs/well-known/*.example`
- `/pay/gmo/complete` は DeepLinkBus へ（WebView 遷移なし）。payments が confirm 後 `/pay/done` へ
