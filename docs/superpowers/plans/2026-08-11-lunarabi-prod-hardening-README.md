# Lunarabi 本番硬化プラン索引

> Spec: [../specs/2026-08-11-lunarabi-prod-hardening-design.md](../specs/2026-08-11-lunarabi-prod-hardening-design.md)

実装は **依存順の5ブランチ**。各プランは単独でテスト可能な Flutter 成果物を出す。Web/バックエンド義務は **External release gates** であり、Flutter テスト成功＝本番完了ではない。

| 順 | Branch | Plan | Base |
|---|---|---|---|
| 1 | `cursor/lunarabi-webview-guard-c3bc` | [webview-guard](./2026-08-11-lunarabi-webview-guard.md) | `cursor/lunarabi-payments-followups-c3bc` |
| 2 | `cursor/lunarabi-auth-storage-c3bc` | [auth-storage](./2026-08-11-lunarabi-auth-storage.md) | after 1 |
| 3 | `cursor/lunarabi-fcm-web-register-c3bc` | [fcm-web-register](./2026-08-11-lunarabi-fcm-web-register.md) | after 2 |
| 4 | `cursor/lunarabi-iap-bridge-c3bc` | [iap-bridge](./2026-08-11-lunarabi-iap-bridge.md) | after 3 |
| 5 | `cursor/lunarabi-nav-icons-ios-caps-c3bc` | [nav-icons-ios-caps](./2026-08-11-lunarabi-nav-icons-ios-caps.md) | after 4 |

## Frontend contract

- Lands on branch 2: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`
- Updated on branches 3–4 as BridgeTypes change
- Dart lock: `bridge_contract_surface_test.dart` (manually aligned)

## Out of this program / External release gates

- GMO / あおぞら Store 審査対応
- 実 Firebase / 実ドメイン差し替え
- Laravel 本体
- SPA untrusted-frame / CSP policy for JS bridge
- Web: auth restore UX, FCM register API, IAP verify API
- Production APNs entitlements if not config-switched in branch 5

## Execution order

1. Adversarial approve on this design+plans, then Subagent-Driven per branch
2. Complete branch 1 tests + task review
3. Stack branch 2 … 5 similarly
4. Final whole-branch review; external gates remain open until Web/DevOps owners close them
