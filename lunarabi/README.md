# Lunarabi

`com.wandit.lunarabi` 向けの薄い WebView シェル（scaffold）。

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

## テスト

```bash
fvm flutter test
```

テストコードには、初めて読む人向けの日本語コメントを付けている。

- `test/core/env/app_config_test.dart` … 環境 URL / FLAVOR パース
- `test/core/navigation/host_guard_test.dart` … 開いてよい URL の判定
- `test/tool/forbid_firebase_options_test.dart` … FirebaseOptions 禁止の回帰

## 審査メモ（先出し）

アプリ内デジタルコンテンツでも、後続の payments ブランチで Store 外決済（GMO / 銀行振込）を出す予定。iOS ガイドライン 3.1.1 のリスクはプロダクト側で合意済み。
