# M10 Runtime Readiness Notes

The local M10 runtime keeps one shared `platform-api` codebase and exposes separate Docker Compose runtime roles:

```text
platform-api: API HTTP runtime
platform-api-worker: queue worker profile
platform-api-scheduler: scheduler loop profile
platform-api-smoke: one-shot smoke profile
postgres: PostgreSQL
valkey: Redis-compatible cache/queue/lock
```

Use Docker Compose only for every application command. The helper scripts in `scripts/` call Docker Compose and do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, migrations, queue workers, or scheduler commands on the host machine.

Runtime hardening verifier:

```sh
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
```

Queue/Horizon/Reverb/scheduler artifacts:

```text
ops/m10/queue-worker-profiles.json
ops/m10/horizon-queue-supervision.md
ops/m10/reverb-deployment-readiness.md
ops/m10/scheduler-workload-runbook.md
ops/m10/runtime-hardening-readiness.md
```

Migration rehearsal/cutover/rollback verifier:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

Migration artifacts:

```text
ops/m10/old-data-migration-strategy.md
ops/m10/migration-rehearsal-runbook.md
ops/m10/migration-rehearsal-fixtures.md
ops/m10/cutover-runbook.md
ops/m10/rollback-drill-runbook.md
ops/m10/snapshot-requirements.md
ops/m10/production-secret-boundary.md
```
