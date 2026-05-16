# Modal Layer And Runtime Async Migration Hotfix Coordinator Handoff

## Agent

Coordinator

## Task

Apply immediate hotfix for:

```text
BO modal hidden/overlapped by navbar
runtime DB missing stock_generation_batches.total_rounds
```

## What Was Done

- Ran pending async stock generation migration on runtime DB with non-destructive `php artisan migrate`.
- Confirmed migration is now `Ran`.
- Updated `AdminModal` to use Vue `Teleport` to `body`.
- Added explicit modal/backdrop z-index above admin header/sidebar.
- Added viewport max-height constraints for long scrollable modal content.

## Files Changed

```text
apps/back-office/components/AdminModal.vue
apps/back-office/assets/css/admin-foundation.css
ai-agents/decisions/20260516-modal-layer-runtime-migration-hotfix-decision.md
ai-agents/handoffs/20260516-modal-layer-runtime-migration-hotfix-coordinator-handoff.md
ai-agents/BOARD.md
```

## Runtime Command Applied

```sh
docker compose -p newpaotang run --rm platform-api php artisan migrate --no-interaction --force
```

## Validation

```text
git diff --check: PASS
runtime migration status: async stock migration Ran
BO lint: PASS
BO build: PASS
protected route smoke: /admin/central/stock-generation redirects to login without SSR/server crash
```

## Next Agent

Coordinator

