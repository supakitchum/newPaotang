# M10 Scheduler Workload Runbook

## Boundary

This runbook covers local/dev scheduler readiness only. It does not approve production scheduler SLOs, process supervision, or long-running scheduler loops.

## Local Evidence Commands

```sh
docker compose run --rm platform-api php artisan schedule:list
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
```

The Docker Compose `platform-api-scheduler` profile remains available for local/dev loops, but validation must use bounded commands unless Coordinator explicitly asks to start the profile.

## Registered Local/Dev Workloads

```text
stock:reservations:expire --limit=100
stock:sold:sync --limit=100
reward:check --chunk=100
commission:calculate --limit=100
platform:alerts:check --dry-run --format=json
```

## Safety Policy

```text
registered commands must be idempotent, chunk-limited, or non-mutating dry runs
workloads use withoutOverlapping
schedule:list is the QA evidence source for registration
unsafe or production-only jobs must be blockers instead of scheduled blindly
```

## Production Evidence Required

```text
process manager or orchestrator runs a single scheduler leader
overlap locks are backed by production Redis/Valkey
runtime logs and alerting verify missed/failed schedules
maintenance windows and deploy drain behavior are rehearsed
```
