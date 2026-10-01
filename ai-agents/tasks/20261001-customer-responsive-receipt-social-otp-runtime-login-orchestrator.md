# Superseded on 2026-10-01

The user confirmed testing was completed and requested task closure and main integration. This proposal will not be activated. See `ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-close-main-decision.md`. The original proposal below is retained as history.

# Local Runtime / Login Acceptance Proposal

Date: 2026-10-01 (Asia/Bangkok)
Target Agent: Orchestrator, **after explicit human authorization**
Active task: `customer-responsive-receipt-social-otp`
Status: **Prepared; NOT ACTIVATED / NOT DISPATCHED**

## Purpose and Activation Gate

Resolve QA-G02 without changing protected runtime data, credentials or configuration. QA-G01 is approved by `ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-contract-approval-decision.md`.

Before execution, record the user's authorization for the four local services below and permitted login side effects. Obtain the approved admin/customer account identifiers, role, tenant host and expected redirect; passwords/PIN/tokens must be supplied through an approved secure input, never committed or printed in chat/artifacts. Do not infer activation from this proposed task, contract approval, or the message saying QA completed.

After authorization, user relays this task to Orchestrator. Orchestrator prepares a narrowly owned runtime recovery/verification prompt, then QA verifies actual login and returns to Coordinator. No new milestone and no incidental application implementation.

## Proposed Service Scope

| Existing service | Port | Proposed action |
| --- | --- | --- |
| platform-api | 8000 | Start existing container after startup/source/mount check; verify API readiness. |
| back-office | 3100 | Start existing container after startup/mount check; verify login and admin-login redirect. |
| customer | configured 3000 | Start existing built Flutter/nginx container after image/port check; verify customer HTTP/login surface. |
| local-proxy | 80 | Start existing container after upstream/config/port check; verify approved tenant routing. |

Keep existing Postgres, Valkey, reverb, scrapers, worker/scheduler/support services and volumes in their observed states. No automatic dependency startup, image build/pull/recreation, port/config change or source cleanup. The root customer image has no source bind; identify its build and report any source mismatch. This stage verifies runtime/login availability, not installed/current-source or legacy Nuxt acceptance.

## Start / Preservation Gate

- Read AGENTS.md, the contract approval, prior contract QA report recovery proposal/prerequisite matrix, current Compose/runtime policy and this task.
- Canonical worktree `/Users/supakit/WorkSpace/www/newPaotang`, branch develop; fetch origin and inspect status/HEAD/origin. Expected baseline `c8f130cdcc1a1addc3a7526597bd7a17107d574d`, application diff `f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9`, OpenAPI `0e99748570a37c0164e6d5e9ebb8ff1dda36bbffba2f1273fa487da2e594d3d5`. If source differs, return the exact difference before relying on prior acceptance. Preserve dirty and untracked work; no merge/stash/reset/clean/stage/commit/push.
- Refresh selected live container image IDs/digests, commands, mounts, source labels, ports and running/stopped states; inspect intended startup code for migrations/seeds/account rewrites. Do not dump resolved environment or credentials. The proposed starts must not hide DB-writing startup hooks.
- Arrange a recoverable private backup of runtime DB and needed writable state before recovery/login. Keep backup outside the repository/evidence folder with restrictive permissions; do not print records/password hashes or delete volumes. Verify effective DB name is `newpaotang` for this read-only backup, not an assumed testing environment. No DB reset/seed/migration/stock generation/recall or record rewrite is allowed.
- Confirm intended port/tenant routing and secure approved login account. If containers are missing, startup/config/images are unsafe, ports conflict, or recovery needs rebuild/recreation, stop that part and return a concrete revised scope to Coordinator. Do not silently change the plan.
- Repeat `docker compose --dry-run -p newpaotang start platform-api back-office customer local-proxy` and verify it proposes only the four approved starts. The Coordinator simulation showed existing Postgres/Valkey health waits and no support/worker starts; all four services remained stopped afterward. If the new simulation lists any unapproved service start, return the exact difference before executing. Do not infer a real start from simulation output.

## Execution Once Authorized and Gates Pass

Use existing containers, in dependency order; `start` does not authorize creating/rebuilding them:

```sh
docker compose -p newpaotang start platform-api
# Verify API readiness before continuing.
docker compose -p newpaotang start back-office
docker compose -p newpaotang start customer
docker compose -p newpaotang start local-proxy
```

No `up --build`, recreation, root project down or worker/scheduler starts. If an already-running service is healthy, leave it running. Do not stop working services to recreate a previous failure state.

Verify HTTP routes and the approved tenant through the proxy. /login must load; /admin/login must return the expected /login redirect without a redirect loop. Use approved accounts to check actual API and UI login, role/tenant routing and the expected post-login/PIN destination. Avoid financial/stock/provider/SMS writes. Allowed auth-side effects are only those explicitly approved (session, auth audit and last-login).

Do not guess or restore seeded/default passwords. Preserve the earlier `seeded-logins: failed` observation as a legacy check; judge current approved-account login independently. If an approved account or its password/PIN is unavailable, complete permitted unauthenticated readiness checks and retain the authenticated gate as BLOCKED.

No application tests/builds or destructive test setup are needed for this runtime availability stage. All application commands, if specifically required by the activated prompt, must be in Docker. Do not run platform:smoke unless its cache-probe side effect is explicitly included in the authorized validation scope.

## QA Evidence / Return

Write a new runtime/login report and artifact directory under:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-runtime-login-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-runtime-login-qa/**
```

Include user authorization/scope, before/after service identities/statuses, exact source/image mismatch limits, safe backup location/verification without contents, DB/volume/account/config preservation, actual HTTP/redirect/API/UI outcomes, account role/tenant identifiers only, observed auth side effects and remaining blockers. Redact passwords, PIN, OTP, tokens, cookies and sensitive account values from logs/screenshots.

Do not overwrite prior QA reports/manifests or alter the contract/application source to pass login. Return any defects through Orchestrator to Coordinator. QA-G02 may pass only for checks actually executed; QA-G03 and overall release gates remain separate. **Next Agent: Coordinator.**
