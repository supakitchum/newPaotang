# Customer content fixtures

This fixture provides 10 activities and 10 announcements with local cover images.
It defaults to databases whose effective name ends in `_test`.

Validate the content and image references without connecting to a database:

```sh
docker compose run --rm --no-deps \
  -e APP_ENV=testing \
  -e DB_DATABASE=newpaotang_test \
  platform-api \
  php artisan customer-content:seed-test --validate-only
```

Seed an existing test tenant and game:

```sh
docker compose run --rm --no-deps \
  -e APP_ENV=testing \
  -e DB_DATABASE=newpaotang_test \
  platform-api php artisan customer-content:seed-test \
  --tenant=<existing-test-tenant-code> \
  --game=<existing-test-game-code>
```

The command is idempotent for the same tenant. It updates only fixture-owned rows
and does not delete unrelated content. Before writing, it verifies that both
fixture groups contain exactly 10 unique slugs and that every referenced cover
image exists locally. When `--game` is omitted, the current open game is used;
if no game is open, the latest existing game is used as a fallback.

Runtime insertion is blocked unless an operator explicitly authorizes that exact
database action. After verifying the effective database from inside the API
container, runtime execution additionally requires both `--allow-runtime` and an
exact `--confirm-database=<effective-name>` value. These flags do not perform a
fresh, wipe, reset, delete, or broad reseed.
