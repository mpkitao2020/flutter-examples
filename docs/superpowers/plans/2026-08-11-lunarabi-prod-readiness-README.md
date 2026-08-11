# Lunarabi 本番運用クロージャ — プラン索引

> Spec: [../specs/2026-08-11-lunarabi-prod-readiness-design.md](../specs/2026-08-11-lunarabi-prod-readiness-design.md)

敵対的検証の結論「現状では本番運用不可」を閉じるための依存順プラン。

| 順 | Branch（予定） | Plan | Base |
|---|---|---|---|
| 1 | `cursor/lunarabi-prod-config-c3bc` | [prod-config](./2026-08-11-lunarabi-prod-config.md) | `cursor/lunarabi-nav-icons-ios-caps-c3bc` |
| 2 | `cursor/lunarabi-prod-secrets-signing-c3bc` | [prod-secrets-signing](./2026-08-11-lunarabi-prod-secrets-signing.md) | after 1 |
| 3 | `cursor/lunarabi-prod-payment-http-c3bc` | [prod-payment-http](./2026-08-11-lunarabi-prod-payment-http.md) | after 2 |
| 4 | `cursor/lunarabi-prod-web-gates-c3bc`（docs）+ Web/DevOps 作業 | [prod-web-gates](./2026-08-11-lunarabi-prod-web-gates.md) | after 3（Web は並行可） |

## Already done (do not redo)

本番硬化 Flutter ブランチ 1–5（webview-guard → nav-icons-ios-caps）。

## Out of program

- Laravel フル実装
- App Review 通過そのもの（ゲート準備まで）
