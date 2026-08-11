# Lunarabi ビルド資料（環境別）

`com.wandit.lunarabi` を **dev / stg / prod** ごとにビルドするための手順書です。  
アプリ本体は `lunarabi/`（scaffold 以降のブランチ）。

## 環境一覧

| 環境 | Android flavor | `--dart-define=FLAVOR=` | Web ベース URL | API ベース URL | Firebase ファイル |
|---|---|---|---|---|---|
| 開発 | `dev` | `dev` | `https://dev.lunarabi.example` | `https://api-dev.lunarabi.example` | `android/app/src/dev/...` / `ios/config/dev/...` |
| 検証 | `stg` | `stg` | `https://stg.lunarabi.example` | `https://api-stg.lunarabi.example` | `android/app/src/stg/...` / `ios/config/stg/...` |
| 本番 | `prod` | `prod` | `https://www.lunarabi.example` | `https://api.lunarabi.example` | `android/app/src/prod/...` / `ios/config/prod/...` |

- applicationId / bundle ID は全環境共通: `com.wandit.lunarabi`
- ディープリンクホスト（予定）: `app.lunarabi.example`
- Flutter は FVM ピン留め（scaffold 時点: **3.44.9**。`.fvmrc` を正とする）

## 共通前提

```bash
cd lunarabi
fvm install          # .fvmrc のバージョンを入れる
fvm flutter pub get
bash tool/forbid_firebase_options.sh   # Dart FirebaseOptions 禁止チェック
```

### 必ず揃える 2 つ

1. **Android product flavor**（`--flavor`）… ネイティブ Firebase JSON の切り替え  
2. **Dart FLAVOR**（`--dart-define=FLAVOR=`）… WebView / API URL の切り替え  

片方だけ変えると「Firebase は stg なのに URL は prod」のようなズレが起きます。

### 環境別ページ

- [開発 (dev)](./dev.md)
- [検証 (stg)](./stg.md)
- [本番 (prod)](./prod.md)

### 関連プラン

- アプリアイコン / スプラッシュ / 通知アイコン: [../plans/2026-08-11-lunarabi-branding.md](../plans/2026-08-11-lunarabi-branding.md)
- ブランチ一覧: [../plans/README.md](../plans/README.md)
