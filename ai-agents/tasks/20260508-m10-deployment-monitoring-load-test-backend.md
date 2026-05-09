# 20260508-m10-deployment-monitoring-load-test - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved the full Back-office Operations Page Slice 1 chain with accepted risks and instructed Orchestrator to resume the main execution plan.

Select the next main-plan slice from:

```text
document/15_EXECUTION_PLAN.md
document/08_IMPLEMENTATION_ROADMAP.md
```

The next main-plan slice is Milestone 10: Deployment, Monitoring, Load Test, Migration.

This is the first M10 backend/ops foundation slice. Carry forward accepted production-readiness risks from the back-office approval, but do not treat the prior approval as staging, production, or client-delivery approval.

## Objective

Implement the backend/runtime foundation for M10 release readiness: Docker/Compose runtime guardrails, API/worker deployment readiness, environment templates, health/smoke checks, monitoring and usage-metering foundations, load-test script scaffolding, and migration/cutover/rollback documentation.

The goal is to make M10 measurable and testable without changing customer UI flow, back-office UI behavior, backend business contracts, or tenant isolation rules.

## Source Of Truth

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
- `ai-agents/decisions/20260508-back-office-operations-page-slice-1-approval-decision.md`
- `ai-agents/handoffs/20260508-back-office-operations-page-slice-1-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-approval-decision.md`
- `compose.yaml`
- `apps/platform-api/**`

## Scope

Implement a focused backend/ops M10 foundation.

Approved implementation scope:

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
ai-agents/handoffs/20260508-m10-deployment-monitoring-load-test-backend-handoff.md
```

Required focus areas:

```text
production-ready platform-api Docker image target and worker/runtime entrypoints where missing
Docker Compose service definitions or profiles for API, queue worker, scheduler, and health/smoke validation
environment template coverage for infrastructure-level config only
health/smoke commands that can run through Docker
monitoring/usage metering backend foundations or readiness checks that build on existing M1/M2/M9 tables/services
load-test script scaffolding for key M10 scenarios
migration rehearsal, cutover, and rollback documentation
carry-forward risk register for back-office hydration, Meno license, npm audit, seed credential limits, maintenance bypass list gap, backend menu category/icon fields, and Nuxt warnings
```

Minimum load-test scenarios to scaffold:

```text
partner tenant burst sync
customer stock search
concurrent booking same stock
checkout wallet consistency
reward publish spike
reward checking queue/chunk path
ticket image CDN spike placeholder
```

If a scenario cannot be executable in this slice, create a safe script placeholder plus documentation with required seed data, expected metrics, and follow-up owner. Do not fake passing results.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement customer UI changes.
- Do not implement back-office UI changes.
- Do not modify public customer flow.
- Do not change backend business contracts, response envelopes, permission scopes, tenant resolution, or approved OpenAPI paths.
- Do not edit `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, or `document/**`.
- Do not add NoSQL, ClickHouse, a search engine, analytics database, or a second operational database without a Coordinator-approved architecture decision.
- Do not create tenant-specific codebases, app forks, or per-tenant source directories.
- Do not resolve Meno license by guessing terms or adding unverified license text.
- Do not upgrade Laravel, PHP, Composer, Node, Nuxt, or package dependencies unless Coordinator explicitly approves.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, or runtime commands on the host machine.

## File Ownership

Can edit:

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
ai-agents/handoffs/20260508-m10-deployment-monitoring-load-test-backend-handoff.md
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
docs/api-conventions.md
docs/events.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-deployment-monitoring-load-test-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, queue, worker, scheduler, and load-test commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Inspect current runtime files before editing:

```text
compose.yaml
apps/platform-api/Dockerfile
apps/platform-api/.env.example
apps/platform-api/composer.json
apps/platform-api/routes/api.php
apps/platform-api/app/Console/**
apps/platform-api/app/Shared/**
apps/platform-api/tests/**
```

5. Add or harden Docker image targets/entrypoints for `platform-api` so the API container and worker-style runtime can be built from one shared codebase.
6. Add Docker Compose service definitions or profiles for backend runtime roles where missing:

```text
platform-api
platform-api-worker or equivalent queue worker role
platform-api-scheduler or equivalent scheduler role
postgres
valkey
```

Keep local/dev commands Docker-only and preserve existing `platform-api`, `customer`, and `back-office` local services.

7. Ensure environment templates cover infrastructure-level config only:

```text
DB_*
REDIS_*
QUEUE_CONNECTION
CACHE_STORE
SESSION_DRIVER
APP_URL / site URLs where already used
S3/R2/CDN placeholders
REVERB placeholders if already applicable
monitoring/metrics toggles if implemented
seed credential overrides already approved for local QA
```

Do not move tenant logo/theme/payment/domain/feature flags into env files.

8. Add safe backend health/smoke checks or scripts that can run through Docker and verify:

```text
/health
/health/live
/health/ready
database connectivity
Redis/Valkey connectivity
queue configuration visibility
seeded central admin and tenant owner login viability where practical
```

9. Add or harden monitoring/usage readiness around existing partner monitoring and usage records:

```text
partner monitoring profile exists after seed/provisioning
usage meters exist after seed/provisioning
partner health checks are queryable
daily usage summary path is documented or scaffolded
metrics labels include partner/tenant context where implemented
```

10. Add load-test script scaffolding under `load-tests/**` or equivalent for the required M10 scenarios. Scripts must target local Docker-hosted services by default and avoid embedding secrets beyond approved local seeded credentials.
11. Add documentation in `docs/m10-deployment-monitoring-load-test.md` covering:

```text
runtime services and Docker-only commands
image/worker/scheduler roles
environment variable boundaries
Cloudflare/HTTPS readiness gates
monitoring and usage-metering readiness
load-test scenarios and how to run them through Docker
migration rehearsal checklist
cutover checklist
rollback checklist
accepted risks carried forward from Back-office Operations Page Slice 1
release gates not yet satisfied
```

12. Add or update tests/checks so M10 guardrails are caught in future:

```text
Docker-only command examples remain documented
env template does not use tenant-level config for logo/theme/domain/payment/feature flags
worker/scheduler services or documented commands exist
monitoring/usage seed/provisioning defaults remain present
load-test scripts are present and syntactically valid where practical
```

13. Run Docker-only validation commands.
14. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-deployment-monitoring-load-test-backend-handoff.md
```

## Acceptance Criteria

- M10 backend/ops foundation is implemented without changing customer or back-office source ownership.
- `platform-api` Docker image/runtime remains buildable.
- Backend worker/scheduler runtime roles are available through Docker Compose services, profiles, or clearly documented Docker-only commands.
- Docker Compose local/dev services for customer and back-office are preserved.
- All runtime/test/build/migration/queue examples use Docker Compose only.
- Environment templates separate infrastructure config from tenant config.
- Health/smoke checks cover API, database, Redis/Valkey, and queue readiness where practical.
- Partner monitoring profile, usage meters, alert policy, and health check readiness are tested or documented from existing seed/provisioning behavior.
- Load-test scaffolding exists for M10 peak scenarios and does not claim fake pass results.
- Migration rehearsal, cutover, and rollback checklists exist.
- Carry-forward risk register includes accepted back-office production-readiness risks.
- No tenant-specific app fork, per-tenant source directory, second operational database, or unapproved infrastructure dependency is introduced.
- Docker validation passes, or failures are documented with exact evidence and owner.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6 commands.

Required baseline:

```sh
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test
```

Required health/smoke validation, adjusted only if Backend implements a more specific Docker-only command:

```sh
docker compose exec platform-api php artisan route:list
curl -I --max-time 10 http://localhost:8000/health
curl -I --max-time 10 http://localhost:8000/health/live
curl -I --max-time 10 http://localhost:8000/health/ready
```

Worker/scheduler validation must use Docker Compose only. Examples:

```sh
docker compose run --rm platform-api php artisan queue:work --once --tries=1
docker compose run --rm platform-api php artisan schedule:list
```

If load-test scripts require a runner image, use Docker. Example:

```sh
docker run --rm -v "$PWD/load-tests:/scripts" grafana/k6:latest run /scripts/<scenario>.js
```

If the runner image is unavailable, record the limitation in the handoff and validate scripts with the strongest Docker-only/static checks available.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-deployment-monitoring-load-test-backend-handoff.md
```

Must include:

```text
what was done
files changed
runtime/deployment approach
monitoring/usage readiness approach
load-test scaffolding summary
migration/cutover/rollback documentation summary
Docker validation commands and results
known risks carried forward
follow-up slices needed for customer/back-office/production gates
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```
