# Lunarabi branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** アプリアイコン、スプラッシュ、プッシュ通知アイコンを環境共通で設定し、差し替え手順を残す。

**Architecture:** ソース画像を `lunarabi/branding/` に置き、`flutter_launcher_icons` / `flutter_native_splash` で Android・iOS へ生成。通知アイコンは Android 用白単色（アルファ）アセットを別途用意。初期は仮アセット、後から同パス差し替え。

**Tech Stack:** `flutter_launcher_icons`, `flutter_native_splash`, FVM

**Branch:** `cursor/lunarabi-branding-c3bc`  
**Base:** scaffold マージ後の `develop`（bridge 前後どちらでも可。icons は独立）  
**Index:** [README.md](./README.md)  
**Build docs:** [../build/README.md](../build/README.md)

## Global Constraints

- 仮アセット可。ファイル名と生成コマンドを固定し、デザイン差し替えは上書きのみ
- applicationId / bundle ID は変えない
- 通知アイコン（Android）は **白 + 透明背景**（カラー画像はシステムに潰される）
- テストは「生成物パスが存在する」程度のスモーク + README 手順
- package: `com.wandit.lunarabi`

---

### Task 1: Source assets

**Files:**
- Create: `lunarabi/branding/README.md`（差し替え手順）
- Create: `lunarabi/branding/app_icon.png`（1024×1024 相当の仮画像）
- Create: `lunarabi/branding/splash.png`（仮）
- Create: `lunarabi/branding/splash_dark.png`（任意。無ければ splash を流用）
- Create: `lunarabi/branding/notification_icon.png`（24×24〜96×96 の白単色）

仮画像は単色背景 + 中央に "L" などのシンプルマークでよい（ImageMagick / スクリプト可）。

- [ ] **Step 1: 生成スクリプトまたは手動で PNG を配置**
- [ ] **Step 2: branding/README に「このファイルを差し替えて Task 2 を再実行」と書く**
- [ ] **Step 3: Commit**

```bash
git add lunarabi/branding
git commit -m "feat(lunarabi): add placeholder branding source assets"
```

---

### Task 2: Launcher icons

**Files:**
- Modify: `lunarabi/pubspec.yaml`（dev_dependency + flutter_launcher_icons 設定）
- Generated: Android mipmap / iOS AppIcon.appiconset

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: branding/app_icon.png
  adaptive_icon_background: "#0B1F33"
  adaptive_icon_foreground: branding/app_icon.png
  remove_alpha_ios: true
```

- [ ] **Step 1: pub add + 設定**
- [ ] **Step 2: `fvm flutter pub run flutter_launcher_icons`**
- [ ] **Step 3: 生成パスが存在することを確認する軽いテスト or スクリプト**
- [ ] **Step 4: Commit**

```bash
git commit -m "feat(lunarabi): generate app launcher icons"
```

---

### Task 3: Native splash

**Files:**
- Modify: `pubspec.yaml`（flutter_native_splash）
- Generated: Android launch backgrounds / iOS LaunchImage 等

```yaml
flutter_native_splash:
  color: "#0B1F33"
  image: branding/splash.png
  color_dark: "#0B1F33"
  image_dark: branding/splash.png
  android_12:
    color: "#0B1F33"
    image: branding/splash.png
```

- [ ] **Step 1: 設定して `fvm flutter pub run flutter_native_splash:create`**
- [ ] **Step 2: Commit**

```bash
git commit -m "feat(lunarabi): configure native splash screens"
```

---

### Task 4: Push notification small icon (Android)

**Files:**
- Create: `lunarabi/android/app/src/main/res/drawable/ic_stat_lunarabi.png`（または vector）
- Modify: AndroidManifest / デフォルト通知チャネル設定（push ブランチと重複する場合は meta-data だけ先置き）

```xml
<meta-data
  android:name="com.google.firebase.messaging.default_notification_icon"
  android:resource="@drawable/ic_stat_lunarabi" />
```

iOS の通知アイコンはアプリアイコンが使われるため追加作業なし（文書化のみ）。

- [ ] **Step 1: 白単色アイコン配置 + manifest meta-data**
- [ ] **Step 2: build docs（dev/stg/prod）に「通知アイコン確認」を追記済みか確認**
- [ ] **Step 3: Commit**

```bash
git commit -m "feat(lunarabi): add Android push notification status icon"
```

---

### Task 5: Document regeneration

**Files:**
- Modify: `lunarabi/README.md`
- Ensure `docs/superpowers/build/*.md` から branding へリンク

```bash
# 差し替え後の再生成
fvm flutter pub run flutter_launcher_icons
fvm flutter pub run flutter_native_splash:create
```

- [ ] **Step 1: README 更新**
- [ ] **Step 2: Commit**

```bash
git commit -m "docs(lunarabi): document branding asset regeneration"
```

---

## Self-review checklist

- アイコン・スプラッシュ・通知アイコンが揃っている
- 差し替え手順が branding/README と build 資料から辿れる
- 通知アイコンが monochrome である旨を明記
