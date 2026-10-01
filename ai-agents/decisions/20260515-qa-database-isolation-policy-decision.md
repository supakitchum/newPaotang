# Decision: QA Database Isolation Policy

Date: 2026-05-15

Decision: QA MUST USE ISOLATED TEST DATABASE FOR DESTRUCTIVE TESTING

## Context

User reported that QA runs delete local/runtime data after each QA test cycle.

Current source inspection shows:

- `apps/platform-api/phpunit.xml` already points PHPUnit to `DB_DATABASE=newpaotang_test`.
- Several QA/handoff command examples still use `migrate:fresh --seed` without forcing `APP_ENV=testing` and `DB_DATABASE=newpaotang_test`.
- Runtime service `platform-api` uses the main local database `newpaotang` from `compose.yaml`.

## Policy

The main local/runtime database `newpaotang` is not a disposable QA database.

QA and all agents are forbidden from running destructive database commands against `newpaotang` unless the user explicitly asks to wipe the runtime database in the current conversation turn.

Destructive commands include:

```text
migrate:fresh
migrate:refresh
migrate:reset
db:wipe
bulk truncate/drop/reset commands
```

Backend feature/PHPUnit QA must use:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
```

Required command pattern:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

Runtime restore/login smoke must be non-destructive against `newpaotang`:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
```

## QA Reporting Requirement

Every QA report that runs destructive DB commands must record the database name and command evidence.

Coordinator must reject a clean PASS if:

- destructive commands do not show `APP_ENV=testing` and `DB_DATABASE=newpaotang_test`
- QA uses `migrate:fresh --seed` against the runtime DB
- runtime login smoke is skipped after DB/build/browser testing

## Files Updated

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
docs/coordinator-agent-handoff.md
```

## Next Agent

Orchestrator

