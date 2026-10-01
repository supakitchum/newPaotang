# customer-responsive-receipt-social-otp-contract - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Continue the same milestone under:

```text
ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-qa-review-decision.md
ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-contract-review-orchestrator.md
```

Coordinator confirmed the delivered existing-phone flow and corrected its contract documentation. Independently verify QA-G01, refresh read-only QA-G02 preflight, and prepare the missing QA-G03 acceptance prerequisites. No Backend/BO/Customer implementation is assigned and no chat has been started automatically.

## Objective

Determine whether the corrected OpenAPI/integration map accurately describe the unchanged services, controllers, and clients. Report QA-G01 independently from the overall acceptance status; overall acceptance remains BLOCKED while applicable runtime/native/provider gates are unresolved.

## Source Of Truth

- AGENTS.md and docs/docker-runtime-policy.md
- ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-qa-review-decision.md
- ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-contract-review-orchestrator.md
- ai-agents/reports/20261001-customer-responsive-receipt-social-otp-qa-report.md
- ai-agents/handoffs/20261001-customer-responsive-receipt-social-otp-orchestrator-coordinator-handoff.md
- ai-agents/workflow/handoff-protocol.md and ai-agents/roles/qa-tester.md
- docs/openapi.yaml and docs/customer-api-integration-map.md
- apps/platform-api/routes/api.php and the auth controllers/services they reference
- apps/customer_flutter/lib/core/auth/auth_repository.dart
- apps/customer_flutter/lib/features/auth/presentation/line_auth_screens.dart
- apps/customer/composables/usePlatformApi.ts and apps/customer/pages/line/link-phone.vue

## Worktree Start Gate

Use only `/Users/supakit/WorkSpace/www/newPaotang`. Freshly fetched dispatch baseline:

```text
branch: develop
HEAD and origin/develop: c8f130cdcc1a1addc3a7526597bd7a17107d574d
status: dirty; intentional local delivery, QA, and Coordinator docs preserved
tracked application diff SHA-256:
f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9
docs/openapi.yaml SHA-256:
7a6f6ec86df0cdfcd14a37489799553f7abafbc09c68e0b77e101f111558682f
docs/customer-api-integration-map.md SHA-256:
f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac
original QA report SHA-256:
20313844c6d61834fa36c7a7a95bce5650fb10d5911463fa6ac27995eeb17c5c
```

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
git diff --check
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256
shasum -a 256 docs/openapi.yaml docs/customer-api-integration-map.md ai-agents/reports/20261001-customer-responsive-receipt-social-otp-qa-report.md
```

Verify the untracked customer logos, news preloader, receipt logo widget and preview hashes against the original QA report. Orchestrator confirmed those hashes and all 269 original artifact checksums at dispatch. HEAD alone omits the delivery. If baseline/source/doc hashes differ, identify exact changed files and return to Coordinator before relying on prior QA. Do not merge, stash, reset, clean, stage, commit or push the dirty delivery.

## Scope

### QA-G01: Contract Verification

1. Independently parse OpenAPI, resolve internal references, and inspect both phone-link paths and `CustomerSocialLinkPhoneRequest`, `CustomerSocialLinkPhoneResponse`, `CustomerSocialRegistrationRequiredResponse`, and `CustomerAuthResponse`.
2. Use a suitable schema validator in an isolated Docker runner if available. Test minimal existing-phone probe, legacy probe with blank member fields/false terms, and complete new-member request. Validate both HTTP 200 response branches and their actual top-level JSON shape, not just service-internal `resource` arrays. Distinguish YAML/ref checks from full OpenAPI/schema validation; record unavailable tooling and any unperformed checks explicitly.
3. Trace generic Google/Apple/Facebook/LINE and legacy LINE routes through controllers/services and both clients. Universal fields are `link_token`, `phone`, and register-purpose `otp_verification_token`; `existing_only` is a boolean defaulting to false when omitted. Both endpoints must describe session or `registration_required: true` outcomes.
4. New-member requirements depend on tenant account state. An active existing account can link without member fields. A new-phone probe creates no customer/session and consumes neither token. Subsequent registration still requires valid names/password/terms; clients collect/send matching password confirmation. Verify the documented omission fallback matches the current backend without weakening client validation. Blank legacy probe fields/false terms must not be falsely rejected by the request schema.
5. Verify OTP validation before account disclosure; phone/tenant/register-purpose/TTL/consumption checks; suspension/inactivity, identity conflict, provider-mismatch safeguards; one-time consumption on success; existing profile/password preservation; PIN/session activation and safe redirect behavior. Do not infer real-provider success from fixtures.
6. Check integration-map prose and endpoint response/request documentation against these traces. Report discrepancies with precise file/line evidence to Coordinator; do not fix source or documents.
7. Reuse original API/Flutter/fixture results only after snapshot and manifest verification. Label them prior QA evidence. Documentation-only changes do not require full Flutter/Nuxt rebuilds or a full suite rerun. Additional focused Docker tests are allowed only for missing assertions or changed source, after the safety gate.

### QA-G02: Read-Only Runtime / Login Preflight

- Refresh shared services/images/ports/mount paths and unauthenticated login HTTP/redirect checks. Do not print full Compose environments, secrets, password hashes, credentials, OTP or auth tokens.
- Keep stopped services stopped. Do not start/recreate/recover services, reset/seed runtime data, recreate accounts/change passwords, or flush shared caches.
- If stopped services or missing approved credentials prevent login acceptance, list exact required services and a proposed data-preserving recovery/login scope for Coordinator. The proposal is not authorization to execute it.
- Preserve the prior `seeded-logins: failed` evidence; do not equate a legacy default-password check with invalid current accounts. Do not claim QA-G02 PASS without actual authorized runtime/login verification.

### QA-G03: Acceptance Prerequisites

Prepare a matrix for installed iOS/Android receipt/share/save/safe areas/keyboard, real Google/Apple/Facebook/LINE OTP linking, authenticated Nuxt success, and production news timing. For each record required device/build/source snapshot, tenant/provider configuration, approved existing/new account and phone, safe order fixture, authorization and missing prerequisites. Unknown values must be marked missing, not invented. Keep native/provider/Nuxt/production items NOT TESTED/BLOCKED until actually performed under appropriate authorization.

## Out Of Scope

- Implementation/OpenAPI/integration-map fixes or a new business/security contract.
- Full app rebuilds/regression reruns without a missing assertion or changed-source reason.
- Runtime service recovery/start/recreation, DB migrations/reset/seed, account/password/cache changes.
- Installations, real SMS/account linking, purchases, credential creation or deployment.
- Commit/push, cleanup, alternate worktrees or a new milestone.

## File Ownership

Can add:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/**
```

Keep application files, root Compose/runtime settings, contract docs, Coordinator decision, original QA report/artifacts/manifest and delivery handoffs unchanged. Put any extra fixtures/scripts/tool configuration only under the new artifact directory; run them from disposable containers without modifying app dependencies or lockfiles.

## Required Steps

1. Read the sources and capture exact baseline, doc/source/report hashes and evidence-reuse checks.
2. Create the targeted contract case matrix; trace code and perform structural/schema checks using a QA-owned isolated Docker runner if tooling is available. Mount application/docs read-only and keep temporary tool dependencies outside the application. Record tool versions, exact commands, resolved image IDs/digests and limits.
3. Run additional focused API assertions only when needed and only on the verified test database. Do not run migrations/destructive setup for this documentation follow-up.
4. Perform read-only runtime preflight and prepare the proposed recovery/login scope if blocked; do not execute that recovery.
5. Prepare real-acceptance prerequisite matrix, then report QA-G01, QA-G02, QA-G03 and overall acceptance separately. Do not silently waive missing acceptance.

## Validation Commands

All application/schema/test execution must be inside Docker. Git/file inspection and HTTP preflight are permitted on the host. The following read-only runtime commands do not authorize service changes:

```sh
docker compose -p newpaotang config --services
docker compose -p newpaotang ps --all
curl --max-time 5 -i -sS http://localhost:3100/login
curl --max-time 5 -i -sS http://localhost:3100/admin/login
curl --max-time 5 -i -sS http://localhost:3000/
```

Record mount/image/port inventory using only selected non-secret inspect fields. Do not dump full `docker compose config` or full container inspect output. The root `customer` image serves built Flutter/nginx, not legacy Nuxt; its HTTP state does not prove the pending local source is deployed or test authenticated Nuxt success.

For schema checks, QA may define a disposable validation service in the new artifact directory and run it with `docker compose run --rm --no-deps`. Record its actual command/tool output; do not reuse the old full-build runner or change application dependency files merely to obtain a validator. If no suitable tool is available, distinguish what was inspected from what was not validated and return that limitation.

Only if additional DB-backed assertions are justified, verify effective configuration inside Docker first:

```sh
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap(); $db = config("database.connections.".config("database.default").".database"); echo "effective_db=".$db.PHP_EOL; echo "effective_env=".app()->environment().PHP_EOL; exit($db === "newpaotang_test" && app()->environment() === "testing" ? 0 : 1);'
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php artisan test --env=testing --do-not-cache-result --filter='CustomerSocialAuthServiceTest|CustomerSmsOtpTest'
```

Required effective values: `newpaotang_test` and `testing`; `--env=testing` alone is insufficient. Stop if the check fails, and recheck if configuration changes. No runtime `newpaotang` mutation/destructive command or migration is authorized.

## Acceptance Criteria

- QA-G01 receives an evidence-backed PASS/FAIL/BLOCKED based on corrected contracts versus unchanged routes/controllers/services/clients, with structural/full-schema distinctions and exact file/line findings.
- Reused evidence is explicitly separated from newly executed validation, and snapshot/doc hashes match or differences are returned to Coordinator before reuse.
- QA-G02 contains fresh read-only observations and the exact remaining recovery/account prerequisites; no unauthorized service/data/configuration changes.
- QA-G03 has the criterion/prerequisite/authorization matrix, with native/provider/authenticated Nuxt/production items still visibly unverified when prerequisites are absent.
- Overall acceptance stays BLOCKED while applicable QA-G02/QA-G03 gates remain unresolved, even if QA-G01 passes.

## Handoff Requirements

Write:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md
```

Include worktree/branch/HEAD/origin, all relevant source/doc/evidence hashes, files added, tools/commands/results, evidence reused versus new, discrepancies with file/line references, individual gate results, known risks and Next Agent. Include `Runtime Restore / Login Smoke`: prior/fresh state, HTTP/redirect results, approved credentials availability, preserved stopped services and data, and any checks not executed. Do not run restoration seed/start commands as a substitute for missing authorization.

## Next Agent

Coordinator
