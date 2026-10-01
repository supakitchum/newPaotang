# retire-physical-stock-flow-bo Handoff

## Agent

BO Develop

## Task

`retire-physical-stock-flow-bo`

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
start HEAD: b70d70d6ec81ba7e9ed0b3adb615f8341cc4cba9
origin/develop at start: b70d70d6ec81ba7e9ed0b3adb615f8341cc4cba9
implementation commit: 3d46de9e5f656dcc8e480dc338302219315ea783
git status after implementation commit: ## develop...origin/develop [ahead 1]
```

## What Was Done

- Retired active BO Partner Quotas workflow from navigation and active operation catalog.
- Replaced the stale `/admin/central/partner-quotas` catalog entry with retired guidance only; create/update quota forms and actions are no longer present.
- Added explicit `retired_flow`/HTTP 410 handling so retired backend responses show a workflow-retired warning instead of a generic crash.
- Preserved the virtual allocation workflow: allocation create remains `allocation_percent` based, with partner/tenant/game option sources and no `requested_count` in the BO operation catalog.
- Preserved virtual-only stock generation: Generate stock remains `virtual_profile` only and strips retired physical fields before submit.
- Kept allocation row routes scoped to virtual stock views with `game_id`, `partner_id`, `tenant_id`, `allocation_id`, and status.
- Updated BO structural guardrails and the active-BO OpenAPI snapshot so Partner Quotas write paths are not required as active BO coverage.
- Updated BO CRUD coverage wording for the retired Partner Quotas row.

## Files Changed

```text
apps/back-office/components/AdminApiState.vue
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check-stock-summary-widgets.mjs
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
```

## Backend Routes / Contracts Consumed

```text
POST /api/v1/admin/central/allocations rejects requested_count and accepts allocation_percent.
POST /api/v1/admin/central/stock/generate accepts generation_mode=virtual_profile only.
GET /api/v1/admin/central/partner-quotas remains legacy read-only.
POST /api/v1/admin/central/partner-quotas returns 410 retired_flow.
PATCH /api/v1/admin/central/partner-quotas/{quotaId} returns 410 retired_flow.
stock_partner_distributions is the active virtual partner distribution source of truth.
```

## Partner Quotas Retirement Behavior

- `central:partner_quotas` was removed from BO route overrides and filtered out of active central navigation even if the backend menu still sends it.
- The operation catalog no longer has Partner Quotas create/update actions or form fields.
- A stale deep link to `/admin/central/partner-quotas` resolves to a retired guidance state that points admins to Partners stock percent and Central Stock Allocations.
- 410 `retired_flow` API errors render as warning alerts with retired-workflow copy.

## Allocation / Stock Evidence

- Allocation create form fields remain partner select, tenant select, game select, and `allocation_percent`; no `requested_count` exists in `useAdminOperationsCatalog.ts`.
- Allocation actions still include stock coverage, remaining stock, recall-all, and redistribute.
- Remaining stock route remains scoped through:

```text
/admin/central/stock-generation?game_id={game_id}&partner_id={partner_id}&tenant_id={tenant_id}&allocation_id={id}&status=allocated
```

- Stock generation normalizer still forces `generation_mode: virtual_profile` and strips `seed`, `total_count`, `back2_count_per_number`, `back3_count_per_number`, `front3_count_per_number`, `start_number`, `count`, `number_digits`, `central_limits`, and `partner_limits`.

## Validation

```text
git diff --check
PASS

docker compose -p newpaotang build back-office
PASS

docker compose -p newpaotang run --rm back-office npm run lint
PASS

docker compose -p newpaotang run --rm back-office npm run test
PASS

docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
PASS

docker compose -p newpaotang run --rm back-office npm run build
PASS
Note: Nuxt emitted the existing Node DEP0180 deprecation warning but exited 0.

docker compose -p newpaotang up -d --force-recreate back-office
PASS

curl --max-time 10 -i -s http://localhost:3100/login
PASS: HTTP 200 after Nuxt warmup.

curl --max-time 10 -i -s http://localhost:3100/admin/central/partner-quotas
PASS: unauthenticated protected route redirects to /login?redirect=/admin/central/partner-quotas.

curl --max-time 10 -i -s http://localhost:3100/admin/central/allocations
PASS: unauthenticated protected route redirects to /login?redirect=/admin/central/allocations.
```

Initial HTTP smoke immediately after container recreate returned Nuxt `Starting Nuxt...` 503 during warmup; after Vite/Nitro warmup logs completed, retries passed.

## Known Risks

- Authenticated browser workflow was not executed in this BO handoff; QA should verify active navigation no longer shows Partner Quotas after login and stale deep link shows the retired guidance state.
- `docs/back-office-menu-completion.md` still contains historical Partner Quotas completion wording. This task ownership only allowed BO app files, `docs/back-office-crud-coverage.md`, and this handoff, so it was left untouched.
- Git continues to emit the existing non-blocking `.git/gc.log`/unreachable loose object housekeeping warning during commit operations.

## Questions For Coordinator

None.

## Unrelated Dirty Files

None observed before writing this handoff.

## Next Agent

Orchestrator
