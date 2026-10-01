# M10 Reverb Deployment Readiness

## Boundary

This artifact is local/dev readiness only. It is not approval for public websocket delivery, TLS termination, Reverb scaling, or client-delivery realtime behavior.

## Local Auth Evidence

The existing API keeps admin realtime auth endpoints:

```text
POST /api/v1/admin/central/realtime/auth
POST /api/v1/admin/tenant/realtime/auth
```

They remain permissioned through the current admin auth and tenant-scope middleware. The readiness command reports endpoint presence without exposing `REVERB_APP_KEY`, `REVERB_APP_SECRET`, hostnames, or production URLs.

Stock generation realtime progress adds central-admin-only private channels:

```text
private-admin.central.stock-generation
private-admin.central.stock-generation.game.{game_id}
private-admin.central.stock-generation.batch.{batch_id}
```

These channels are authorized through `POST /api/v1/admin/central/realtime/auth` only and require authenticated central scope plus `stock.generate`. Tenant-scope admins are rejected for these channels.

The backend event contract is `stock.generation.progress.updated`.

2026-05-16 hotfix update:

```text
Laravel Reverb package is installed.
Docker local/dev profile `realtime` provides `platform-api-reverb`.
Back-office local/dev config points to `http://localhost:8080`.
Stock generation progress was proven over a private central admin Reverb channel in local Docker.
```

This remains local/dev readiness only. Public websocket delivery, TLS termination, scaling/load evidence, and production secret ownership are still not approved.

Run the local verifier through Docker:

```sh
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
```

## Current Blockers

```text
reverb_tls_and_public_host_not_verified
reverb_scaling_and_load_not_verified
```

## Safe Env Boundary

`.env.example` may include infrastructure-level placeholders:

```text
REVERB_APP_ID
REVERB_APP_KEY
REVERB_APP_SECRET
REVERB_HOST
REVERB_PORT
REVERB_SCHEME
```

Readiness output must use booleans or `[CONFIGURED]` / `[REDACTED]`, never raw keys, secrets, hosts, or URLs.

## Production Evidence Required

```text
Production Reverb public host/TLS approved
Production Reverb scaling/load evidence approved
TLS and public websocket host verified
admin/customer channel auth contract load-tested
horizontal scaling and Redis/Valkey pub-sub behavior verified
secrets managed outside committed files
```
