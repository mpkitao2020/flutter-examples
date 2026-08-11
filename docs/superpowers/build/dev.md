# ビルド手順 — 開発 (dev)

## 目的

開発用 Web / API / Firebase に接続したデバッグビルド。

## 設定値

| 項目 | 値 |
|---|---|
| FLAVOR | `dev` |
| Android `--flavor` | `dev` |
| Web | `https://dev.lunarabi.example` |
| API | `https://api-dev.lunarabi.example` |
| Firebase Android | `android/app/src/dev/google-services.json` |
| Firebase iOS | `ios/config/dev/GoogleService-Info.plist` |
| iOS Configuration 対応 | `Debug` → script が **dev** plist をコピー（または `Debug-dev`） |

## 事前準備

1. 本物の `google-services.json` / `GoogleService-Info.plist` が必要ならプレースホルダを置換
2. `fvm flutter pub get`
3. （任意）アセット差し替えは branding プラン参照

## Android

### 実行（デバッグ）

```bash
cd lunarabi
fvm flutter run --flavor dev --dart-define=FLAVOR=dev
```

### APK ビルド

```bash
fvm flutter build apk --flavor dev --dart-define=FLAVOR=dev --debug
# または検証に近い形
fvm flutter build apk --flavor dev --dart-define=FLAVOR=dev --release
```

成果物例: `build/app/outputs/flutter-apk/app-dev-*.apk`

### App Bundle

```bash
fvm flutter build appbundle --flavor dev --dart-define=FLAVOR=dev --release
```

## iOS

### 実行

```bash
cd lunarabi
fvm flutter run --dart-define=FLAVOR=dev
# Xcode では Debug（→ dev plist）または Debug-dev スキームを使用
```

### ipa / archive

```bash
fvm flutter build ipa --dart-define=FLAVOR=dev --release
```

Build Phase「Copy GoogleService-Info」が `ios/config/dev/GoogleService-Info.plist` をバンドルへコピーすることを確認。

## 動作確認チェック

- [ ] 起動後 WebView が `dev.lunarabi.example` 系を開く（debug メニューの環境表示が `dev`）
- [ ] `bash tool/forbid_firebase_options.sh` が OK
- [ ] Firebase が開発プロジェクトを指している（クラッシュや Analytics で確認）
- [ ] （bridge 後）ボトムナビと JS ブリッジが動く
- [ ] （push 後）FCM トークンが取れる

## よくある失敗

| 症状 | 原因 | 対処 |
|---|---|---|
| URL が本番のまま | `FLAVOR` 未指定で release 相当 | `--dart-define=FLAVOR=dev` |
| Firebase が別環境 | `--flavor` 忘れ | `--flavor dev` |
| iOS で Firebase 初期化失敗 | plist 未コピー | Build Phase / `ios/config/dev/` を確認 |
