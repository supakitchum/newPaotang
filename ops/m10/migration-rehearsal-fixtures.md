# M10 Migration Rehearsal Fixtures

## Boundary

Local/dev rehearsal uses synthetic and seeded data only. Do not commit old-data dumps, customer exports, production database snapshots, object-storage manifests, bearer tokens, signed URLs, or PII.

Docker verifier:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

## Allowed Fixture Sources

```text
apps/platform-api/database/seeders/DatabaseSeeder.php
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
apps/platform-api/database/seeders/BootstrapAdminSeeder.php
apps/platform-api/database/seeders/DemoTenantSeeder.php
feature test fixtures under apps/platform-api/tests/Support
synthetic rows created inside tests
```

## Rehearsal Data Boundary

```text
partner ids use demo/synthetic prefixes only
tenant hosts use .test domains only
admin/customer credentials are local QA seed credentials only
ticket image paths are placeholders or generated local fixtures only
no production hostnames or real object keys
no raw customer phone, national id, bank account, or payment credential dumps
```

## Evidence Expected

The local/dev readiness command may report:

```text
seeders present or missing
fixture categories covered
synthetic_seeded_data_only=true
real_old_data_dumps_committed=false
production_approved=false
```

It must not emit row-level payloads.
