# 20260508-m10-migration-rehearsal-cutover-rollback - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator approved `20260508-m10-horizon-reverb-scheduler-hardening` for local/dev runtime hardening readiness with accepted risks and instructed Orchestrator to open:

```text
20260508-m10-migration-rehearsal-cutover-rollback
```

Backend Develop reports the migration rehearsal/cutover/rollback slice is complete. Validate the local/dev readiness foundation without granting staging, production, client delivery, real old-data migration, real production cutover, real production rollback, production secret-management approval, or final M10 release approval.

## Objective

Verify that Backend implemented a Docker-only, QA-verifiable local/dev migration rehearsal/cutover/rollback foundation:

```text
platform:migration:rehearsal --dry-run --format=json safe JSON command
old-data migration strategy artifact and idempotency/reject boundaries
synthetic/seeded rehearsal fixture boundary
database/object-storage snapshot requirements
cutover operator runbook and abort criteria
rollback drill runbook and rollback command boundaries
production secret-management boundary and redaction
bounded Docker-only helper scripts
docs/runbook updates
no API/customer/back-office/source-of-truth contract drift
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-horizon-reverb-scheduler-hardening-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-horizon-reverb-scheduler-hardening-qa-report.md`
- `ai-agents/tasks/20260508-m10-migration-rehearsal-cutover-rollback-backend.md`
- `ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md`
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
- `compose.yaml`
- `apps/platform-api/.env.example`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/app/Console/Commands/PlatformMigrationRehearsalCommand.php`
- `apps/platform-api/app/Shared/Migration/MigrationRehearsalReadinessService.php`
- `apps/platform-api/app/Console/README.md`
- `apps/platform-api/tests/Feature/M10MigrationRehearsalCutoverRollbackTest.php`
- `apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php`
- `apps/platform-api/tests/Feature/M10HorizonReverbSchedulerHardeningTest.php`
- `apps/platform-api/tests/Feature/M10ProductionObservabilityAlertingTest.php`
- `apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- `scripts/platform-migration-rehearsal.sh`
- `scripts/platform-cutover-preflight.sh`
- `scripts/platform-rollback-drill.sh`
- `scripts/platform-api-smoke.sh`
- `scripts/platform-runtime-readiness.sh`
- `ops/m10/old-data-migration-strategy.md`
- `ops/m10/migration-rehearsal-fixtures.md`
- `ops/m10/migration-rehearsal-runbook.md`
- `ops/m10/cutover-runbook.md`
- `ops/m10/rollback-drill-runbook.md`
- `ops/m10/snapshot-requirements.md`
- `ops/m10/production-secret-boundary.md`
- `ops/m10/runtime-readiness.md`

## Scope

Validate Backend/Ops implementation for M10 migration rehearsal, cutover, and rollback readiness.

Inspect at minimum:

```text
apps/platform-api/app/Console/Commands/PlatformMigrationRehearsalCommand.php
apps/platform-api/app/Shared/Migration/MigrationRehearsalReadinessService.php
apps/platform-api/bootstrap/app.php
apps/platform-api/config/platform.php
apps/platform-api/.env.example
apps/platform-api/tests/Feature/M10MigrationRehearsalCutoverRollbackTest.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
scripts/platform-migration-rehearsal.sh
scripts/platform-cutover-preflight.sh
scripts/platform-rollback-drill.sh
ops/m10/old-data-migration-strategy.md
ops/m10/migration-rehearsal-fixtures.md
ops/m10/migration-rehearsal-runbook.md
ops/m10/cutover-runbook.md
ops/m10/rollback-drill-runbook.md
ops/m10/snapshot-requirements.md
ops/m10/production-secret-boundary.md
ops/m10/runtime-readiness.md
docs/backend-console-commands.md
docs/m10-deployment-monitoring-load-test.md
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, ops, scripts, compose, workflows, or Board.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, or business rules.
- Do not approve staging, production, client delivery, real old-data migration, real production snapshot, real object-storage snapshot, real production secret management, real production cutover, real production rollback, Meno license, npm audit, back-office production-readiness, or final M10 release.
- Do not connect to, import, export, mutate, truncate, overwrite, dump, restore, or otherwise operate on real production data or real old-data sources.
- Do not run destructive production migration or rollback commands.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, Cloudflare CLI, wrangler, aws, psql, pg_dump, or runtime commands on the host machine.
- Do not copy real production database URLs, object-storage credentials, Cloudflare/R2 secrets, app keys, bearer tokens, DSNs, passwords, private keys, signed URLs, customer data, old-data payloads, or production hostnames into QA reports/artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-migration-rehearsal-cutover-rollback-qa-report.md
ai-agents/reports/artifacts/20260508-m10-migration-rehearsal-cutover-rollback-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260508-m10-migration-rehearsal-cutover-rollback-qa-report.md and ai-agents/reports/artifacts/20260508-m10-migration-rehearsal-cutover-rollback-qa/**
```

If a defect requires implementation, docs, schema, command, readiness logic, helper script, migration artifact, cutover/rollback runbook, secret boundary, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, Cloudflare, wrangler, aws, psql, pg_dump, database, object-storage, and runtime commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Review Backend handoff for:

```text
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
```

5. Verify command registration and safe output:

```text
platform:migration:rehearsal --dry-run --format=json
```

The command must emit safe JSON, avoid external calls, avoid starting long-lived processes, avoid destructive production operations, report blockers, and keep `production_approved=false`.

6. Verify migration rehearsal JSON fields:

```text
status is blocked_external while real old-data/snapshot/secret/cutover/rollback evidence is missing
production_approved=false
boundary.local_dev_verifiable=true
boundary.dry_run=true
boundary.synthetic_seeded_data_only=true
boundary.external_services_called=false
boundary.long_lived_processes_started=false
boundary.destructive_production_operations_attempted=false
boundary.old_data_payloads_loaded=false
boundary.staging_approved=false
boundary.production_approved=false
boundary.production_cutover_approved=false
boundary.production_rollback_approved=false
old_data_migration_strategy.status=ready_local
rehearsal_fixtures.status=ready_local
snapshot_requirements.status=blocked_external
cutover.status=blocked_external
rollback.status=blocked_external
production_secret_boundary.status=blocked_external
helpers.status=ready_local
blockers include real_old_data_source_missing
blockers include real_database_snapshot_missing
blockers include real_object_storage_metadata_snapshot_missing
blockers include production_secret_management_missing
blockers include staging_rehearsal_not_completed
blockers include rollback_rehearsal_not_executed
docker_validation_commands include Docker-only commands
```

7. Verify fake secret/config redaction. The following fake values must not appear raw in migration rehearsal JSON output or QA artifacts:

```text
legacy-postgres-redaction-source
postgres://legacy-user:legacy-password@legacy-prod.internal/newpaotang
legacy-source-token-placeholder
legacy-ticket-image-bucket
secret-manager/prod/migration
paotang-api:release-redaction
paotang-api:previous-redaction
```

Expected safe placeholders:

```text
production_secret_boundary.redacted_config.source_dsn=[REDACTED]
production_secret_boundary.redacted_config.source_token=[REDACTED]
production_secret_boundary.redacted_config.object_storage_bucket=[CONFIGURED]
production_secret_boundary.redacted_config.secret_reference=[REDACTED]
cutover.redacted_config.release_image_tag=[CONFIGURED]
rollback.redacted_config.previous_image_tag=[CONFIGURED]
```

8. Verify old-data migration strategy artifact:

```text
supported source categories are documented
unsupported/unknown categories are explicit
tenant/partner identity is required
current platform modules/tables are targets
status mapping must be explicit
unknown records go to reject report
idempotency/replay rules exist
payload hash conflicts are rejected
PII/secrets/raw payload redaction is explicit
local/dev dry-run does not claim real production migration
```

9. Verify rehearsal fixture/data boundary:

```text
synthetic and seeded data only
expected seeders are documented
real old-data dumps, customer exports, snapshots, object manifests, signed URLs, bearer tokens, and PII must not be committed
real old-data source remains an external blocker
```

10. Verify snapshot requirements:

```text
database snapshot scope includes schema, tenant data, ledger/order/reward/report state, outbox/inbox, audit, and monitoring state
object-storage metadata snapshot scope includes ticket image keys, variants, CDN policy metadata, bucket prefixes, and ownership maps
raw object binaries, signed URLs, and production credentials are not committed
restore rehearsal evidence is required before production approval
```

11. Verify cutover runbook:

```text
preflight checklist
release tag/image boundary
previous image tag recorded for rollback
database snapshot and restore-test requirement
object-storage metadata snapshot requirement
queue pause/drain decision
tenant maintenance decision
dry-run before production-safe migration
health/smoke/runtime readiness checks
Cloudflare/CDN/R2 checkpoints
monitoring and alert checkpoints
abort criteria
communications and evidence capture
production cutover remains blocked pending Coordinator/Ops approval
```

12. Verify rollback drill runbook:

```text
previous image tag requirement
database backward-compatibility boundary
feature flag/off-switch boundary
queue pause/resume boundary
tenant maintenance boundary
object-storage rollback or repair boundary
post-rollback health/smoke/readiness checks
residual repair tasks for Coordinator review
no destructive down-migration or irreversible schema rollback claim
```

13. Verify production secret-management boundary:

```text
.env.example contains placeholders only
production values must come from Coordinator/Ops-approved secret manager outside committed files
readiness output uses booleans, [CONFIGURED], [REDACTED], or null
raw database URLs, access tokens, object-storage credentials, signed URLs, private keys, DSNs, customer data, old-data payloads, and production hostnames are not printed
tenant logo/theme/payment/domain/feature config is not moved into env
```

14. Verify helper scripts:

```text
scripts/platform-migration-rehearsal.sh uses docker compose exec/run platform-api php artisan platform:migration:rehearsal --dry-run --format=json
scripts/platform-cutover-preflight.sh uses Docker-only bounded commands
scripts/platform-rollback-drill.sh uses Docker-only bounded commands
no helper runs PHP, Composer, Artisan, psql, pg_dump, Node, npm, Nuxt, Vite, or other project runtime command directly on host
```

15. Verify docs/runbooks:

```text
docs/backend-console-commands.md lists platform:migration:rehearsal
docs/m10-deployment-monitoring-load-test.md documents migration rehearsal/cutover/rollback readiness and blockers
ops/m10/runtime-readiness.md references migration rehearsal/cutover/rollback boundary if appropriate
local/dev vs staging/production boundary is preserved
```

16. Verify existing M10 guardrails still pass:

```text
platform:runtime:readiness --format=json still reports Horizon/Reverb external blockers safely
M10 Cloudflare/CDN/R2 readiness tests still pass
M10 observability tests still pass
M10 deployment readiness tests still pass
Console command structure tests still pass
```

17. Verify no forbidden API/customer/back-office/source-of-truth drift is attributable to this slice.
18. Capture or summarize safe command output under:

```text
ai-agents/reports/artifacts/20260508-m10-migration-rehearsal-cutover-rollback-qa/**
```

Do not copy secrets into artifacts. Redact any sensitive-looking values.

19. Write QA report to:

```text
ai-agents/reports/20260508-m10-migration-rehearsal-cutover-rollback-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- `M10MigrationRehearsalCutoverRollbackTest` passes.
- `M10DeploymentReadinessTest` passes.
- `M10HorizonReverbSchedulerHardeningTest` passes.
- `M10ProductionObservabilityAlertingTest` passes.
- `M10CloudflareHttpsWafCdnR2Test` passes.
- `ConsoleCommandStructureTest` passes.
- Full platform-api test suite passes.
- `route:list` passes and shows no public API contract drift attributable to this slice.
- `platform:smoke` passes after seeded DB is restored if needed.
- `platform:runtime:readiness --format=json` still passes and preserves safe runtime boundary.
- `platform:migration:rehearsal --dry-run --format=json` passes and emits safe JSON.
- Migration rehearsal output keeps `production_approved=false`.
- Migration rehearsal output does not expose database URLs, object-storage credentials, signed URLs, private keys, bearer tokens, passwords, DSNs, customer PII, old-data payloads, release tags, previous tags, secret references, or production hostnames.
- Old-data migration strategy, fixture boundary, snapshot requirements, cutover runbook, rollback drill runbook, and production secret boundary artifacts exist and preserve local/dev vs production boundaries.
- Helper scripts are Docker-only and bounded.
- Real old-data source, real production snapshots, real object storage, real production secrets, staging rehearsal, production cutover, production rollback, and final M10 release approval remain explicit blockers.
- No customer/back-office/source-of-truth contract drift is found.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, Cloudflare, wrangler, aws, psql, pg_dump, database, object-storage, and runtime commands.

Required Docker validation:

```sh
docker compose config --quiet
docker compose --profile worker --profile scheduler config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10MigrationRehearsalCutoverRollbackTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
docker compose run --rm platform-api php artisan migrate:status
docker compose run --rm platform-api php artisan schedule:list
docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default
docker compose run --rm platform-api php artisan list
```

Required fake migration redaction probe:

```sh
docker compose run --rm -e MIGRATION_REHEARSAL_SOURCE_TYPE=legacy-postgres-redaction-source -e MIGRATION_REHEARSAL_SOURCE_DSN=postgres://legacy-user:legacy-password@legacy-prod.internal/newpaotang -e MIGRATION_REHEARSAL_SOURCE_TOKEN=legacy-source-token-placeholder -e MIGRATION_REHEARSAL_OBJECT_STORAGE_BUCKET=legacy-ticket-image-bucket -e MIGRATION_REHEARSAL_SECRET_REFERENCE=secret-manager/prod/migration -e PLATFORM_RELEASE_IMAGE_TAG=paotang-api:release-redaction -e PLATFORM_PREVIOUS_IMAGE_TAG=paotang-api:previous-redaction platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

Required helper/static validation:

```sh
git status --short
sh -n scripts/platform-migration-rehearsal.sh
sh -n scripts/platform-cutover-preflight.sh
sh -n scripts/platform-rollback-drill.sh
rg -n "platform:migration:rehearsal|migration rehearsal|cutover|rollback|snapshot|production_approved|dry-run" apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md
rg -n "MIGRATION_REHEARSAL_SOURCE_TYPE|MIGRATION_REHEARSAL_SOURCE_DSN|MIGRATION_REHEARSAL_SOURCE_TOKEN|MIGRATION_REHEARSAL_OBJECT_STORAGE_BUCKET|MIGRATION_REHEARSAL_SECRET_REFERENCE|PLATFORM_RELEASE_IMAGE_TAG|PLATFORM_PREVIOUS_IMAGE_TAG" apps/platform-api/.env.example apps/platform-api/config/platform.php docs/backend-console-commands.md ops/m10
rg -n "password|secret|token|private_key|BEGIN PRIVATE KEY|Bearer |signed URL|signed_url|DATABASE_URL|R2_SECRET|CLOUDFLARE_API_TOKEN|MIGRATION_REHEARSAL_SOURCE_DSN|MIGRATION_REHEARSAL_SOURCE_TOKEN" apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md
rg -n "legacy-postgres-redaction-source|postgres://legacy-user:legacy-password@legacy-prod.internal/newpaotang|legacy-source-token-placeholder|legacy-ticket-image-bucket|secret-manager/prod/migration|paotang-api:release-redaction|paotang-api:previous-redaction" ai-agents/reports/artifacts/20260508-m10-migration-rehearsal-cutover-rollback-qa ai-agents/reports/20260508-m10-migration-rehearsal-cutover-rollback-qa-report.md
```

Interpretation notes:

```text
The final rg for fake migration values should return no matches after QA writes redacted artifacts/report. If it returns matches because QA intentionally recorded the forbidden-value checklist, redact those values and re-run.
Secret scans may match safe placeholders, env names, docs examples, local seed-password placeholders, and redaction test fixture names. QA must distinguish placeholders/redacted output from real secret leakage.
Do not run real production dump/restore, psql, pg_dump, Cloudflare, wrangler, aws, long-lived scheduler, or long-lived worker commands.
Do not run host PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6 commands.
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-migration-rehearsal-cutover-rollback-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
migration rehearsal command review
safe output/redaction review
old-data migration strategy review
rehearsal fixture/data boundary review
snapshot requirements review
cutover runbook review
rollback drill runbook review
production secret-management boundary review
helper script review
docs/runbook boundary review
route-list/API contract review
test results
static check results
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
