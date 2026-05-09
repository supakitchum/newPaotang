# 20260508-m10-migration-rehearsal-cutover-rollback - Backend Develop Handoff

## Task

20260508-m10-migration-rehearsal-cutover-rollback

## What Was Done

- Added a Docker-runnable local/dev migration rehearsal readiness command:
  `php artisan platform:migration:rehearsal --dry-run --format=json`.
- Added a safe readiness service that emits machine-readable migration, fixture, snapshot, cutover, rollback, secret-boundary, helper-script, blocker, and validation-command status.
- Added Docker-only helper scripts for migration rehearsal, cutover preflight, and rollback drill.
- Added M10 ops artifacts for old-data migration strategy, rehearsal fixtures, snapshot requirements, cutover, rollback drill, and production secret boundary.
- Updated backend/M10 docs to list the new command, scripts, artifacts, local/dev boundary, and remaining staging/production blockers.
- Added regression tests that lock command registration, safe JSON output, `production_approved=false`, redaction, fixture boundaries, runbook artifacts, snapshot requirements, secret placeholders, and Docker-only helper script behavior.
- Did not edit `apps/customer/**`, `apps/back-office/**`, `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, or `document/**`.

## Backend Files Changed

- `apps/platform-api/app/Console/Commands/PlatformMigrationRehearsalCommand.php`
- `apps/platform-api/app/Shared/Migration/MigrationRehearsalReadinessService.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/.env.example`
- `apps/platform-api/app/Console/README.md`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- `apps/platform-api/tests/Feature/M10MigrationRehearsalCutoverRollbackTest.php`

## Ops, Script, And Doc Files Changed

- `scripts/platform-migration-rehearsal.sh`
- `scripts/platform-cutover-preflight.sh`
- `scripts/platform-rollback-drill.sh`
- `ops/m10/old-data-migration-strategy.md`
- `ops/m10/migration-rehearsal-fixtures.md`
- `ops/m10/migration-rehearsal-runbook.md`
- `ops/m10/cutover-runbook.md`
- `ops/m10/rollback-drill-runbook.md`
- `ops/m10/snapshot-requirements.md`
- `ops/m10/production-secret-boundary.md`
- `ops/m10/runtime-readiness.md`
- `docs/backend-console-commands.md`
- `docs/m10-deployment-monitoring-load-test.md`

## API Endpoints Implemented

None. This slice adds backend console/readiness and ops artifacts only.

No HTTP route, public API path, method, response envelope, permission scope, tenant resolution behavior, customer flow, back-office flow, or source-of-truth API contract was changed.

## Permissions/Tenant Checks Enforced

- No new HTTP endpoint or tenant-scoped mutation path was introduced.
- The rehearsal command is local/dev readiness only and does not read, import, export, mutate, truncate, or connect to real old-data sources.
- The readiness output reports only categories, booleans, blockers, and redacted/configured placeholders.
- Existing tenant isolation, auth, RBAC, audit, wallet, payment, reward, order, stock, queue, outbox/inbox, and realtime backend behavior remains covered by the full platform-api regression suite.

## Old-Data Migration Strategy Summary

Artifact: `ops/m10/old-data-migration-strategy.md`

- Supported categories are documented for partners/tenants, domains/branding, admin users/roles/menus, customers, wallet/ledger reconciliation inputs, games/stock, orders/tickets/payments/topups, rewards/claims/agents/affiliates/reports.
- Unsupported categories are explicit: raw passwords/password hash reuse, unversioned event payloads, base64 ticket images, production payment provider secrets, unmapped legacy statuses, and records without tenant/partner identity.
- Mapping requires tenant identity, current platform tables/modules as targets, explicit status mapping, and reject reports for unknown records.
- Idempotency requires stable legacy source keys, replay into the same target record, payload-hash conflict rejection, and preserved outbox/inbox event ids or idempotency keys.
- Local/dev dry-run output is count/category oriented and must not emit customer PII, raw old-data payloads, production URLs, signed URLs, or secrets.

## Rehearsal Fixture/Data Boundary

Artifact: `ops/m10/migration-rehearsal-fixtures.md`

- Local/dev rehearsal uses synthetic and seeded data only.
- Checked seeders are `DatabaseSeeder`, `DefaultRbacMenuSeeder`, `BootstrapAdminSeeder`, and `DemoTenantSeeder`.
- Real old-data dumps, customer exports, production database snapshots, object-storage manifests, bearer tokens, signed URLs, and PII must not be committed.
- Real old-data source access remains blocked until Coordinator/Ops provide verified infrastructure and approved secret management.

## Migration Rehearsal Command/Report Summary

Command:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

Report behavior:

- Emits JSON with `status=blocked_external` and `production_approved=false`.
- Marks local/dev strategy, fixtures, and helper scripts as ready.
- Marks snapshot requirements, cutover, rollback, and production secret boundary as externally blocked.
- Includes blockers for missing real database snapshot, object-storage metadata snapshot, restore rehearsal evidence, real old-data source, production secret management, staging rehearsal, production cutover, and rollback execution.
- Redacts configured sensitive values as `[REDACTED]` and non-sensitive configured release/source fields as `[CONFIGURED]`.
- Does not call external services, start long-lived workers/schedulers, or attempt destructive production operations.

## Cutover Runbook Summary

Artifact: `ops/m10/cutover-runbook.md`

Covered checkpoints:

- preflight
- release tag/image boundary
- previous image tag recorded for rollback
- database snapshot and restore-test requirement
- object-storage metadata snapshot requirement
- queue pause/drain decision
- tenant maintenance decision
- dry-run before production-safe migration
- health/smoke/runtime readiness checks
- Cloudflare/CDN/R2 verification
- monitoring and alert checks
- abort criteria
- communications and evidence capture

Production cutover remains blocked until Coordinator/Ops approve infrastructure, secrets, snapshots, staging rehearsal, release images, and communications.

## Rollback Drill Runbook Summary

Artifact: `ops/m10/rollback-drill-runbook.md`

Covered boundaries:

- previous image tag requirement
- database backward-compatibility boundary
- feature flag/off-switch boundary
- queue pause/resume boundary
- tenant maintenance boundary
- object-storage rollback or repair boundary
- post-rollback health/smoke/readiness checks
- residual repair tasks for Coordinator review

No destructive down-migration or irreversible schema rollback claim was added.

## Database/Object-Storage Snapshot Requirements

Artifact: `ops/m10/snapshot-requirements.md`

- Database snapshot scope covers PostgreSQL schema, tenant data, ledger/order/reward/report state, outbox/inbox, audit, and monitoring state.
- Object-storage metadata snapshot scope covers ticket image keys, variants, CDN policy metadata, bucket prefixes, and ownership maps.
- Raw object binaries, signed URLs, and production credentials must not be committed.
- Restore rehearsal evidence is required before production approval.

## Production Secret-Management Boundary

Artifact: `ops/m10/production-secret-boundary.md`

- Added placeholder-only environment keys in `apps/platform-api/.env.example`.
- Production values must come from a Coordinator/Ops-approved secret manager outside committed files.
- Readiness output may only use booleans, `[CONFIGURED]`, `[REDACTED]`, or `null`.
- Raw database URLs, access tokens, object-storage credentials, signed URLs, private keys, DSNs, customer data, old-data payloads, and production hostnames must not be printed.

## Docker Validation

Required setup:

- `docker compose config --quiet` - passed
- `docker compose --profile worker --profile scheduler config --quiet` - passed
- `docker compose up -d postgres valkey platform-api` - passed
- `docker compose run --rm platform-api composer install` - passed
- `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing` - passed

Required Backend regression:

- `docker compose run --rm platform-api php artisan test --filter=M10MigrationRehearsalCutoverRollbackTest` - passed, 3 tests, 110 assertions
- `docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest` - passed, 5 tests, 94 assertions
- `docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest` - passed, 4 tests, 68 assertions
- `docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest` - passed, 5 tests, 81 assertions
- `docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test` - passed, 5 tests, 136 assertions
- `docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest` - passed, 3 tests, 84 assertions
- `docker compose run --rm platform-api php artisan test` - passed, 138 tests, 3485 assertions

Required runtime commands:

- `docker compose exec -T platform-api php artisan route:list` - passed, 199 routes
- `docker compose exec -T platform-api php artisan platform:smoke` - passed, app/database/cache/monitoring-defaults/seeded-logins ok
- `docker compose exec -T platform-api php artisan platform:runtime:readiness --format=json` - passed, status `blocked_external` for Horizon/Reverb external blockers
- `docker compose exec -T platform-api php artisan platform:migration:rehearsal --dry-run --format=json` - passed, status `blocked_external`, `production_approved=false`
- `docker compose run --rm platform-api php artisan migrate:status` - passed, all listed migrations ran
- `docker compose run --rm platform-api php artisan schedule:list` - passed, expected five scheduled workloads listed
- `docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default` - passed, exit code 0
- `docker compose run --rm platform-api php artisan list` - passed, includes `platform:migration:rehearsal`

Required static/helper validation:

- `git status --short` - ran; workspace is very dirty with many unrelated pre-existing modified/untracked files outside this task scope
- `sh -n scripts/platform-migration-rehearsal.sh` - passed
- `sh -n scripts/platform-cutover-preflight.sh` - passed
- `sh -n scripts/platform-rollback-drill.sh` - passed
- `rg -n "platform:migration:rehearsal|migration rehearsal|cutover|rollback|snapshot|production_approved|dry-run" apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts` - passed, expected matches found
- `rg -n "password|secret|token|private_key|BEGIN PRIVATE KEY|Bearer |signed URL|signed_url|DATABASE_URL|R2_SECRET|CLOUDFLARE_API_TOKEN" apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts` - ran; matches are expected placeholders, redaction rules, existing tests/fixtures, config keys, and safe code paths. No `BEGIN PRIVATE KEY` or committed `Bearer ` literal was introduced by this slice.

## Remaining Staging/Production Blockers

- Real old-data source is not provided.
- Production secret management is not approved or wired.
- Real database snapshot is missing.
- Real object-storage metadata snapshot is missing.
- Restore rehearsal evidence is missing.
- Staging rehearsal is not completed.
- Release image tag and previous image tag are not verified.
- Cloudflare/CDN/R2 production evidence remains external.
- Production monitoring alert channels are not verified.
- Production cutover window is not approved.
- Production rollback drill has not been executed.
- Database backward compatibility and object-storage rollback/repair plan are not verified for production.

## Known Risks/Questions

- The command intentionally reports `blocked_external`; this is expected for local/dev until Coordinator/Ops provide real infrastructure evidence.
- Helper scripts are bounded Docker wrappers, but they are not production execution tooling.
- The workspace has many unrelated dirty/untracked files from other agents/tasks; this slice did not attempt to revert or normalize them.
- Production migration execution still needs a separate approved implementation once source data, snapshots, secrets, image tags, and staging evidence exist.

## Next Agent

Orchestrator
