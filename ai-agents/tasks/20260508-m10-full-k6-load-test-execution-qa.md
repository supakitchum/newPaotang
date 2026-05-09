# 20260508-m10-full-k6-load-test-execution - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator resumed M10 release-gate follow-up planning after Backend Module Structure Remediation was approved.

Orchestrator selected the first follow-up slice:

```text
Full k6 load-test execution with fixture data, bearer tokens, thresholds, and runner ownership
```

Backend Develop reports the local/dev k6 execution workflow is complete. Validate that this slice is genuinely reproducible, Docker-only, secret-safe, and limited to local/dev load-test readiness.

## Objective

Verify the M10 full k6 local/dev execution slice.

Prove or reject these Backend claims:

```text
fixture command prepares deterministic local/dev k6 data
generated bearer tokens are runtime-only and ignored
six API-backed k6 scenarios run successfully through Docker
ticket image CDN scenario is correctly skipped or runnable only with explicit CDN/R2 env
threshold profiles are wired
new Partner Sync API routes implement existing OpenAPI paths without changing docs/openapi.yaml
full platform-api regression still passes
no staging, production, Cloudflare/CDN/R2, or client-delivery approval is claimed
```

## Source Of Truth

- `ai-agents/decisions/20260508-backend-module-structure-remediation-approval-decision.md`
- `ai-agents/handoffs/20260508-backend-module-structure-remediation-approval-coordinator-handoff.md`
- `ai-agents/decisions/20260508-m10-release-gate-follow-up-planning-decision.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-coordinator-handoff.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-orchestrator-handoff.md`
- `ai-agents/decisions/20260508-m10-deployment-monitoring-load-test-approval-decision.md`
- `ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md`
- `ai-agents/tasks/20260508-m10-full-k6-load-test-execution-backend.md`
- `ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-develop-handoff.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/api-conventions.md`
- `docs/backend-architecture-compliance.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `docs/openapi.yaml`
- `ops/m10/runtime-readiness.md`
- `load-tests/README.md`
- `load-tests/k6/*.js`
- `load-tests/k6/lib/profile.js`
- `load-tests/results/.gitignore`
- `scripts/k6-prepare-baseline-fixtures.sh`
- `scripts/k6-run-baseline.sh`
- `compose.yaml`
- `apps/platform-api/**`

Note: Backend wrote the handoff as:

```text
ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-develop-handoff.md
```

The original task requested:

```text
ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
```

Treat the existing `backend-develop-handoff` as the active Backend handoff, but record the naming mismatch as a traceability finding.

## Scope

Validate Backend/Ops implementation for local/dev k6 execution readiness.

Inspect at minimum:

```text
apps/platform-api/app/Console/Commands/PrepareK6BaselineCommand.php
apps/platform-api/app/Modules/Partner/Http/Controllers/PartnerSyncController.php
apps/platform-api/app/Modules/Partner/Services/PartnerSyncService.php
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
apps/platform-api/tests/Feature/M10K6LoadTestExecutionTest.php
load-tests/k6/lib/profile.js
load-tests/k6/customer-stock-search.js
load-tests/k6/concurrent-booking-same-stock.js
load-tests/k6/checkout-wallet-consistency.js
load-tests/k6/partner-tenant-burst-sync.js
load-tests/k6/reward-publish-spike.js
load-tests/k6/reward-checking-queue-chunk.js
load-tests/k6/ticket-image-cdn-spike.js
load-tests/README.md
load-tests/results/.gitignore
scripts/k6-prepare-baseline-fixtures.sh
scripts/k6-run-baseline.sh
docs/m10-deployment-monitoring-load-test.md
docs/openapi.yaml
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, or Board.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, or business rules.
- Do not approve staging, production, client delivery, Cloudflare, HTTPS, WAF, CDN/R2, Horizon, Reverb, migration rehearsal, production observability, Meno license, or npm audit gates.
- Do not commit generated bearer tokens, env files, k6 summaries, Cloudflare credentials, R2 keys, production URLs, or other secrets.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-full-k6-load-test-execution-qa-report.md
ai-agents/reports/artifacts/20260508-m10-full-k6-load-test-execution-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-m10-full-k6-load-test-execution-qa-report.md and ai-agents/reports/artifacts/20260508-m10-full-k6-load-test-execution-qa/**
```

If a defect requires implementation, docs, route, test, contract, artifact-policy, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, and runtime commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Review Backend handoff for:

```text
files changed
fixture setup design
generated env/artifact policy
token/credential handling
scenario coverage table
k6 threshold profiles
Docker validation commands and results
k6 run commands and results
artifact locations
release gates still open
known risks
```

5. Verify handoff naming mismatch and decide severity:

```text
actual: ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-develop-handoff.md
expected by task: ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
```

6. Verify fixture command behavior and command registration:

```text
load-tests:k6:prepare exists
fixture command writes both JSON and env artifacts
generated tokens are emitted only to ignored runtime artifacts
database stores token hashes, not plaintext generated tokens
fixture data is local/dev/testing scoped and does not alter production business rules
```

7. Verify secret/artifact policy:

```text
load-tests/results/.gitignore ignores generated env, JSON, summary, and skipped artifacts
git check-ignore recognizes generated token/env files
generated artifacts are not staged or tracked
no generated bearer token appears in tracked source, docs, tasks, handoffs, or reports
```

8. Verify k6 threshold profiles:

```text
smoke
baseline
release-candidate
```

Profiles must be explicit, documented, and selected by env such as `K6_PROFILE`.

9. Verify each API-backed k6 scenario uses fixture/env values rather than hardcoded secrets:

```text
customer-stock-search.js
concurrent-booking-same-stock.js
checkout-wallet-consistency.js
partner-tenant-burst-sync.js
reward-publish-spike.js
reward-checking-queue-chunk.js
```

10. Verify `ticket-image-cdn-spike.js` remains honest:

```text
it should run only when explicit CDN_BASE_URL and IMAGE_PATH, or equivalent explicit image env, are provided
otherwise the baseline runner should create a skipped artifact that keeps Cloudflare/CDN/R2 gate open
```

11. Verify Partner Sync API scope:

```text
GET /api/v1/partner-sync/allocations
POST /api/v1/partner-sync/events
```

These routes must already exist in `docs/openapi.yaml`; QA must confirm `docs/openapi.yaml` was not modified for this slice and that implementation preserves auth, partner, tenant, and idempotency checks claimed in the handoff.

12. Verify no forbidden areas were changed by this slice:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
document/**
```

The workspace is noisy; fail only when evidence ties forbidden drift to this slice.

13. Run Docker validation commands.
14. Reproduce fixture generation with Docker-only commands or the provided Docker-only helper script.
15. Reproduce the short k6 smoke baseline for the six API-backed scenarios.
16. Capture or reference QA artifacts under:

```text
ai-agents/reports/artifacts/20260508-m10-full-k6-load-test-execution-qa/**
```

Do not copy secret env/token files into report artifacts. Redact any token-like values if command output includes them.

17. Write QA report to:

```text
ai-agents/reports/20260508-m10-full-k6-load-test-execution-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Fixture generation is reproducible.
- Generated bearer tokens are runtime-only, ignored, untracked, and not copied into QA reports.
- `load-tests/results/.gitignore` protects generated token/env/summary artifacts.
- `git check-ignore` confirms generated fixture/env and summary artifacts are ignored.
- `M10K6LoadTestExecutionTest` passes.
- `ConsoleCommandStructureTest` passes.
- `php artisan test --filter=M10` passes.
- Full platform-api test suite passes.
- `platform:smoke` passes after fixture/seed setup.
- All seven k6 scripts pass `k6 inspect` through Docker.
- Six API-backed k6 scenarios run through Docker and produce summary artifacts.
- k6 smoke result metrics are recorded in the QA report.
- `ticket-image-cdn-spike.js` is either run against explicit CDN/R2 image env or skipped with a clear blocker artifact.
- Partner Sync API routes are present in `route:list` and match existing OpenAPI paths.
- Partner Sync auth/partner/tenant/idempotency behavior is covered by implementation and tests.
- No API contract drift, customer flow drift, back-office flow drift, tenant isolation drift, or permission drift is found.
- Docs clearly present this as local/dev load-test execution readiness only.
- Release gates still open are carried forward:

```text
production observability and alert channels
Cloudflare HTTPS/WAF/rate-limit/CDN/R2 integration
Horizon/Reverb hardening
scheduler workload registration
migration rehearsal/cutover/rollback
production secret management
Meno license compliance
npm audit remediation
back-office hydration/stale-marker/menu metadata risks
maintenance bypass list endpoint
backend menu category/icon fields
```

- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, and runtime commands.

Required Docker validation:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10K6LoadTestExecutionTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test --filter=M10
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker run --rm grafana/k6:latest version
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/customer-stock-search.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/concurrent-booking-same-stock.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/checkout-wallet-consistency.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/partner-tenant-burst-sync.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-publish-spike.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-checking-queue-chunk.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

Required helper-script reproduction, allowed only because the scripts must call Docker/Docker Compose internally:

```sh
scripts/k6-prepare-baseline-fixtures.sh
scripts/k6-run-baseline.sh
```

Required static checks:

```sh
git status --short
git check-ignore -v load-tests/results/k6-baseline.env load-tests/results/k6-baseline-env.json
git check-ignore -v load-tests/results/*/*.summary.json load-tests/results/*/ticket-image-cdn-spike.skipped.json
rg -n "Bearer |CUSTOMER_TOKEN=|ADMIN_TOKEN=|PARTNER_TOKEN=|secret|password" load-tests README.md docs/m10-deployment-monitoring-load-test.md scripts ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-develop-handoff.md
rg -n "/api/v1/partner-sync/(allocations|events)|partner-sync" docs/openapi.yaml apps/platform-api/routes/api.php apps/platform-api/app/Modules/Partner apps/platform-api/tests/Feature/M10K6LoadTestExecutionTest.php
```

Interpretation notes:

```text
Secret scans may match placeholders, docs, or environment variable names. QA must distinguish safe placeholders from real generated token values.
Generated token/env artifacts must not be copied into QA reports.
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-full-k6-load-test-execution-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
handoff naming/traceability finding
fixture setup review
token and secret handling review
artifact ignore/tracking review
k6 profile/threshold review
k6 inspect results
k6 baseline run results
ticket image CDN scenario result or blocker
Partner Sync API/OpenAPI review
permission/tenant/idempotency review
route-list review
test results
docs/release-boundary review
customer/back-office no-change review
release gates still open
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```
