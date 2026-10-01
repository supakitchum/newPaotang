# m10-backend-only-deploy-ready-closeout - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator replanned the active main scope to backend deploy-readiness only:

```text
ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md
ai-agents/handoffs/20260509-backend-only-main-scope-deploy-ready-replan-coordinator-handoff.md
```

Backend Develop completed:

```text
m10-backend-only-deploy-ready-closeout
ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md
```

Run QA for the backend-only deploy-ready closeout package.

This QA does not approve Back Office, Customer frontend, staging, production, client delivery, external secret management, Cloudflare/R2 production readiness, production mail/payment/LINE readiness, old-data migration, cutover, rollback, Gate 5, or final M10 release.

## Objective

Verify that the backend-only deploy-readiness closeout package is accurate, locally/dev validated, committed in scope, and correctly leaves production/external gates blocked.

QA must prove:

```text
OpenAPI/app route parity remains 279 / 279 / 0 / 0
full backend Docker suite passes
runtime/smoke/readiness/observability/alerts/cloudflare/migration commands behave as documented
worker/scheduler commands are Docker-validated
k6 fixture and script readiness is Docker-validated or blocker is explicit
docs/m10-backend-deploy-ready-closeout.md exists and matches evidence
ops/m10/backend-deploy-ready-blocker-matrix.md exists and accurately separates local/dev readiness from external blockers
ops/m10/backend-release-gate-ledger.md reflects backend-only closeout status
Backend commit a93b822 contains only scoped closeout files
BO/customer frontend freeze is preserved
```

## Source Of Truth

- `ai-agents/tasks/20260509-m10-backend-only-deploy-ready-closeout-backend.md`
- `ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md`
- `ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md`
- `ai-agents/handoffs/20260509-backend-only-main-scope-deploy-ready-replan-coordinator-handoff.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/stage-gates.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/events.md`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/backend-console-commands.md`
- `docs/backend-maintenance-support.md`
- `docs/backend-model-layer.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-request-validation.md`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `docs/m10-backend-deploy-ready-closeout.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `docs/workspace-app-structure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ops/m10/backend-deploy-ready-blocker-matrix.md`
- `ops/m10/**`
- `apps/platform-api/**`
- `scripts/platform-*.sh`
- `scripts/k6-prepare-baseline-fixtures.sh`
- `scripts/k6-run-baseline.sh`
- `load-tests/k6/**`

## Scope

Perform QA for backend deploy-readiness only.

Validate:

```text
route parity and route registration
full backend tests and focused M10 readiness tests
permission, tenant isolation, idempotency, audit, outbox/inbox, model/migration/seeder/doc compliance evidence
runtime, queue, scheduler, Horizon, Reverb readiness posture
Docker image/runtime/deployment-template readiness posture
observability and alerts readiness posture
Cloudflare/HTTPS/WAF/CDN/R2 readiness posture
mail/payment/LINE/secret-manager provider boundary posture
old-data migration, snapshot, staging rehearsal, cutover, rollback posture
load-test fixture/script readiness posture
Backend commit scope and handoff correctness
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, OpenAPI, permissions, package files, source files, decisions, tasks, handoffs, compose, workflows, load-test scripts, ops docs, or Board.
- Do not approve BO work or dispatch BO Develop.
- Do not approve customer frontend work.
- Do not approve staging, production, client delivery, external secret management, Cloudflare/R2 production readiness, production mail/payment/LINE readiness, old-data migration, cutover, rollback, Gate 5, or final M10 release.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, k6, build, or runtime commands on the host machine.
- Do not copy real tokens, secrets, bearer tokens, provider credentials, private keys, customer data, or production URLs into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260509-m10-backend-only-deploy-ready-closeout-qa-report.md
ai-agents/reports/artifacts/20260509-m10-backend-only-deploy-ready-closeout-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
apps/customer/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260509-m10-backend-only-deploy-ready-closeout-qa-report.md and ai-agents/reports/artifacts/20260509-m10-backend-only-deploy-ready-closeout-qa/**
```

If a defect requires implementation, docs, ops, scripts, tests, runtime, backend, provider, or policy changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for backend runtime, migration, queue, scheduler, k6, and test commands.
3. Inspect `git status --short` and separate QA report/artifacts from unrelated dirty workspace noise.
4. Verify Backend commit:

```text
commit: a93b822
message: m10-backend-only-deploy-ready-closeout: close backend deploy readiness
files: docs/m10-backend-deploy-ready-closeout.md, ops/m10/backend-deploy-ready-blocker-matrix.md, ops/m10/backend-release-gate-ledger.md
```

5. Recompute OpenAPI/app route parity.
6. Run Docker-only backend validation commands.
7. Run Docker-only focused M10 readiness tests.
8. Run Docker-only worker/scheduler validations.
9. Run Docker-only k6 script inspection. Do not run host k6.
10. Static-review closeout docs and blocker matrix for:

```text
no production readiness fabrication
external blockers are explicit
local/dev readiness evidence matches commands
Gate 5/final release not approved
BO/customer frontend deferred/frozen
```

11. Confirm no BO/customer implementation files were edited by the backend closeout commit.
12. Write QA report to:

```text
ai-agents/reports/20260509-m10-backend-only-deploy-ready-closeout-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- QA writes only allowed report/artifact paths.
- Backend commit `a93b822` is verified and scoped.
- No BO/customer implementation files are touched.
- Route parity is verified as `279 / 279 / 0 / 0`.
- Full backend Docker suite passes or every failure is documented with severity and owner.
- Runtime, smoke, observability, alerts, Cloudflare, migration, worker, scheduler, and k6 readiness evidence is verified.
- Docs/ledger/blocker matrix accurately distinguish `ready_local`, guarded local/dev, `blocked_external`, and `not_triggered`.
- Production/staging/final release claims are not fabricated.
- QA verdict routes to Coordinator.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan/k6 commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend validation:

```sh
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose exec -T platform-api php artisan platform:smoke
docker compose exec -T platform-api php artisan platform:runtime:readiness --format=json
docker compose exec -T platform-api php artisan platform:observability:report --format=json
docker compose exec -T platform-api php artisan platform:alerts:check --dry-run --format=json
docker compose exec -T platform-api php artisan platform:cloudflare:readiness --format=json
docker compose exec -T platform-api php artisan platform:migration:rehearsal --dry-run --format=json
docker compose run --rm platform-api php artisan schedule:list
docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default
docker compose run --rm platform-api php artisan load-tests:k6:prepare --base-url=http://host.docker.internal:8000 --tenant-host=k6-alpha.newpaotang.test
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=M10K6LoadTestExecutionTest
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=M10MigrationRehearsalCutoverRollbackTest
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
```

Docker-only k6 script inspection:

```sh
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/customer-stock-search.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/concurrent-booking-same-stock.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/checkout-wallet-consistency.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-checking-queue-chunk.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/partner-tenant-burst-sync.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-publish-spike.js
```

Read-only host static review commands are allowed:

```sh
git status --short
git show --stat --oneline --no-renames a93b822
git diff --name-only a93b822^ a93b822
rg -n "ready_local|blocked_external|not_triggered|production_approved|Gate 5|final release|279/279|Cloudflare|R2|Horizon|Reverb|mail|payment|LINE|secret|migration|cutover|rollback|k6" docs/m10-backend-deploy-ready-closeout.md ops/m10/backend-deploy-ready-blocker-matrix.md ops/m10/backend-release-gate-ledger.md
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260509-m10-backend-only-deploy-ready-closeout-qa-report.md
```

Also write artifacts under:

```text
ai-agents/reports/artifacts/20260509-m10-backend-only-deploy-ready-closeout-qa/
```

Must include:

```text
verdict
scope checked
commit verification
files/artifacts reviewed
route parity counts
Docker validation commands and results
runtime/worker/scheduler findings
load-test readiness findings
release-gate ledger findings
external blocker matrix findings
defects, if any
risks/not approved
recommendation
next agent
```

Set next agent to:

```text
Coordinator
```
