# Decision: Modal Layer And Runtime Async Migration Hotfix

Date: 2026-05-16

Decision: HOTFIX APPLIED DIRECTLY BY COORDINATOR

## User Request

Hotfix:

```text
Navbar ทับ modal ทำให้ modal ที่ยาวๆเห็นไม่เต็ม
SQLSTATE[42703]: Undefined column: 7 ERROR: column "total_rounds" of relation "stock_generation_batches" does not exist
```

## Runtime Database Finding

Coordinator verified the async stock generation migration existed in code but was still pending in the runtime database:

```text
2026_05_16_000001_add_async_stock_generation_batches ............... Pending
```

Coordinator ran a non-destructive runtime migration:

```sh
docker compose -p newpaotang run --rm platform-api php artisan migrate --no-interaction --force
```

After migration:

```text
2026_05_16_000001_add_async_stock_generation_batches ............... [2] Ran
```

This resolves the missing `total_rounds` column in runtime DB `newpaotang`.

## BO Modal Fix

Coordinator updated the shared Back Office modal to avoid fixed navbar/sidebar stacking over long modal content:

```text
AdminModal now teleports modal/backdrop to body
custom modal/backdrop z-index is higher than admin header/sidebar
modal dialog/content has viewport max-height so long modals scroll inside the viewport
```

Changed files:

```text
apps/back-office/components/AdminModal.vue
apps/back-office/assets/css/admin-foundation.css
```

## Validation

Commands run:

```sh
git diff --check
docker compose -p newpaotang run --rm platform-api php artisan migrate:status --no-interaction
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang up -d back-office
curl --max-time 10 -i -s http://localhost:3100/admin/central/stock-generation
```

Results:

```text
migration status: async stock generation migration is Ran
back-office lint: PASS
back-office build: PASS
route smoke: HTTP 302 to /login?redirect=/admin/central/stock-generation
```

## Follow-up

No Orchestrator routing is required for this narrow hotfix.

If QA rechecks UI, focus on:

```text
long AdminModal content is above navbar/sidebar
modal body scrolls within viewport
stock generation pages no longer error on total_rounds
```

Next Agent: Coordinator

