# Platform API Console Layer

Production workflow commands are first-class Laravel command classes under:

```text
apps/platform-api/app/Console/Commands/**
```

They are registered in `apps/platform-api/bootstrap/app.php` through `withCommands([...])`.

M10 runtime readiness uses `platform:smoke` as the Docker-safe smoke command for app, database, cache, queue, seeded-login, and monitoring-default checks.

M10 Cloudflare/CDN readiness uses `platform:cloudflare:readiness --format=json` as a Docker-safe local/dev verifier. It emits blockers and keeps `production_approved=false`; it does not call or mutate Cloudflare/R2.

M10 migration rehearsal readiness uses `platform:migration:rehearsal --dry-run --format=json` as a Docker-safe local/dev verifier. It reports migration, cutover, rollback, snapshot, and secret-management blockers while keeping `production_approved=false`.

The active controller convention remains module-based. Controllers live with their owning domain module:

```text
apps/platform-api/app/Modules/<Domain>/Http/Controllers/**
```

Do not create a duplicate root `apps/platform-api/app/Http/Controllers` layer for this modular monolith.
