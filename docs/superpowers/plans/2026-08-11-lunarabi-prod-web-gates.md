# Lunarabi prod web + external gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** README External release gates を「空欄の表」から、実行可能な受け入れ手順と証拠テンプレに落とし、Web/DevOps が staging で閉じられる状態にする。Flutter リポジトリ側は契約ドキュメントとチェックリスト自動化（可能な範囲）のみ。

**Architecture:** このプランの成果物は主に docs + README チェックリスト更新 + 手動検証ランブック。SPA/Laravel 実装は別リポジトリでもよいが、**契約フィールドと証拠フォーマットは本リポジトリが正**とする。

**Tech Stack:** existing bridge contract markdown, curl, browser DevTools

**Branch:** `cursor/lunarabi-prod-web-gates-c3bc`  
**Base:** after prod-payment-http（docs のみなら並行可）

## Global Constraints

- Contract source of truth: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`
- Every gate row needs: evidence path, owner email/name, ISO date, signOff initials
- Do not mark Flutter unit tests as satisfying Web gates
- Spec: prod-readiness design

---

### Task 1: Acceptance runbook file

**Files:**
- Create: `docs/superpowers/runbooks/2026-08-11-lunarabi-prod-release-gates.md`
- Modify: `lunarabi/README.md`（runbook へリンク）

**Runbook sections (must include exact steps):**

1. **Firebase swap**
   - Download prod `google-services.json` / `GoogleService-Info.plist`
   - Overwrite `lunarabi/android/app/src/prod/` and `lunarabi/ios/config/prod/`
   - Run `bash tool/forbid_release_placeholders.sh` → expect exit 0
   - Evidence: script stdout + Firebase project ID screenshot path

2. **Domains + AASA + assetlinks**
   - `curl -sS https://<deepLinkHost>/.well-known/apple-app-site-association | tee evidence/aasa.json`
   - `curl -sS https://<deepLinkHost>/.well-known/assetlinks.json | tee evidence/assetlinks.json`
   - Confirm `appID` / `package_name` match `com.wandit.lunarabi`
   - Evidence: saved JSON files

3. **SPA frame / CSP**
   - On trusted web origin, DevTools → Network → document response headers
   - Require evidence of policy that blocks untrusted parent/embedding as agreed (e.g. `Content-Security-Policy` containing `frame-ancestors` suitable for the product)
   - Confirm no untrusted iframe can call `window.LunarabiBridge`
   - Evidence: header dump text file

4. **Web auth restore**
   - Login on device → kill app → relaunch → confirm `auth.getStoredToken` after `bridge.ready` (Safari/Chrome remote debug or Web log)
   - Force 401 → confirm `auth.clearBearerToken`
   - Evidence: redacted log snippet

5. **Web FCM register**
   - Receive `push.setToken` with `platform`
   - POST to registration API (name the endpoint in evidence form; Laravel team fills actual path)
   - Evidence: request/response redacted

6. **Web IAP verify**
   - Sandbox purchase → `iap.purchaseUpdated` → API verify → `iap.confirmResult ok:true` → `iap.finished completed`
   - Evidence: staging log with purchaseKey redaction rules

7. **Signing**
   - Android: `apksigner verify --print-certs` on AAB/APK
   - iOS: archive entitlements dump showing `aps-environment=production`
   - Evidence: command output files

8. **Japan external payments**
   - Product/legal sign-off that GMO/あおぞら disclosure and App Review notes are approved
   - Evidence: link to internal doc + approver name

- [ ] **Step 1: Write the runbook with the eight sections above (full commands, not summaries)**
- [ ] **Step 2: Link from README checklist**
- [ ] **Step 3: Commit** `docs: add production release gates runbook`

---

### Task 2: Evidence template table in README

**Files:**
- Modify: `lunarabi/README.md` External release gates table — add column `evidence_path` example `docs/evidence/YYYY-MM-DD/<gate>.txt`
- Create: `docs/evidence/README.md` explaining gitignore of secrets; commit only redacted stubs if needed
- Modify: `.gitignore` to ignore `docs/evidence/**` except `docs/evidence/README.md`

- [ ] **Step 1: gitignore evidence dumps**
- [ ] **Step 2: README table update**
- [ ] **Step 3: Commit** `docs: evidence paths for external release gates`

---

### Task 3: Bridge contract Web obligation snippets

**Files:**
- Modify: `docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md`

Add copy-paste JS sketches:

```js
window.__LUNARABI_NATIVE_EVENT__ = async (msg) => {
  if (msg.type === "bridge.ready") {
    const res = await window.LunarabiBridge.post({
      type: "auth.getStoredToken",
      requestId: crypto.randomUUID(),
      payload: {},
    });
    // apply Bearer to API client
  }
  if (msg.type === "push.setToken") {
    await api.registerPush({ token: msg.payload.token, platform: msg.payload.platform });
  }
  if (msg.type === "iap.purchaseUpdated") {
    const ok = await api.verifyIap(msg.payload);
    await window.LunarabiBridge.post({
      type: "iap.confirmResult",
      requestId: crypto.randomUUID(),
      payload: { purchaseKey: msg.payload.purchaseKey, ok },
    });
  }
};
```

- [ ] **Step 1: Insert snippets under Web obligations**
- [ ] **Step 2: Commit** `docs: SPA handler sketches for auth FCM IAP`

---

### Task 4: Flutter deliverables checklist tick guidance

**Files:**
- Modify: `lunarabi/README.md` Flutter branch deliverables — document the exact test commands that constitute acceptance:

```bash
cd lunarabi
fvm flutter test test/features/webview test/features/bridge
fvm flutter test test/features/push
fvm flutter test test/features/payments
fvm flutter test test/branding test/ios
```

- [ ] **Step 1: Update checklist with commands**
- [ ] **Step 2: Commit** `docs(lunarabi): acceptance commands for Flutter deliverables`

---

## Self-review checklist

- [ ] Every Critical external gate has a runbook section with a command or explicit sign-off artifact
- [ ] No claim that unit tests close Web gates
- [ ] Secrets not instructed to be committed
