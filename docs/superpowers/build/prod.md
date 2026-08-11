# ビルド手順 — 本番 (prod)

## 目的

本番 Web / API / Firebase 向けのストア提出用ビルド。

## 設定値

| 項目 | 値 |
|---|---|
| FLAVOR | `prod` |
| Android `--flavor` | `prod` |
| Web | `https://www.lunarabi.example` |
| API | `https://api.lunarabi.example` |
| Firebase Android | `android/app/src/prod/google-services.json` |
| Firebase iOS | `ios/config/prod/GoogleService-Info.plist` |
| iOS Configuration 対応 | `Release` → script が **prod** plist（または `Release-prod`） |

## 事前準備（必須）

1. **本番 Firebase** の json / plist を配置（プレースホルダ禁止）
2. Android **upload keystore** と `key.properties`（リポジトリに秘密をコミットしない）
3. iOS **配布用証明書 / Provisioning Profile** / App Store Connect アプリレコード
4. （payments）本番 IAP 商品 `lunarabi.credit.100` を Store に登録
5. （deeplink）`apple-app-site-association` / `assetlinks.json` を実ドメインへ設置
6. アプリアイコン・スプラッシュ・通知アイコンが本番デザインであること（branding プラン）

```bash
cd lunarabi
fvm flutter pub get
bash tool/forbid_firebase_options.sh
fvm flutter test
fvm flutter analyze
```

## Android

### AAB（Play 提出用）

```bash
cd lunarabi
fvm flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
```

成果物: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`

### 署名

`android/key.properties`（gitignore 推奨）例:

```properties
storePassword=***
keyPassword=***
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

`build.gradle.kts` の `prod` + `release` でこの設定を読むこと（scaffold 初期は debug 署名のままなので、提出前に必ず本番署名へ変更）。

## iOS

```bash
cd lunarabi
fvm flutter build ipa --dart-define=FLAVOR=prod --release
```

- Bundle ID: `com.wandit.lunarabi`
- Copy GoogleService-Info Phase が **prod** plist を入れていること
- Push: 本番 APNs キーが Firebase に紐づいていること

## 提出前チェックリスト

- [ ] `FLAVOR=prod` と `--flavor prod` の両方
- [ ] Web が `www.lunarabi.example`（または確定本番 URL）
- [ ] 本番 Firebase のみ参照
- [ ] 環境切替メニューが **出ない**（release）
- [ ] アイコン / スプラッシュ / 通知アイコンが本番素材
- [ ] IAP・外部決済の審査リスク（デジタルコンテンツ）をプロダクトが把握済み
- [ ] プライバシーポリシー / 権限説明文が Store に登録済み
- [ ] `forbid_firebase_options`・test・analyze がグリーン

## よくある失敗

| 症状 | 原因 | 対処 |
|---|---|---|
| 本番なのに dev URL | define 漏れ or debug メニュー残留ビルド | release + `FLAVOR=prod` |
| 通知アイコンが白い四角 | monochrome アセット未設定 | branding プランの Android `ic_stat_*` |
| iOS Universal Link 無効 | AASA 未設置 / Team ID 不一致 | deeplink 資料の well-known |
| Play に AAB 上げられない | 署名 / flavor 成果物パス違い | `prodRelease` を確認 |
