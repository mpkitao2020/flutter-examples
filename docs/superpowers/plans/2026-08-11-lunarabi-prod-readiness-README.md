# Lunarabi 本番運用クロージャ — プラン索引（敵対的検証反映）

> Spec: [../specs/2026-08-11-lunarabi-prod-readiness-design.md](../specs/2026-08-11-lunarabi-prod-readiness-design.md)

| 順 | Branch | Plan | Base |
|---|---|---|---|
| 1 | `cursor/lunarabi-prod-readiness-impl-c3bc` | config + secrets + payment + gates を同一ブランチで実装可（分割コミット） | `cursor/lunarabi-nav-icons-ios-caps-c3bc` |

詳細タスクは各 plan ファイル。**必須**: すべての shippable release は `lunarabi/tool/verify_release_inputs.sh` を通す。

## Critical fixes from plan adversarial review

- No debug signing fallback on shippable release
- Native deep link hosts substituted + tested (not README-only)
- Firebase placeholder connected to release preflight
- Web gates require evidence manifest (docs alone ≠ closed)
