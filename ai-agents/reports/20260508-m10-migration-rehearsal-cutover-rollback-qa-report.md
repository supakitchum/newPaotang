# QA Report: M10 Migration Rehearsal, Cutover, Rollback

Date: 2026-05-08
Agent: QA Tester
Task: `20260508-m10-migration-rehearsal-cutover-rollback`
Verdict: PASS WITH RISKS
Next Agent: Coordinator

## Summary

QA verified the M10 migration rehearsal readiness command, helper scripts, runbooks, documentation, and Docker-only validation path. The local/dev contract is implemented: rehearsal is dry-run, synthetic/seeded-data only, does not call external services, does not start long-lived workers, does not attempt destructive production operations, does not load old-data payloads, and keeps production/cutover/rollback approvals closed.

No QA defects found. The remaining risk is intentionally external and should stay with Coordinator/Ops: real old-data source, database snapshot, object-storage metadata snapshot, production secret management, staging rehearsal, cutover approval, and rollback rehearsal are still blocked.

## Scope Reviewed

- Backend handoff: `ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-backend-handoff.md`
- QA task: `ai-agents/tasks/20260508-m10-migration-rehearsal-cutover-rollback-qa.md`
- Command/service:
  - `apps/platform-api/app/Console/Commands/PlatformMigrationRehearsalCommand.php`
  - `apps/platform-api/app/Shared/Migration/MigrationRehearsalReadinessService.php`
  - `apps/platform-api/bootstrap/app.php`
  - `apps/platform-api/config/platform.php`
  - `apps/platform-api/.env.example`
- Tests:
  - `apps/platform-api/tests/Feature/M10MigrationRehearsalCutoverRollbackTest.php`
  - `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- Helpers:
  - `scripts/platform-migration-rehearsal.sh`
  - `scripts/platform-cutover-preflight.sh`
  - `scripts/platform-rollback-drill.sh`
- Runbooks/docs:
  - `ops/m10/old-data-migration-strategy.md`
  - `ops/m10/migration-rehearsal-fixtures.md`
  - `ops/m10/migration-rehearsal-runbook.md`
  - `ops/m10/snapshot-requirements.md`
  - `ops/m10/cutover-runbook.md`
  - `ops/m10/rollback-drill-runbook.md`
  - `ops/m10/production-secret-boundary.md`
  - `ops/m10/runtime-readiness.md`
  - `docs/backend-console-commands.md`
  - `docs/m10-deployment-monitoring-load-test.md`

Artifacts: `ai-agents/reports/artifacts/20260508-m10-migration-rehearsal-cutover-rollback-qa/`

## Docker Runtime Policy

PASS. Runtime commands were executed through Docker only. Static host commands were limited to file inspection/report/artifact work.

Validated Docker commands included:

- `docker compose up -d postgres valkey platform-api`
- `docker compose run --rm platform-api composer install`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing`
- `docker compose run --rm platform-api php artisan test --filter=M10MigrationRehearsalCutoverRollbackTest`
- `docker compose run --rm platform-api php artisan test`
- `docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json`
- `docker compose exec platform-api php artisan platform:runtime:readiness --format=json`
- `docker compose exec platform-api php artisan platform:smoke`
- `docker compose run --rm platform-api php artisan migrate:status`
- `docker compose run --rm platform-api php artisan schedule:list`
- `docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default`
- `docker compose run --rm platform-api php artisan list`
- `docker compose exec platform-api php artisan route:list`

## Migration Rehearsal Command Review

PASS.

`platform:migration:rehearsal --dry-run --format=json` returns safe JSON with:

- `status=blocked_external`
- `production_approved=false`
- `boundary.local_dev_verifiable=true`
- `boundary.dry_run=true`
- `boundary.synthetic_seeded_data_only=true`
- `boundary.external_services_called=false`
- `boundary.long_lived_processes_started=false`
- `boundary.destructive_production_operations_attempted=false`
- `boundary.old_data_payloads_loaded=false`
- `boundary.staging_approved=false`
- `boundary.production_approved=false`
- `boundary.production_cutover_approved=false`
- `boundary.production_rollback_approved=false`

Section statuses matched the QA contract:

- `old_data_migration_strategy=ready_local`
- `rehearsal_fixtures=ready_local`
- `snapshot_requirements=blocked_external`
- `cutover=blocked_external`
- `rollback=blocked_external`
- `production_secret_boundary=blocked_external`
- `helpers=ready_local`

Expected blockers remain present for external gates, including real old-data source, real database snapshot, object-storage metadata snapshot, production secret management, staging rehearsal, and rollback rehearsal.

## Safe Output And Redaction

PASS.

QA ran a fake migration environment probe with sanitized fake values. Raw leak count was `0`. The JSON output exposed only safe placeholders:

- `source_dsn=[REDACTED]`
- `source_token=[REDACTED]`
- `object_storage_bucket=[CONFIGURED]`
- `secret_reference=[REDACTED]`
- `release_image_tag=[CONFIGURED]`
- `previous_image_tag=[CONFIGURED]`

The report and artifacts were scanned after sanitization; no fake migration values were present.

## Old-Data Migration Strategy

PASS.

The strategy document covers supported/unsupported old-data categories, tenant/partner identity requirements, explicit status mapping, reject-report behavior for unknown records, idempotency, payload hash conflicts, PII handling, and secret redaction. The readiness service validates the artifact and reports it as `ready_local`.

## Rehearsal Fixture And Data Boundary

PASS.

The fixture document and readiness output keep local rehearsal constrained to synthetic seeded data and feature-test fixtures. The readiness output confirms `real_old_data_dumps_committed=false`, `synthetic_seeded_data_only=true`, and no old-data payload loading.

## Snapshot Requirements

PASS WITH EXPECTED EXTERNAL BLOCKERS.

Snapshot requirements are documented for database and object-storage metadata. The readiness output correctly keeps this section `blocked_external` until real database snapshot, object-storage metadata snapshot, and restore rehearsal evidence are provided.

## Cutover Runbook

PASS WITH EXPECTED EXTERNAL BLOCKERS.

The runbook includes preflight, image/tag boundary, queue/maintenance decision points, dry-run migration boundary, health/smoke/runtime readiness, Cloudflare/CDN/R2 checkpoints, monitoring, abort criteria, and evidence capture. The readiness output correctly blocks production cutover until release image, approved cutover window, staging rehearsal, production Cloudflare/CDN/R2 evidence, and alert-channel verification are complete.

## Rollback Drill

PASS WITH EXPECTED EXTERNAL BLOCKERS.

The rollback runbook includes previous-image rollback, database compatibility boundary, feature flag off switch, queue pause/resume, tenant maintenance, object-storage rollback/repair, post-rollback checks, and Coordinator-owned residual repair review. The readiness output correctly blocks rollback until external verification is complete.

## Production Secret Boundary

PASS WITH EXPECTED EXTERNAL BLOCKERS.

The production-secret-boundary document keeps real credentials outside committed files and requires Coordinator/Ops-approved secret management. Readiness output redacts or config-masks all sensitive fields and blocks production migration until secret management and source credentials exist outside the repo.

## Helper Scripts

PASS.

The three helper scripts exist, are executable, and call runtime operations through `docker compose`. Static helper scan found no direct host PHP/Composer/Artisan/Node/npm/Vite/Nuxt/psql/pg_dump runtime invocation.

## Docs And Route/API Contract

PASS.

`docs/backend-console-commands.md` lists the new rehearsal command. `docs/m10-deployment-monitoring-load-test.md` documents M10 migration readiness. Route list was captured for no-drift evidence; no customer/back-office route or API contract change was introduced by this slice.

## Test Results

PASS.

- `M10MigrationRehearsalCutoverRollbackTest`: 3 passed / 110 assertions
- `M10DeploymentReadinessTest`: 5 passed / 94 assertions
- `M10HorizonReverbSchedulerHardeningTest`: 4 passed / 68 assertions
- `M10ProductionObservabilityAlertingTest`: 5 passed / 81 assertions
- `M10CloudflareHttpsWafCdnR2Test`: 5 passed / 136 assertions
- `ConsoleCommandStructureTest`: 3 passed / 84 assertions
- Full platform API suite: 138 passed / 3485 assertions

Runtime checks also passed:

- `platform:smoke`
- `platform:runtime:readiness --format=json`
- `platform:migration:rehearsal --dry-run --format=json`
- `migrate:status`
- `schedule:list`
- `queue:work --once`
- `artisan list`
- `route:list`

## Static Check Results

PASS.

- Expected migration/runbook/config markers found.
- No tenant logo/theme/payment/domain/feature work drift found in `.env.example`.
- Helper scripts stay Docker-only.
- Fake migration env values were sanitized from artifacts and absent from final scan.

## Customer/Back-Office No-Change Review

PASS.

This slice adds migration readiness, runbooks, docs, tests, and helper scripts. QA did not find customer-facing or back-office API behavior changes in the inspected scope.

## Release Gates Still Open

These are expected Coordinator/Ops gates, not QA defects:

- Real old-data source is not approved/configured.
- Real database snapshot is missing.
- Real object-storage metadata snapshot is missing.
- Restore rehearsal evidence is missing.
- Production secret management is missing.
- Migration source credentials are missing.
- Release image tag is not verified.
- Production cutover window is not approved.
- Staging rehearsal is not completed.
- Cloudflare/CDN/R2 production evidence is missing.
- Production monitoring alert channels are not verified.
- Previous image tag is missing in default local env.
- Production database backward compatibility is not verified.
- Object-storage rollback plan is not verified.
- Rollback rehearsal is not executed.

## Defects

None.

## Recommendation

Send to Coordinator. QA recommends accepting the local/dev M10 migration rehearsal/cutover/rollback planning implementation as PASS WITH RISKS, with all production and staging approvals kept closed until Coordinator/Ops supply external evidence and explicitly approve the next release gate.
