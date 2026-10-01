# m10-backend-only-deploy-ready-closeout - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator replanned the active main scope so it closes at backend deploy-readiness and defers Back Office to the next phase:

```text
ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md
ai-agents/handoffs/20260509-backend-only-main-scope-deploy-ready-replan-coordinator-handoff.md
```

Open backend-only closeout task:

```text
m10-backend-only-deploy-ready-closeout
```

The active closeout target is:

```text
apps/platform-api backend deploy-readiness only
```

Do not dispatch or edit Back Office. Do not edit customer frontend. Do not trigger Gate 5 or final release approval.

## Objective

Close the backend deploy-readiness package for M10 by auditing, fixing safe backend-only gaps, validating through Docker, and producing a final backend release-gate evidence set.

The output must clearly answer:

```text
is backend/API route parity closed
are permissions, tenant isolation, models, migrations, seeders, tests, docs, audit, idempotency, outbox/inbox, queue, scheduler, Horizon, and Reverb locally/dev ready
which backend runtime/image/deployment templates are ready local/dev
which load-test fixtures/scripts/artifacts are ready local/dev
which Cloudflare/HTTPS/WAF/CDN/R2, mail, payment, LINE, secret-manager, migration, cutover, rollback, and production-readiness gates remain external blockers
what Docker-only validation proves the current backend state
what commit contains this Backend Develop task scope
```

## Source Of Truth

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
- `docs/m10-deployment-monitoring-load-test.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/15_EXECUTION_PLAN.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `docs/workspace-app-structure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/runtime-hardening-readiness.md`
- `ops/m10/horizon-queue-supervision.md`
- `ops/m10/reverb-deployment-readiness.md`
- `ops/m10/scheduler-workload-runbook.md`
- `ops/m10/observability-signal-inventory.md`
- `ops/m10/alert-channel-runbook.md`
- `ops/m10/cloudflare-https-waf-cdn-r2-readiness.md`
- `ops/m10/r2-ticket-image-strategy.md`
- `ops/m10/ticket-image-cdn-load-test-runbook.md`
- `ops/m10/old-data-migration-strategy.md`
- `ops/m10/migration-rehearsal-runbook.md`
- `ops/m10/migration-rehearsal-fixtures.md`
- `ops/m10/cutover-runbook.md`
- `ops/m10/rollback-drill-runbook.md`
- `ops/m10/snapshot-requirements.md`
- `ops/m10/production-secret-boundary.md`
- `apps/platform-api/**`
- `scripts/platform-*.sh`
- `scripts/k6-prepare-baseline-fixtures.sh`
- `scripts/k6-run-baseline.sh`
- `load-tests/k6/**`

## Scope

Backend deploy-readiness only.

Required coverage:

```text
OpenAPI/app route parity 279/279/0/0
permission and tenant isolation compliance
model/service/controller/request/migration/seeder/test/doc compliance
Docker-only backend validation
queue, scheduler, Horizon, Reverb readiness
idempotency, audit, outbox/inbox readiness
backend runtime/image/deployment template readiness
load-test scripts, fixture preparation, and backend execution evidence
Cloudflare/HTTPS/WAF/CDN/R2 backend readiness or exact external blocker evidence
mail, payment, LINE provider, production secret-manager, old-data migration, cutover, and rollback blocker matrix
backend release-gate ledger
```

Expected closeout artifacts:

```text
docs/m10-backend-deploy-ready-closeout.md
ops/m10/backend-release-gate-ledger.md
ops/m10/backend-deploy-ready-blocker-matrix.md
ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md
```

Use existing docs if they already contain the required information; otherwise update/create narrowly.

## Out Of Scope

- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not dispatch BO Develop.
- Do not perform BO page/menu/visual/build/dependency/license/npm audit/deploy work.
- Do not change customer frontend flow.
- Do not change API paths, methods, schemas, or response semantics without Coordinator approval.
- Do not claim staging, production, client delivery, external secret management, Cloudflare/R2 production readiness, production mail delivery, payment provider readiness, LINE production readiness, old-data migration success, cutover, rollback, Gate 5, final M10 release, or new milestone approval without external evidence.
- Do not fabricate external infrastructure evidence.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, k6, build, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/backend-architecture-compliance.md
docs/backend-bootstrap-seeders.md
docs/backend-console-commands.md
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-request-validation.md
docs/m10-backend-completion-and-release-gate-closure.md
docs/m10-backend-deploy-ready-closeout.md
docs/m10-deployment-monitoring-load-test.md
docs/workspace-app-structure.md
ops/m10/**
scripts/platform-*.sh
scripts/k6-prepare-baseline-fixtures.sh
scripts/k6-run-baseline.sh
load-tests/k6/**
load-tests/results/**
ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml unless a non-breaking documentation correction is required and fully justified
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml unless Coordinator approval is explicitly required in the handoff
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy and Code Agent Commit Rule.
3. Inspect `git status --short` before editing and preserve unrelated dirty changes.
4. Reconfirm route parity:

```text
OpenAPI routes: 279
app routes: 279
missing: 0
undocumented: 0
```

5. Audit backend/API readiness against docs:

```text
permissions and tenant isolation
events and audit/outbox/inbox
ERD/model/migration/seeder parity
status enums
request validation
query builder exception policy
console command structure
maintenance/support/security rules
```

6. Audit runtime/deployment readiness:

```text
platform-api Dockerfile production target
platform-api .env.example backend placeholders
queue worker profile and worker-once validation
scheduler profile and schedule:list validation
Horizon blockers
Reverb blockers
runtime readiness command
smoke command
observability report and alerts dry-run
```

7. Audit M10 infra/release gates:

```text
Cloudflare/HTTPS/WAF/CDN/R2 readiness
ticket image CDN/load-test boundary
mail provider boundary
payment provider boundary
LINE provider boundary
production secret-manager/key rotation
old-data migration
snapshot requirements
staging rehearsal
cutover
rollback
```

8. Audit load-test readiness:

```text
load-tests:k6:prepare command
k6 script inspectability through Docker
baseline runner behavior
local/dev baseline results or explicit blocker
ticket-image CDN spike skip/blocker behavior when CDN evidence is missing
```

9. Implement only safe backend/docs/ops/script fixes inside File Ownership.
10. Create/update closeout docs:

```text
docs/m10-backend-deploy-ready-closeout.md
ops/m10/backend-deploy-ready-blocker-matrix.md
ops/m10/backend-release-gate-ledger.md
```

11. Run Docker-only validation commands.
12. Stage and commit only this task scope after validation passes, following `ai-agents/rules/global-rules.md`.
13. Write Backend handoff to:

```text
ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- No BO/customer files are edited.
- Backend route parity remains `279 / 279 / 0 / 0`.
- Backend permission, tenant isolation, model, request validation, console, idempotency, audit, outbox/inbox, and docs compliance are documented.
- Runtime readiness, worker, scheduler, Horizon, Reverb, smoke, observability, alert, Cloudflare/R2, migration/cutover/rollback, and secret-boundary states are documented as ready local/dev or external blocker.
- Load-test fixture/script readiness is validated or blockers are explicit.
- `docs/m10-backend-deploy-ready-closeout.md` exists.
- `ops/m10/backend-deploy-ready-blocker-matrix.md` exists.
- `ops/m10/backend-release-gate-ledger.md` reflects the backend-only closeout status.
- Full backend Docker suite passes or every failure is documented with severity and owner.
- Backend Develop commits its scoped changes after validation and records commit hash in handoff.
- Handoff clearly states whether ready for QA.

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
```

If running baseline k6 scenarios, invoke k6 through Docker directly with generated env artifacts. Do not run host k6:

```sh
docker run --rm --add-host=host.docker.internal:host-gateway --env-file load-tests/results/k6-baseline.env -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest run /scripts/customer-stock-search.js
```

If env artifacts are missing or the local API is not reachable from the k6 container, stop and document the blocker instead of running a host k6/runtime command.

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "production_approved|blocked_external|ready_local|Horizon|Reverb|Cloudflare|R2|secret|migration|cutover|rollback|k6|route parity|279" docs ops apps/platform-api scripts load-tests
rg -n "Route::|middleware\\(|permission|tenant_id|idempotency|audit|outbox|inbox" apps/platform-api/routes apps/platform-api/app apps/platform-api/tests docs
```

Commit commands after validation:

```sh
git status --short
git add <scoped files only>
git commit -m "m10-backend-only-deploy-ready-closeout: close backend deploy readiness"
git status --short
```

Do not push unless Coordinator or user explicitly asks in this task. Record commit hash in handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md
```

Must include:

```text
status: Ready for QA or blocker
commit hash
files changed and committed
unrelated dirty files left untouched
route parity count
backend deploy-readiness summary
release-gate ledger summary
external blocker matrix summary
load-test readiness summary
Docker validation commands and results
known risks/not approved
next agent
```

Set next agent to:

```text
Orchestrator
```
