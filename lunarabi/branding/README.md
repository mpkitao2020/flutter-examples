# Branding source assets

仮アセットです。本番デザインができたら **同じファイル名で上書き** し、下の再生成コマンドを実行してください。

| ファイル | 用途 | 推奨サイズ |
|---|---|---|
| `app_icon.png` | アプリアイコン元画像 | 1024×1024 |
| `splash.png` | スプラッシュ中央画像 | 縦長でも可（例 1284×2778） |
| `splash_dark.png` | ダーク用（現状は splash と同内容可） | splash と同じ |
| `notification_icon.png` | Android 通知の小さいアイコン | 96×96、**白＋透明背景のみ** |
| `nav/home.svg` | ボトムナビ: ホーム | 24×24、単色 |
| `nav/search.svg` | ボトムナビ: 検索 | 24×24、単色 |
| `nav/notify.svg` | ボトムナビ: 通知 | 24×24、単色 |
| `nav/account.svg` | ボトムナビ: アカウント | 24×24、単色 |

`branding/nav/*.svg` は Flutter の asset として登録済みです。本番デザインができたら同じファイル名で上書きしてください。

## 差し替え後の再生成

```bash
cd lunarabi
fvm flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
# 通知アイコンは drawable へコピー（変更時）
cp branding/notification_icon.png android/app/src/main/res/drawable/ic_stat_lunarabi.png
```

色の基準（仮）: 背景 `#0B1F33`
