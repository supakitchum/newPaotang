# M10 Rollback Drill Runbook

## Boundary

This is a local/dev rollback drill boundary. It is not approval for destructive down migrations or production rollback execution.

Local/dev verifier:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
scripts/platform-rollback-drill.sh
```

## Required Inputs

```text
previous image tag and digest
current release image tag and digest
database backward-compatibility note
feature flag/off-switch list
queue pause/resume plan
tenant maintenance plan
object-storage metadata snapshot and repair plan
post-rollback smoke/readiness checklist
```

## Drill Steps

```text
record current and previous image tags
pause or drain queues if data compatibility is uncertain
enable tenant maintenance for affected tenants only when needed
switch risky features off through database-backed flags
roll API, worker, scheduler, customer, and back-office images together when required
avoid destructive down migrations unless a Coordinator-approved repair plan exists
run health endpoints, platform smoke, runtime readiness, and migration rehearsal report
record residual data repair tasks for Coordinator review
```

## Data Compatibility Boundary

Rollback assumes additive/backward-compatible migrations. Irreversible schema changes, old-data imports, ledger corrections, object-storage deletes, and ticket-image key rewrites require a separate repair plan and Coordinator approval.

## Blockers Before Production

```text
previous image tag missing
database backward compatibility not verified
object-storage rollback or repair plan not verified
rollback rehearsal not executed in staging
post-rollback smoke/readiness evidence missing
```
