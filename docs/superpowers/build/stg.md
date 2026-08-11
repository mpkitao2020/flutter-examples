# ビルド手順 — 検証 (stg)

## 目的

検証用 Web / API / Firebase に接続したビルド。QA・ストア内部テスト向け。

## 設定値

| 項目 | 値 |
|---|---|
| FLAVOR | `stg` |
| Android `--flavor` | `stg` |
| Web | `https://stg.lunarabi.example` |
| API | `https://api-stg.lunarabi.example` |
| Firebase Android | `android/app/src/stg/google-services.json` |
| Firebase iOS | `ios/config/stg/GoogleService-Info.plist` |
| iOS Configuration 対応 | `Profile` → script が **stg** plist（または `Profile-stg` / `Release-stg`） |

## 事前準備

1. stg 用 Firebase ファイルを配置（プレースホルダのままでは実プッシュ不可）
2. ストア内部配布なら署名（Android keystore / iOS provisioning）を用意
3. `fvm flutter pub get`

## Android

### 実行

```bash
cd lunarabi
fvm flutter run --flavor stg --dart-define=FLAVOR=stg --release
```

### APK / AAB

```bash
fvm flutter build apk --flavor stg --dart-define=FLAVOR=stg --release
fvm flutter build appbundle --flavor stg --dart-define=FLAVOR=stg --release
```

Play Console の内部テストトラックに上げる場合は **AAB** を推奨。

## iOS

### 実行 / ビルド

```bash
cd lunarabi
fvm flutter run --dart-define=FLAVOR=stg --release
fvm flutter build ipa --dart-define=FLAVOR=stg --release
```

TestFlight 向けは Xcode Organizer または `flutter build ipa` の成果物を使用。  
Configuration が `Release` のままだと script は **prod** plist を選ぶため、stg 検証では次のどちらかにする:

- Configuration / Scheme を `Release-stg`（または `Profile`）にする
- 一時的に検証専用スキームを切る（branding / scaffold README 参照）

## 動作確認チェック

- [ ] WebView が `stg.lunarabi.example`
- [ ] API が `api-stg.lunarabi.example`（プロキシやログで確認）
- [ ] Firebase プロジェクトが検証用
- [ ] （payments）IAP サンドボックス商品 `lunarabi.credit.100` が見える
- [ ] （deeplink）`https://app.lunarabi.example/...` の検証準備ができている
- [ ] リリース相当でも debug 用環境メニューが出ないこと

## よくある失敗

| 症状 | 原因 | 対処 |
|---|---|---|
| iOS が prod Firebase になる | `Release` + fallback が prod | `Profile` か `*-stg` Configuration |
| Android は stg・Dart は prod | define 忘れ | `--dart-define=FLAVOR=stg` |
| 署名エラー | debug key のまま配布 | stg 用 signingConfig を設定 |
