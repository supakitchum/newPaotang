# 20260508-m10-cloudflare-https-waf-cdn-r2-remediation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed the QA failure for:

```text
20260508-m10-cloudflare-https-waf-cdn-r2
```

QA verdict is `FAIL`. Do not approve the slice yet.

Open a focused Backend remediation for two P2 blocking defects:

```text
readiness JSON leaks configured Cloudflare/R2 identifiers instead of presence-only safe output
configured Cloudflare/R2 env can report ready_local without explicit ticket-image object evidence
```

After Backend handoff, Orchestrator must create a QA re-test task.

## Objective

Remediate Cloudflare/CDN/R2 readiness output so it is safe and release-gate accurate:

```text
configured Cloudflare/R2 values must never appear raw in platform:cloudflare:readiness JSON
readiness must expose presence booleans or fully redacted placeholders only
ticket-image CDN/R2 readiness must remain blocked until explicit ticket-image object evidence exists
CDN/R2 placeholder credentials alone must not produce ready_local
tests must prove fake configured values are not leaked and no-image-evidence remains blocked
```

This remediation is still local/dev readiness inside M10. It is not production approval.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-cloudflare-https-waf-cdn-r2-qa-review-decision.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-qa-report.md`
- `ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-qa/json-command-summary.txt`
- `ai-agents/tasks/20260508-m10-cloudflare-https-waf-cdn-r2-backend.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md`
- `ai-agents/tasks/20260508-m10-cloudflare-https-waf-cdn-r2-qa.md`
- `apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php`
- `apps/platform-api/app/Console/Commands/PlatformCloudflareReadinessCommand.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/.env.example`
- `apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php`
- `scripts/ticket-image-cdn-check.sh`
- `scripts/k6-run-baseline.sh`
- `load-tests/k6/ticket-image-cdn-spike.js`
- `ops/m10/cloudflare-https-waf-cdn-r2-readiness.md`
- `ops/m10/r2-ticket-image-strategy.md`
- `ops/m10/ticket-image-cdn-load-test-runbook.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `docs/docker-runtime-policy.md`

## Scope

Fix only the QA-blocking Cloudflare/CDN/R2 readiness defects.

Approved remediation scope:

```text
apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php
apps/platform-api/app/Console/Commands/PlatformCloudflareReadinessCommand.php
apps/platform-api/config/platform.php
apps/platform-api/.env.example
apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
scripts/ticket-image-cdn-check.sh
scripts/k6-run-baseline.sh
load-tests/k6/ticket-image-cdn-spike.js
docs/m10-deployment-monitoring-load-test.md
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend-handoff.md
```

Required behavior:

```text
do not emit raw account id, zone id, API token, API base URL, CDN base URL, R2 endpoint, R2 bucket, R2 access key id, R2 secret key, signed URLs, production-like hosts, or ticket-image object URLs in readiness JSON
use configured/present booleans, status labels, or constant redacted placeholders such as [CONFIGURED] or [REDACTED]
do not pass raw identifiers through a generic redactor if the raw value may still be returned
add or use explicit non-secret ticket-image object evidence such as IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH
keep `cdn_r2_ticket_images.blockers` non-empty until that explicit image-path evidence exists
keep overall readiness `status=blocked_external` when ticket-image evidence is missing, even if Cloudflare/R2 placeholder env values are configured
normal API `BASE_URL` must not count as CDN/R2 ticket-image evidence
preserve `production_approved=false` and no external Cloudflare/R2 mutation
```

## Out Of Scope

- Do not call real Cloudflare APIs.
- Do not create or mutate DNS records, WAF rules, cache rules, R2 buckets, SSL certificates, or production domains.
- Do not approve staging, production, client delivery, Cloudflare production activation, DNS ownership, HTTPS enforcement, WAF enforcement, R2 delivery, CDN cache hit ratio, or real ticket-image CDN coverage without QA-verifiable infrastructure evidence.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not add customer UI, back-office UI, or public API route changes.
- Do not change business rules, tenant resolution, permission scopes, response envelopes, or documented API paths.
- Do not broaden this into Horizon/Reverb/scheduler work, migration rehearsal, dependency/license work, npm audit work, or back-office production-risk cleanup.
- Do not move tenant logo/theme/payment/domain/feature config into env.
- Do not commit or document real secrets, bearer tokens, access keys, signed URLs, account IDs, zone IDs, production URLs, private certificates, or passwords.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, Cloudflare CLI, wrangler, aws, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php
apps/platform-api/app/Console/Commands/PlatformCloudflareReadinessCommand.php
apps/platform-api/config/platform.php
apps/platform-api/.env.example
apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
scripts/ticket-image-cdn-check.sh
scripts/k6-run-baseline.sh
load-tests/k6/ticket-image-cdn-spike.js
docs/m10-deployment-monitoring-load-test.md
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for package, build, test, runtime, migration, queue, scheduler, k6, and readiness validation commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Inspect the QA artifacts for the fake-env probe and confirm the exact raw values that must not appear in readiness output.
5. Inspect `CloudflareReadinessService` redaction areas identified by QA:

```text
cloudflare redacted_config around lines 77-82
ticket image/CDN redacted_config around lines 237-243
ticketImageReadiness blocker logic around lines 203-245
```

6. Replace raw `redacted_config` output with presence-only or constant-redacted output for Cloudflare and CDN/R2 configuration.
7. Add explicit ticket-image object evidence to readiness logic. Use either the existing k6 `IMAGE_PATH` contract or a clearly documented non-secret platform config such as `TICKET_IMAGE_CDN_IMAGE_PATH`.
8. Ensure missing image-path evidence adds a stable blocker such as:

```text
ticket_image_cdn_image_path_missing
```

9. Ensure configured fake Cloudflare/R2 env values without image-path evidence return `blocked_external` and non-empty blockers.
10. Ensure configured fake Cloudflare/R2 env values with explicit non-secret image-path evidence can only reach local dry-run readiness, never production approval.
11. Add or adjust tests in `M10CloudflareHttpsWafCdnR2Test` to assert:

```text
fake account id, zone id, API token, CDN base URL, R2 endpoint, bucket, access key id, secret key, and signed/object-like values do not appear raw in readiness JSON
configured booleans/statuses remain useful for QA without exposing raw values
no image-path evidence keeps ticket-image readiness blocked
BASE_URL alone does not satisfy ticket-image CDN/R2 coverage
explicit IMAGE_PATH or documented equivalent removes only the image-path blocker
production_approved remains false
external_cloudflare_calls_attempted remains false
external_r2_calls_attempted remains false
```

12. Update docs/runbooks only where needed to align the readiness command, helper script, and k6 behavior around explicit `CDN_BASE_URL` plus `IMAGE_PATH` or equivalent ticket-image evidence.
13. Preserve the previously green WAF/cache artifacts, custom-domain activation guard, route boundary, and Docker-only helper behavior unless directly required by this remediation.
14. Run Docker-only validation commands.
15. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend-handoff.md
```

## Acceptance Criteria

- `platform:cloudflare:readiness --format=json` never emits raw configured Cloudflare/R2 identifiers, tokens, access keys, endpoints, buckets, CDN base URLs, signed URLs, or production-like object paths.
- Readiness JSON still exposes useful configured/present booleans or fully redacted placeholders.
- Fake configured env values used by QA are absent from raw command output.
- Without explicit ticket-image object evidence, `cdn_r2_ticket_images.blockers` includes a ticket-image evidence blocker and overall status remains `blocked_external`.
- CDN/R2 placeholder credentials alone cannot produce `ready_local`.
- `BASE_URL` cannot satisfy ticket-image CDN/R2 readiness.
- With explicit non-secret ticket-image image-path evidence, the image-path blocker is removed while `production_approved=false` remains.
- Existing domain readiness guards remain intact.
- Existing WAF/rate-limit and cache-bypass artifacts remain valid.
- No public API, customer UI, or back-office UI contract drifts.
- Docker-only regression validation passes.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6 commands.

Required setup:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
```

Required Backend regression:

```sh
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=M10K6LoadTestExecutionTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioningTest
docker compose run --rm platform-api php artisan test --filter=TenantResolutionTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
```

Required readiness probes:

```sh
docker compose exec platform-api php artisan platform:cloudflare:readiness --format=json
docker compose run --rm -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction platform-api php artisan platform:cloudflare:readiness --format=json
docker compose run --rm -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction -e IMAGE_PATH=/tickets/qa-redaction-safe.png platform-api php artisan platform:cloudflare:readiness --format=json
docker compose run --rm -e BASE_URL=https://api.fake-redaction.test -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction platform-api php artisan platform:cloudflare:readiness --format=json
```

Required command and route guardrails:

```sh
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

The handoff must summarize the readiness probe results and explicitly state whether any fake QA values appeared raw in output.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend-handoff.md
```

Must include:

```text
what was done
files changed
redaction approach
ticket-image evidence/blocker approach
readiness JSON behavior for default env
readiness JSON behavior for fake configured env without image evidence
readiness JSON behavior for fake configured env with explicit image evidence
confirmation that raw fake identifiers do not appear in readiness output
Docker validation
known risks
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```
