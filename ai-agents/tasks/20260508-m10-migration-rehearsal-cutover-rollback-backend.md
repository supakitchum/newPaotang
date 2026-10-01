# 20260508-m10-migration-rehearsal-cutover-rollback - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved `20260508-m10-horizon-reverb-scheduler-hardening` for local/dev runtime hardening readiness with accepted risks and opened the next M10 release-gate slice:

```text
20260508-m10-migration-rehearsal-cutover-rollback
```

Target Backend/Ops implementation first unless a safer ownership split is found.

This slice must cover:

```text
old-data migration script strategy and dry-run/rehearsal commands
rehearsal fixture/data set boundaries
cutover checklist and operator runbook
rollback drill and rollback command boundaries
database/object-storage snapshot requirements
production secret-management boundary for migration/cutover inputs
Docker-only validation commands
local/dev vs staging/production boundary
QA acceptance criteria for rehearsal evidence vs remaining production blockers
```

Keep these gates separate unless Coordinator approves bundling:

```text
Meno license compliance
npm audit remediation
back-office production-readiness cleanup
final M10 release approval
```

## Objective

Implement verifiable local/dev readiness for M10 migration rehearsal, cutover planning, and rollback drill evidence without claiming staging, production, client delivery, or final M10 approval.

The goal is to make migration/cutover/rollback readiness measurable through Docker-only commands and safe artifacts:

```text
old-data migration strategy with explicit dry-run/rehearsal command boundary
local/dev rehearsal fixture/data set boundary and sample-safe evidence path
snapshot requirements for database and object-storage metadata
operator cutover checklist and abort criteria
rollback drill runbook and rollback command boundaries
production secret-management boundary for migration/cutover inputs
safe machine-readable readiness output or equivalent report
tests that prevent migration/cutover/rollback docs and commands from drifting
```

This slice is not production approval. Real old-data sources, real production snapshots, real object storage, real production secrets, real staging/prod cutover, and real rollback execution remain blockers unless Coordinator later provides verified infrastructure and credentials.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-horizon-reverb-scheduler-hardening-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-horizon-reverb-scheduler-hardening-qa-report.md`
- `ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md`
- `ai-agents/tasks/20260508-m10-horizon-reverb-scheduler-hardening-backend.md`
- `docs/docker-runtime-policy.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `docs/backend-console-commands.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/backend-model-layer.md`
- `docs/events.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/15_EXECUTION_PLAN.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/runtime-hardening-readiness.md`
- `ops/m10/cloudflare-https-waf-cdn-r2-readiness.md`
- `ops/m10/observability-signal-inventory.md`
- `ops/m10/alert-channel-runbook.md`
- `compose.yaml`
- `scripts/platform-api-smoke.sh`
- `scripts/platform-runtime-readiness.sh`
- `apps/platform-api/.env.example`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/database/migrations/**`
- `apps/platform-api/database/seeders/**`
- `apps/platform-api/app/Console/Commands/**`
- `apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php`
- `apps/platform-api/tests/Feature/M10HorizonReverbSchedulerHardeningTest.php`
- `apps/platform-api/tests/Feature/M10ProductionObservabilityAlertingTest.php`
- `apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`

## Scope

Implement a focused Backend/Ops slice for migration rehearsal, cutover, and rollback readiness.

Approved implementation scope:

```text
apps/platform-api/**
apps/platform-api/.env.example
ops/m10/**
scripts/**
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-bootstrap-seeders.md
docs/backend-model-layer.md
compose.yaml only if a Docker-only helper profile is impossible without it
.github/workflows/platform-api-m10.yml only if updating existing Docker-only M10 validation for this slice
ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md
```

Expected implementation areas:

```text
Docker-runnable migration rehearsal readiness command, such as platform:migration:rehearsal --dry-run --format=json
old-data migration strategy artifact with supported source types, mapping boundary, idempotency rules, and rejected/unknown data handling
local/dev rehearsal fixture/data set boundary that does not require real production data
database snapshot and object-storage metadata snapshot requirement artifact
cutover operator runbook with preflight, freeze/drain, migrate, smoke, monitor, abort, and communication checkpoints
rollback drill runbook with previous image tag, feature flag, queue pause/resume, tenant maintenance, DB compatibility, and data repair boundaries
production secret-management boundary for migration/cutover inputs with placeholders only and redaction rules
bounded helper scripts that call Docker Compose/Docker only and never run PHP/Artisan on the host
tests for command registration, safe JSON, docs/runbooks, no raw secret leakage, and M10 release-gate boundaries
```

Recommended ops artifacts:

```text
ops/m10/old-data-migration-strategy.md
ops/m10/migration-rehearsal-runbook.md
ops/m10/migration-rehearsal-fixtures.md
ops/m10/cutover-runbook.md
ops/m10/rollback-drill-runbook.md
ops/m10/snapshot-requirements.md
ops/m10/production-secret-boundary.md
```

Recommended helper scripts:

```text
scripts/platform-migration-rehearsal.sh
scripts/platform-cutover-preflight.sh
scripts/platform-rollback-drill.sh
```

If the implementation uses different names, keep the same safety guarantees and document the equivalents in the Backend handoff.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement customer UI changes.
- Do not implement back-office UI changes.
- Do not change public API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, or business rules.
- Do not edit `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, or `document/**`.
- Do not bundle Meno license compliance, npm audit remediation, back-office production-readiness cleanup, or final M10 release approval.
- Do not claim staging, production, client delivery, real production migration, real production cutover, real production rollback, real production snapshot, real production object storage, real production secret-management approval, or final M10 release approval.
- Do not connect to, import, export, mutate, truncate, overwrite, or otherwise operate on real production data or real old-data sources.
- Do not add destructive production migration commands. `migrate:fresh --seed` is local/test rehearsal only.
- Do not add rollback logic that depends on destructive down migrations or irreversible schema rollback claims.
- Do not commit real production database URLs, object-storage credentials, Cloudflare/R2 secrets, app keys, bearer tokens, DSNs, passwords, private keys, signed URLs, customer data, old-data dumps, or production hostnames.
- Do not move tenant logo/theme/payment/domain/feature config into env.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, Cloudflare CLI, wrangler, aws, psql, pg_dump, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
apps/platform-api/.env.example
ops/m10/**
scripts/**
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-bootstrap-seeders.md
docs/backend-model-layer.md
compose.yaml only if a Docker-only helper profile is impossible without it
.github/workflows/platform-api-m10.yml only if updating existing Docker-only M10 validation for this slice
ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md
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
.github/** except .github/workflows/platform-api-m10.yml if needed for Docker-only M10 validation
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, test, runtime, migration, queue, scheduler, k6, Cloudflare/R2, database, object-storage, and readiness validation commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Inspect current migrations, seeders, smoke checks, runtime readiness command, queue/scheduler helpers, and M10 ops artifacts before editing.
5. Define the old-data migration strategy:

```text
supported source data categories
explicitly unsupported or unknown source data categories
mapping strategy into current platform tables/modules
idempotency and replay rules
validation and reject-report rules
PII/secrets redaction rules
dry-run-only behavior for local/dev
production blockers and required evidence
```

6. Add a Docker-runnable migration rehearsal command, preferably:

```text
php artisan platform:migration:rehearsal --dry-run --format=json
```

The command should emit safe JSON for rehearsal status, fixture coverage, snapshot requirements, cutover readiness, rollback readiness, blockers, validation commands, and `production_approved=false`.

7. The migration rehearsal output must:

```text
not emit raw secrets, production URLs, signed URLs, customer PII, or old-data payloads
not call external services
not start long-lived workers or scheduler loops
not run destructive production operations
not claim production approval
include local/dev verifiable status
include explicit blockers for missing real old-data source, real snapshots, object storage, production secret management, staging rehearsal, and production cutover
include Docker validation commands
```

8. Define local/dev rehearsal fixtures or fixture boundaries. Use synthetic or seeded data only. Do not commit real old-data dumps.
9. Define database and object-storage snapshot requirements:

```text
database snapshot scope and restore boundary
object-storage metadata snapshot scope
ticket-image/object key inventory expectations
snapshot retention and access-control expectations
restore rehearsal evidence required before production
```

10. Define the cutover runbook:

```text
preflight checklist
release tag/image boundary
queue pause/drain decision
maintenance-mode/tenant isolation decision
migration dry-run and production-safe migration boundary
health/smoke/runtime readiness checks
Cloudflare/CDN/R2 verification checkpoints
monitoring and alert checkpoints
abort criteria
communications and evidence capture
```

11. Define the rollback drill runbook:

```text
previous image tag requirement
database backward-compatibility boundary
feature flag/off-switch boundary
queue pause/resume boundary
tenant maintenance boundary
object-storage rollback/data-repair boundary
health/smoke checks after rollback
residual repair tasks for Coordinator review
```

12. Define production secret-management boundary for migration/cutover inputs. Use placeholders only. Document required external owner/system and never commit real values.
13. Add or update bounded Docker helper scripts where useful. Scripts must call Docker Compose or Docker only and must not run PHP/Artisan on the host.
14. Update M10 docs and backend docs with commands, artifacts, release boundary, and remaining blockers.
15. Add or update tests for:

```text
migration rehearsal command registration and safe JSON
production_approved=false and blocker coverage
fixture/data boundary docs
cutover and rollback runbook artifacts
snapshot requirement docs
secret-management placeholder/redaction rules
Docker-only helper script expectations
existing M10 runtime/Cloudflare/observability tests still green
```

16. Run Docker-only validation commands.
17. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md
```

## Acceptance Criteria

- Docker Compose config remains valid.
- A migration rehearsal command or equivalent safe report exists and is Docker-runnable.
- Rehearsal output is machine-readable when `--format=json` is requested.
- Rehearsal output keeps `production_approved=false`.
- Rehearsal output does not expose production URLs, database URLs, object-storage credentials, signed URLs, private keys, bearer tokens, passwords, DSNs, customer PII, or old-data payloads.
- Local/dev rehearsal uses synthetic/seeded data only.
- Real old-data source, real production snapshots, real object storage, real production secrets, staging rehearsal, production cutover, and production rollback remain explicit blockers unless verified evidence exists.
- Old-data migration strategy documents idempotency, replay, mapping, rejects, and unsupported data boundaries.
- Snapshot requirements cover database and object-storage metadata.
- Cutover runbook includes preflight, release tag/image boundary, queue/scheduler/maintenance decisions, health/smoke/runtime checks, monitoring, abort criteria, and evidence capture.
- Rollback runbook includes previous image tag, DB compatibility, feature flags, queue pause/resume, tenant maintenance, object-storage/data-repair boundary, and post-rollback checks.
- Helper scripts, if added, invoke Docker Compose/Docker and never run project runtime commands on the host.
- Backend docs list the new commands and local/dev vs staging/production boundary.
- Existing M10 readiness tests remain green.
- Full platform-api regression passes.
- No customer/back-office/source-of-truth contract drift is introduced.

## Validation Commands

Use Docker commands only for all PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6/migration/queue/scheduler/runtime/database/object-storage commands.

Required setup:

```sh
docker compose config --quiet
docker compose --profile worker --profile scheduler config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
```

Required Backend regression:

```sh
docker compose run --rm platform-api php artisan test --filter=M10MigrationRehearsalCutoverRollbackTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
```

Required runtime commands:

```sh
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
docker compose run --rm platform-api php artisan migrate:status
docker compose run --rm platform-api php artisan schedule:list
docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default
docker compose run --rm platform-api php artisan list
```

If the command name differs, validate the chosen equivalent and document the difference in the handoff.

Required static/helper validation:

```sh
git status --short
sh -n scripts/platform-migration-rehearsal.sh
sh -n scripts/platform-cutover-preflight.sh
sh -n scripts/platform-rollback-drill.sh
rg -n "platform:migration:rehearsal|migration rehearsal|cutover|rollback|snapshot|production_approved|dry-run" apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts
rg -n "password|secret|token|private_key|BEGIN PRIVATE KEY|Bearer |signed URL|signed_url|DATABASE_URL|R2_SECRET|CLOUDFLARE_API_TOKEN" apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts
```

If a listed helper script is not created because Backend chose a different safe equivalent, document the equivalent validation in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md
```

Must include:

```text
what was done
files changed
old-data migration strategy summary
rehearsal fixture/data boundary
migration rehearsal command/report summary
cutover runbook summary
rollback drill runbook summary
database/object-storage snapshot requirements
production secret-management boundary
Docker validation
remaining staging/production blockers
known risks
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```
