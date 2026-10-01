# Customer Receipt / Social OTP Contract Follow-Up

Date: 2026-10-01 (Asia/Bangkok)
Target Agent: Orchestrator
Active task: `customer-responsive-receipt-social-otp` (same milestone)
Next sequence: **Orchestrator -> QA Tester -> Coordinator**

This is a board instruction for the user to send to Orchestrator chat. It does not start or message an agent. Coordinator has corrected the contract documentation; prepare a targeted QA prompt and hand back independent results. No worker implementation is assigned.

## Required Reading

- `AGENTS.md`
- `ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-qa-review-decision.md`
- `ai-agents/handoffs/20261001-customer-responsive-receipt-social-otp-orchestrator-coordinator-handoff.md`
- `ai-agents/reports/20261001-customer-responsive-receipt-social-otp-qa-report.md`
- `docs/openapi.yaml` (both phone-link endpoints and the request/response schemas)
- `docs/customer-api-integration-map.md` (social phone-link row)
- `ai-agents/workflow/handoff-protocol.md` and `docs/docker-runtime-policy.md`

## Worktree Start Gate

Use the canonical worktree only:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git rev-parse --show-toplevel
git rev-parse HEAD
git rev-parse origin/develop
git diff --check
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256
```

Expected branch `develop`; HEAD/origin both `c8f130cdcc1a1addc3a7526597bd7a17107d574d`. Expected tracked application diff hash `f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9`. Verify the untracked source hashes against the original QA report too; HEAD alone omits the delivery. The corrected contract and Coordinator records are intentional local additions.

If the baseline changes, identify the exact changed files and return to Coordinator before relying on earlier QA. Do not merge over, stash, clean, reset, stage, commit or push the dirty delivery. Root AGENTS.md overrides historical automatic Git and reseed examples. This continuation keeps the existing task open and does not open a new milestone.

## QA Assignment

1. Independently parse/inspect OpenAPI and resolve its references; validate example request/response shapes with an appropriate schema tool in an isolated Docker runner if available. Record tools and distinguish structural file validation from full OpenAPI validation. Do not add dependencies to the application or upgrade lockfiles.
2. Check both the generic endpoint (Google/Apple/Facebook/LINE) and legacy LINE endpoint against actual controllers/services and both clients. Confirm universal token/phone/OTP fields, boolean/default `existing_only`, HTTP 200 auth-session/registration-required union, and top-level JSON shape.
3. Confirm required new-customer member fields/terms are documented conditionally on account state. Minimal probes and legacy probes with blank member fields/false terms must fit the request schema. Full registration must still collect/send matching password confirmation; the documented backend omission fallback must match current code. Do not change business/security rules to make a schema test pass.
4. Confirm OTP validation precedes account disclosure, new-phone probes preserve both tokens, success consumes them once, profile/password are preserved for existing accounts, and PIN/session activation plus tenant/provider/identity/suspension guards remain intact.
5. Reuse original API/Flutter/fixture evidence only after confirming its application snapshot and manifest match. Run additional focused Docker tests only for missing assertions or changed source; documentation correction alone does not require rebuilding Flutter/Nuxt or rerunning the full suite. Label prior results as prior QA evidence.
6. Refresh QA-G02 preflight with read-only Docker inventory and unauthenticated login HTTP checks. Preserve stopped services, DB/accounts/cache/volumes/configuration/ports. If stopped or credentials are missing, write the recovery/login scope and remaining prerequisite; do not start services or seed accounts.
7. List remaining QA-G03 criteria and exact device/build/tenant/account/phone prerequisites. Do not install, send SMS, link real accounts, purchase, create credentials or deploy. Preserve NOT TESTED distinctions for native/provider/authenticated Nuxt/production timing.

Suggested read-only runtime preflight:

```sh
docker compose -p newpaotang config --services
docker compose -p newpaotang ps --all
curl --max-time 5 -i -sS http://localhost:3100/login
curl --max-time 5 -i -sS http://localhost:3100/admin/login
curl --max-time 5 -i -sS http://localhost:3000/
```

Do not print full resolved Compose environment, secrets, password hashes, auth response tokens or OTP. Container IDs/image labels/mount paths/port states are sufficient for inventory.

If a missing assertion requires a DB-backed API test, first verify effective database/environment inside the container using the original QA task's bootstrap check. Required values are `newpaotang_test` and `testing`. Then use:

```sh
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php artisan test --env=testing --do-not-cache-result --filter='CustomerSocialAuthServiceTest|CustomerSmsOtpTest'
```

Do not run destructive commands or migrations for this documentation follow-up. Runtime `newpaotang` stays protected; `--env=testing` alone is insufficient.

## Ownership / Outputs

Orchestrator may write the specific QA prompt and follow-up dispatch/return handoffs under `ai-agents/tasks` and `ai-agents/handoffs`. QA may add:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/**
```

Keep the original QA report/artifacts/manifest, delivery source, OpenAPI/integration map and Coordinator decision unchanged. Route any document or implementation discrepancy to Coordinator with precise file/line evidence rather than fixing it outside this scope.

Report exact source/doc hashes, files added, commands/results, evidence reused vs newly executed, QA-G01 PASS/FAIL/BLOCKED, Runtime Restore / Login Smoke limitations, QA-G02/QA-G03 states, known risks, and **Next Agent: Coordinator**. QA-G01 may pass independently; overall acceptance remains BLOCKED while required runtime/native/provider gates are unresolved.
