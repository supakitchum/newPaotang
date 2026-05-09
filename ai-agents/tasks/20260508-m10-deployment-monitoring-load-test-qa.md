# 20260508-m10-deployment-monitoring-load-test - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the first M10 Deployment, Monitoring, Load Test, Migration backend/ops foundation slice.

Validate the M10 backend/runtime readiness work against the Orchestrator task, Backend handoff, main execution plan, Docker runtime policy, deployment/monitoring/load-test documents, and accepted risk carry-forward from Back-office Operations Page Slice 1 approval.

## Objective

Verify that the M10 backend/ops foundation is implemented, scoped correctly, Docker-only, testable, and honest about remaining release gates.

QA must confirm:

```text
platform-api runtime image/build path works
Docker Compose API/worker/scheduler/smoke roles exist and remain compatible with local customer/back-office services
root health endpoints and versioned health endpoints work
platform:smoke validates DB/cache/queue/seeded login/monitoring defaults
monitoring/usage defaults are present in seed/provisioning flows
load-test scaffolds exist and do not fake pass results
migration/cutover/rollback docs exist
accepted BO risks are carried forward
no forbidden customer/back-office/source-of-truth contract drift occurred
```

## Source Of Truth

- `ai-agents/tasks/20260508-m10-deployment-monitoring-load-test-backend.md`
- `ai-agents/handoffs/20260508-m10-deployment-monitoring-load-test-backend-handoff.md`
- `ai-agents/handoffs/20260508-main-plan-next-slice-orchestrator-handoff.md`
- `ai-agents/decisions/20260508-back-office-operations-page-slice-1-approval-decision.md`
- `ai-agents/handoffs/20260508-back-office-operations-page-slice-1-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-approval-decision.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/15_EXECUTION_PLAN.md`
- `document/01_SYSTEM_OVERVIEW.md`
- `docs/docker-runtime-policy.md`
- `docs/workspace-app-structure.md`
- `docs/api-conventions.md`
- `docs/events.md`
- `docs/backend-console-commands.md`
- `docs/backend-model-layer.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `compose.yaml`
- `apps/platform-api/**`
- `.github/workflows/platform-api-m10.yml`
- `load-tests/**`
- `ops/**`
- `scripts/**`

## Scope

Validate Backend M10 changes within approved scope:

```text
apps/platform-api/**
apps/platform-api/.env.example
apps/platform-api/Dockerfile
compose.yaml
ops/**
scripts/**
load-tests/**
.github/workflows/**
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-bootstrap-seeders.md
```

Inspect at minimum:

```text
compose.yaml
apps/platform-api/Dockerfile
apps/platform-api/.env.example
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/health.php
apps/platform-api/routes/api.php
apps/platform-api/app/Console/Commands/PlatformSmokeCommand.php
apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
apps/platform-api/database/seeders/DemoTenantSeeder.php
apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php
apps/platform-api/tests/Feature/BootstrapSeederTest.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
docs/m10-deployment-monitoring-load-test.md
load-tests/README.md
load-tests/k6/*.js
ops/m10/runtime-readiness.md
scripts/platform-api-smoke.sh
scripts/platform-api-worker-once.sh
scripts/platform-api-schedule-list.sh
.github/workflows/platform-api-m10.yml
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, or Board.
- Do not change backend business contracts, response envelopes, permission scopes, tenant resolution, approved OpenAPI paths, or seeded credentials.
- Do not add NoSQL, ClickHouse, search engine, analytics database, second operational database, tenant-specific codebase, app fork, or per-tenant source directory.
- Do not claim production/staging/client-delivery approval.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, worker, scheduler, k6, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md
ai-agents/reports/artifacts/20260508-m10-deployment-monitoring-load-test-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ops/**
scripts/**
load-tests/**
.github/**
compose.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md and ai-agents/reports/artifacts/20260508-m10-deployment-monitoring-load-test-qa/**
```

If a defect requires implementation, docs, contracts, runtime config, CI, script, or test changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, test, migration, queue, worker, scheduler, smoke, load-test, and runtime commands.
3. Inspect `git status --short` and distinguish Backend M10 changes from unrelated dirty workspace files. Fail scope drift only when this Backend M10 slice changed forbidden areas.
4. Verify Backend did not edit forbidden ownership areas:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/api-conventions.md
docs/events.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

5. Review `compose.yaml` for:

```text
platform-api preserved
customer and back-office local/dev services preserved
platform-api-worker profile exists
platform-api-scheduler profile exists
platform-api-smoke profile exists
postgres and valkey health dependencies remain sensible
workspace read-only mount is limited to guardrail checks
worker queue list is explicit/configurable
```

6. Review `apps/platform-api/Dockerfile` for development and production/runtime target safety. Confirm no dependency or language-version upgrades were introduced without approval.
7. Review health endpoint registration:

```text
GET /health
GET /health/live
GET /health/ready
GET /api/v1/health
GET /api/v1/health/live
GET /api/v1/health/ready
```

Confirm root health aliases reuse existing safe health behavior and do not expose secrets.

8. Review `platform:smoke`:

```text
checks app config
checks database connectivity
checks Redis/Valkey/cache connectivity
checks queue config
checks seeded central and tenant login viability where enabled
checks monitoring profile, usage meter, alert policy, and health check defaults
supports production-safe no-seed-login mode
does not expose secrets
```

9. Review monitoring/usage default changes:

```text
DemoTenantSeeder creates active monitoring profiles
DemoTenantSeeder creates usage meters
DemoTenantSeeder creates default_health alert policies
DemoTenantSeeder creates health checks
PartnerProvisioningService creates equivalent defaults for provisioned partners
meter names match document/12_MONITORING_OBSERVABILITY.md and Backend handoff
```

10. Review env template boundaries:

```text
infrastructure-level config allowed
tenant logo/theme/payment/domain/feature flags must not be moved into env
local seed credential overrides remain local QA only
CDN/R2/Reverb/monitoring placeholders, if present, must not contain real secrets
```

11. Review M10 docs and ops scripts:

```text
Docker-only commands are documented
runtime roles are documented
health/smoke checks are documented
Cloudflare/HTTPS gates are documented as gates, not complete approval
monitoring/usage readiness is documented
load-test prerequisites and fixture needs are documented
migration rehearsal, cutover, and rollback checklists exist
accepted BO risks are carried forward
release gates not yet satisfied are explicit
helper scripts invoke Docker/Docker Compose, not local PHP/Artisan/k6
```

12. Review load-test scaffolds:

```text
all 7 required scenario files exist
scripts default to Docker-hosted localhost targets
write-heavy/data-dependent scripts require explicit env/fixtures
scripts do not embed production secrets or unapproved credentials
scripts fail early on missing required fixture data instead of claiming pass
ticket image CDN spike remains a placeholder if CDN/R2 is not configured
```

13. Run static source checks:

```sh
rg -n "platform-api-worker|platform-api-scheduler|platform-api-smoke|profiles:|PLATFORM_WORKER_QUEUES|platform:smoke|/workspace:ro" compose.yaml
rg -n "GET /health|/health/live|/health/ready|platform:smoke|migration rehearsal|cutover|rollback|Cloudflare|release gates|hydration|Meno license|npm audit" docs/m10-deployment-monitoring-load-test.md ops/m10/runtime-readiness.md
rg -n "api_requests|booking_requests|checkout_requests|orders|sold_tickets|stock_synced|image_bandwidth_gb|storage_gb|queue_jobs|sync_events|default_health" apps/platform-api/database/seeders/DemoTenantSeeder.php apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php docs/m10-deployment-monitoring-load-test.md
rg -n "LOGO|THEME|PAYMENT|DOMAIN|FEATURE" apps/platform-api/.env.example
find load-tests/k6 -maxdepth 1 -type f -name "*.js" | sort
```

The env scan should not reveal tenant-level logo/theme/payment/domain/feature config moved into env. If names appear only as explicit forbidden scans/tests, document that carefully.

14. Run Docker validation commands.
15. Inspect CI workflow `.github/workflows/platform-api-m10.yml` for Docker-only execution and no host PHP/Composer/Artisan project commands.
16. Run or inspect k6 scaffolds through Docker only:

```text
docker run ... grafana/k6:latest inspect <script>
```

Do not claim full scenario execution unless required fixture data and auth tokens are actually prepared and commands are run.

17. Write QA report to:

```text
ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md
```

## Acceptance Criteria

- Backend M10 implementation stays within approved ownership.
- `platform-api` Docker image builds.
- `compose.yaml` remains valid.
- API, worker, scheduler, and smoke runtime roles exist through Docker Compose services/profiles or an equivalent documented Docker-only path.
- Customer/back-office local Docker services are not broken or removed by the M10 backend slice.
- Root health endpoints and versioned health endpoints return successful responses under Docker runtime.
- `platform:smoke` passes after seeded DB is prepared.
- Queue worker one-shot and scheduler listing run through Docker.
- M10-focused tests pass.
- Full platform-api test suite passes.
- Env template additions remain infrastructure-level only.
- Monitoring profile, usage meters, alert policy, and health check defaults exist for seeded/provisioned partners.
- Load-test scaffolds for all required scenarios exist and are syntactically valid under Docker k6 inspect, or limitations are documented without fake pass claims.
- Migration rehearsal, cutover, and rollback docs exist.
- Accepted BO production-readiness risks are carried forward.
- Release gates not yet satisfied are explicit.
- No new infrastructure dependency, database, source fork, or production approval claim is introduced.
- Known limitations are clearly assigned to follow-up owners.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6 commands.

Required config/build/runtime:

```sh
docker compose config --quiet
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
```

Required migrations/tests:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=BootstrapSeederTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
```

Required routes/health/smoke:

```sh
docker compose exec platform-api php artisan route:list
curl -I --max-time 10 http://localhost:8000/health
curl -I --max-time 10 http://localhost:8000/health/live
curl -I --max-time 10 http://localhost:8000/health/ready
curl -I --max-time 10 http://localhost:8000/api/v1/health
curl -I --max-time 10 http://localhost:8000/api/v1/health/live
curl -I --max-time 10 http://localhost:8000/api/v1/health/ready
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:smoke --no-seed-login
```

Required worker/scheduler:

```sh
docker compose run --rm platform-api php artisan queue:work --once --tries=1
docker compose run --rm platform-api php artisan schedule:list
docker compose --profile smoke run --rm platform-api-smoke
```

Required k6 scaffold inspection through Docker:

```sh
docker run --rm grafana/k6:latest version
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/customer-stock-search.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/concurrent-booking-same-stock.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/checkout-wallet-consistency.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/partner-tenant-burst-sync.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-publish-spike.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-checking-queue-chunk.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

If Docker image pull or runner availability blocks k6 inspection, document the limitation and perform the strongest static JS review available without running host k6.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
compose/runtime role review
Docker image/build review
health endpoint review
platform:smoke review
monitoring/usage defaults review
env template boundary review
load-test scaffold review
CI workflow review
docs/migration/cutover/rollback review
Docker validation commands and results
k6 Docker inspection results or limitations
accepted risks carried forward
release gates still not satisfied
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```
