# M10 Migration Rehearsal Runbook

## Boundary

This runbook is for local/dev rehearsal readiness. It does not approve staging, production, old-data import, production cutover, or production rollback.

## Local Dry Run

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
docker compose run --rm platform-api php artisan migrate:status
docker compose exec platform-api php artisan platform:smoke
```

`migrate:fresh --seed` is destructive and allowed only for local/test rehearsal.

## Rehearsal Steps

```text
confirm Docker runtime is healthy
rebuild local/testing database from seeders
run migration rehearsal dry-run report
review fixture boundary and reject-report policy
review database and object-storage snapshot blockers
review cutover and rollback blockers
run smoke and runtime readiness checks
capture command output as QA artifact
```

## Must Not Do

```text
do not connect to real old-data sources
do not run psql, pg_dump, PHP, Artisan, k6, or cloud CLIs on host
do not run destructive production migrations
do not import raw old-data payloads into the repository
do not claim staging or production approval
```

## QA Evidence Boundary

The acceptable local evidence is command output, test results, Docker command logs, and runbook review. Real old-data source, snapshots, secret management, staging rehearsal, production cutover, and rollback execution remain blockers.
