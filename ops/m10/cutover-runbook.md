# M10 Cutover Runbook

## Boundary

This is an operator checklist template. It is not approval for a real cutover. Production cutover remains blocked until Coordinator/Ops approve infrastructure, secrets, snapshots, staging rehearsal, release images, and communications.

Local/dev verifier:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
scripts/platform-cutover-preflight.sh
```

## Preflight Checklist

```text
approved release tag and image digest recorded
previous image tag recorded for rollback
database snapshot completed and restore-tested
object-storage metadata snapshot completed
production secret references available in approved secret manager
staging rehearsal completed with reject report reviewed
Cloudflare DNS, HTTPS, cache-bypass, CDN/R2 evidence reviewed
monitoring and alert channels verified
tenant maintenance and communication plan approved
```

## Freeze / Drain Decisions

```text
decide whether customer write traffic requires tenant maintenance
decide whether queue workers pause or drain by queue profile
confirm scheduler workloads are safe or paused
capture queue lag before migration
capture outbox/inbox backlog before migration
```

## Migration And Verification

```text
run dry-run report first
run production-safe migrations only after approval
run health endpoints
run platform smoke with production-safe seed-login behavior
run runtime readiness report
verify Cloudflare/CDN/R2 checkpoints
monitor API errors, DB health, queue lag, sync lag, and reward/checkout signals
```

## Abort Criteria

```text
snapshot missing or restore untested
release image tag missing
old-data reject rate exceeds approved threshold
tenant identity mapping is ambiguous
queue lag or DB lock wait exceeds approved threshold
health/smoke/readiness fails
Cloudflare/CDN/R2 production evidence missing
secrets are not available through approved manager
```

## Evidence Capture

Capture timestamps, command output, release image tags, snapshot ids, reject counts, smoke results, readiness JSON, queue lag, alert channel state, and Coordinator approval references. Do not capture raw secrets or old-data payloads.
