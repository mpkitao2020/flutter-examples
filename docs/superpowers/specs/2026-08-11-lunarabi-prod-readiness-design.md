# Lunarabi 本番運用クロージャ（2026-08-11）

対象 tip: `cursor/lunarabi-nav-icons-ios-caps-c3bc`  
根拠: 敵対的検証「現状のまま本番運用不可」

## Goal

Store 提出可能な release ビルドと、Web/バックエンド結合の受け入れ証拠を揃える。  
Flutter 硬化コードは揃っている。足りないのは **実設定・署名・Web 契約実装・決済 release 経路**。

## Non-goals

- Laravel 本体の全面実装（エンドポイント契約と疎通確認まで）
- GMO／あおぞらの App Review 最終通過そのもの（準備物とゲートはプランに含む）
- 本番硬化ブランチ 1–5 の再実装

## Critical blockers → plans

| Critical | Plan |
|---|---|
| `.example` ドメイン | [prod-config](../plans/2026-08-11-lunarabi-prod-config.md) |
| Firebase placeholder | [prod-secrets-signing](../plans/2026-08-11-lunarabi-prod-secrets-signing.md) |
| Android release = debug 署名 | [prod-secrets-signing](../plans/2026-08-11-lunarabi-prod-secrets-signing.md) |
| Web auth / FCM / IAP / CSP 未実装 | [prod-web-gates](../plans/2026-08-11-lunarabi-prod-web-gates.md) |
| release `FailClosedPaymentBackend` + GMO DL confirm | [prod-payment-http](../plans/2026-08-11-lunarabi-prod-payment-http.md) |
| 日本向け外部決済審査 | [prod-web-gates](../plans/2026-08-11-lunarabi-prod-web-gates.md) Task Store |

## Product decisions locked for this program

1. **ドメイン／API は dart-define で注入**し、release では `.example` を起動拒否する
2. **IAP 検証は引き続き Web**（既存 bridge）。Flutter はレシート通知と gated complete
3. **GMO／あおぞらは Web UI**。ただしアプリが受け取る GMO complete ディープリンクの `confirmGmo` は release でも HTTP で実 API を呼ぶ（FailClosed のままでは完了 DL が死ぬ）
4. **ネイティブ決済シートは復活させない**（AppBar 購入は削除済みのまま）
5. Firebase／署名の実ファイルは **リポジトリに秘密をコミットしない**。ローカル／CI 秘密経路で差し替え、ガードテストで placeholder を拒否

## Success criteria

- release ビルドが実ドメインで WebView を開ける
- Firebase 実プロジェクトで FCM トークンが取れる（少なくとも staging）
- Android/iOS が非 debug 署名で archive / AAB できる
- Web が `bridge.ready` → auth restore / push register / IAP verify を staging で実証
- GMO complete ディープリンクが release で `confirmGmo` 成功（HTTP client）
- README External release gates の evidence / owner / date / signOff が埋まる

## Execution order

1. prod-config  
2. prod-secrets-signing（Firebase 差し替え手順 + signing）  
3. prod-payment-http  
4. prod-web-gates（Web/DevOps/審査。並行可だが 1–3 の契約が先）
