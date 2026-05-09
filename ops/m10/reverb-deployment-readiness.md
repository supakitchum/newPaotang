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

Run the local verifier through Docker:

```sh
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
```

## Current Blockers

```text
reverb_package_missing
reverb_runtime_profile_not_configured
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
Laravel Reverb package/runtime approved
Reverb process/profile or orchestration config added
TLS and public websocket host verified
admin/customer channel auth contract load-tested
horizontal scaling and Redis/Valkey pub-sub behavior verified
secrets managed outside committed files
```
