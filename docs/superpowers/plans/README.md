# Lunarabi 実装プラン一覧（ブランチ対応）

各機能は **1 ブランチ = 1 プランファイル = 1 PR** とする。  
実装前にこの一覧と対象プランを読む。

## ブランチとプラン

| 順 | Git ブランチ | プランファイル | 成果物 |
|---|---|---|---|
| 0 | `cursor/lunarabi-design-plans-c3bc` | （本ディレクトリ全体） | 設計・プラン・フロント向けブリッジ資料・ビルド資料 |
| 1 | `cursor/lunarabi-scaffold-c3bc` | [2026-08-11-lunarabi-scaffold.md](./2026-08-11-lunarabi-scaffold.md) | FVM、env、WebView、HostGuard、Firebase 置き場 |
| 2 | `cursor/lunarabi-branding-c3bc` | [2026-08-11-lunarabi-branding.md](./2026-08-11-lunarabi-branding.md) | アプリアイコン、スプラッシュ、通知アイコン |
| 3 | `cursor/lunarabi-bridge-c3bc` | [2026-08-11-lunarabi-bridge.md](./2026-08-11-lunarabi-bridge.md) | ボトムナビ＋JS ブリッジ（表示／バッジ／トークン） |
| 4 | `cursor/lunarabi-deeplink-c3bc` | [2026-08-11-lunarabi-deeplink.md](./2026-08-11-lunarabi-deeplink.md) | Universal / App Links |
| 5 | `cursor/lunarabi-push-c3bc` | [2026-08-11-lunarabi-push.md](./2026-08-11-lunarabi-push.md) | FCM（トークンはブリッジ経由で Web へ） |
| 6 | `cursor/lunarabi-payments-c3bc` | [2026-08-11-lunarabi-payments.md](./2026-08-11-lunarabi-payments.md) | IAP / GMO / あおぞら |

## 依存関係

```text
develop
  └─ scaffold
       ├─ branding        ← アイコン / スプラッシュ / 通知アイコン（独立して可）
       └─ bridge          ← フロント向け契約のネイティブ実装
            ├─ deeplink
            ├─ push       ← bridge の pushToken 受け渡しを使う
            └─ payments   ← deeplink の GMO complete に依存
```

## フロント（Web）向け資料

ネイティブ実装とは別に、Web 側が実装するときの契約書:

- [../frontend/2026-08-11-lunarabi-webview-bridge-contract.md](../frontend/2026-08-11-lunarabi-webview-bridge-contract.md)

## ビルド資料（環境別）

- [../build/README.md](../build/README.md)
- [../build/dev.md](../build/dev.md)
- [../build/stg.md](../build/stg.md)
- [../build/prod.md](../build/prod.md)

## 設計仕様

- [../specs/2026-08-11-lunarabi-webview-design.md](../specs/2026-08-11-lunarabi-webview-design.md)

## 運用ルール

- base branch は原則 `develop`（前機能マージ後）
- ブランチ名接尾辞は `-c3bc`
- プランの Task を上から TDD で消化する
- 敵対的レビュー APPROVE 後にコミット／プッシュ
