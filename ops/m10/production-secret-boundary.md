# M10 Production Secret Boundary

## Boundary

Migration, cutover, rollback, database snapshots, and object-storage snapshots require production secrets that must never be committed to this repository.

Local/dev verifier:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

## Placeholder Names

Committed files may reference placeholder names only:

```text
MIGRATION_REHEARSAL_SOURCE_TYPE
MIGRATION_REHEARSAL_SOURCE_DSN
MIGRATION_REHEARSAL_SOURCE_TOKEN
MIGRATION_REHEARSAL_OBJECT_STORAGE_BUCKET
MIGRATION_REHEARSAL_SECRET_REFERENCE
PLATFORM_RELEASE_IMAGE_TAG
PLATFORM_PREVIOUS_IMAGE_TAG
```

Readiness output must use booleans, `[CONFIGURED]`, `[REDACTED]`, or `null`. It must not print raw database URLs, access tokens, object-storage credentials, signed URLs, private keys, DSNs, customer data, old-data payloads, or production hostnames.

## Required External Owner

Production values must come from a Coordinator/Ops-approved secret manager outside committed files. The handoff or QA report may name the external owner/system, but not the values.

## Blockers

```text
production secret management missing
migration source credentials missing
real old-data source missing
snapshot access credentials missing
object-storage credentials missing
```
