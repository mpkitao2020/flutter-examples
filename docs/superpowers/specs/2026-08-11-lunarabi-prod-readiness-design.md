# Lunarabi 本番運用クロージャ（2026-08-11）— 敵対的検証反映版

対象 tip: `cursor/lunarabi-nav-icons-ios-caps-c3bc`  
根拠: 本番運用不可判定 + 修正プラン敵対的検証 REJECT（署名/native host/Firebase gate/Web evidence）

## Goal

Shippable release は **単一の preflight** `tool/verify_release_inputs.sh` を通らない限り作れない／出荷扱いにできない状態にする。  
実シークレットや Web staging 証拠が無い環境では preflight が fail し続けるのが正しい。

## Non-goals

- このリポジトリ内だけで実 Firebase/実ドメイン/実 Web を捏造して「本番相当」と偽ること
- Laravel フル実装
- App Review 通過そのもの

## Hard release gates（コードで強制）

1. `tool/verify_release_inputs.sh`（必須 entrypoint）が次を検証して fail:
   - dart-define 相当の env: `LUNARABI_WEB_BASE_URL`, `LUNARABI_API_BASE_URL`, `LUNARABI_DEEP_LINK_HOST` が absolute https / host-only で、placeholder でない
   - AndroidManifest 解決後ホストおよび iOS Release entitlements の applinks に `.example` が無い（materialize 後）
   - prod Firebase ファイルに `placeholder` が無い
   - Android release signing 入力が揃っている（debug fallback 無し）
   - `docs/evidence/release_gates.manifest.json` の全 gate が `status=closed` かつ evidence/owner/date/signOff 非空
2. Gradle `prodRelease`: signing 未設定なら **ビルド失敗**（debug に落とさない）
3. Gradle release: `LUNARABI_DEEP_LINK_HOST` 未設定または `.example` なら **ビルド失敗**
4. Runtime: `AppConfig.assertReleaseHosts` が release で `.example` / 不正 URL shape を拒否

## Product decisions

1. ドメインは dart-define / 同名 env で注入
2. IAP 検証は Web bridge のまま。`HttpPaymentBackendClient.confirmIap` は UnsupportedError。legacy `IapPurchaseService.buy(...confirmIap...)` は test-only 隔離
3. GMO/あおぞら UI は Web。アプリの GMO complete DL の `confirmGmo` は HTTP
4. Web gates は **docs だけでは closed にならない**。manifest verifier が証拠を要求する

## Success criteria

- 現ツリー（placeholder のまま）で `verify_release_inputs.sh` が非ゼロ
- 実入力を揃えたときだけ preflight がゼロ（運用者作業）
- `fvm flutter test` は常に green（unit は preflight 非依存。detector テストは「現状 fail すること」を固定）
- 敵対的再検証で「ガード欠落」系 Critical がゼロ。残るのは「実 evidence 未投入」のみで、それは preflight がブロックする
