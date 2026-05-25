# Dev Backend Memory

Memory is cache, not source of truth. Trust current task, docs, tests, and `apps/platform-api/**` over this file.

## Stable Context

- Backend ownership is `apps/platform-api/**`.
- Backend changes that touch schema/data contracts require test env validation before QA and GitOps runtime migration after approval.
- Backend work requires a trigger file and worktree start gate before edits.

## Common Commands

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --env=testing
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan migrate:fresh --seed --env=testing --no-interaction
```

## Known Patterns

- API contract source of truth is `docs/openapi.yaml` when task explicitly requires contract updates.
- Authorization and tenant isolation must be enforced in backend, not only through frontend visibility.
- `VirtualStockService` uses an opaque base64 cursor shaped like `{number_offset, copy_offset}` for copy-aware virtual stock pagination; numeric cursors are legacy number offsets.

## Gotchas

- Never wipe/reset local runtime DB `newpaotang`.
- Do not edit `apps/back-office/**` or `apps/customer/**` unless Coordinator explicitly approves cross-role work.
- In AUTO Mode, runner owns trigger status; backend writes requested final status in handoff.

## Last Useful Findings

- GitOps owns local runtime DB migrate after Coordinator approval; backend dev only validates on test env/test DB.
- Exact-six public virtual stock search must paginate duplicate copies by `copy_offset` so one `full_number` with many copies does not repeat ids across pages.

## Do Not Trust Without Rechecking

- Current migration status.
- Existing test fixture names.
- Current route/controller/service organization.
