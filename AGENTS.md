# Agent Safety Rules

## Runtime Database Is Protected

Do not run destructive database commands against the shared runtime database unless the user explicitly asks for that exact runtime DB action in the current turn.

Protected runtime database:

```text
newpaotang
```

Allowed test database:

```text
newpaotang_test
```

Before running any Artisan command that can drop, reset, wipe, reseed large data, generate stock, recall allocation, or rewrite production-like records, verify the effective database from inside the container. Do not trust `--env=testing` by itself because Docker environment variables can override `.env.testing`.

Safe test command pattern:

```sh
docker compose run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

Never use this pattern for destructive commands because it can inherit runtime DB env:

```sh
docker compose exec platform-api php artisan migrate:fresh --env=testing
```

Laravel also has an Artisan guard that blocks destructive commands such as `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe`, `schema:load`, and `runtime:mock-data:seed` unless the effective database name ends with `_test`.
