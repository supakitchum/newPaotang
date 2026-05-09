# QA Report: 20260507-back-office-operations-page-slice-1

## Verdict

FAIL

## Summary

Back-office Docker validation passes for build, lint, test, and basic protected-route smoke checks, but the implementation does not satisfy the approved OpenAPI contract for the tenant growth operations pages. The operations catalog wires multiple tenant growth screens/actions to `/admin/tenant/growth/...` API paths while `docs/openapi.yaml` documents the same resources under `/admin/tenant/...` without the `growth` segment.

Because these are user-facing operations pages and actions, this is a blocking API contract mismatch.

## Blocking Findings

### P1: Tenant growth pages call undocumented API paths

- File: `apps/back-office/composables/useAdminOperationsCatalog.ts`
- Lines: 194-228, 442-453
- Expected contract: `docs/openapi.yaml` documents tenant growth resources at paths such as:
  - `/admin/tenant/agents`
  - `/admin/tenant/agents/{agent_id}`
  - `/admin/tenant/agents/{agent_id}/quotas`
  - `/admin/tenant/affiliate-programs`
  - `/admin/tenant/affiliate-links`
  - `/admin/tenant/affiliate-attributions`
  - `/admin/tenant/affiliates`
  - `/admin/tenant/commission-rules`
  - `/admin/tenant/commission-transactions`
  - `/admin/tenant/commission-transactions/{commission_id}/approve`
  - `/admin/tenant/payouts`
  - `/admin/tenant/payouts/{payout_id}/approve`
- Actual implementation: the catalog calls `/admin/tenant/growth/...` variants for the same resources and actions.
- Impact: these pages/actions will call undocumented endpoints and likely fail at runtime or drift from the backend contract.
- Acceptance criteria affected: API wiring must use approved OpenAPI endpoints only.

## Test Coverage Gap

### P2: Static back-office test does not validate catalog endpoints against OpenAPI

- File: `apps/back-office/scripts/check.mjs`
- Lines: 80-87
- The current static check verifies required headers exist in `useAdminApi.ts`, but it does not compare catalog endpoints against `docs/openapi.yaml`. As a result, `npm run test` passes even though the tenant growth operations catalog has endpoint drift.

## Validation Performed

- `docker compose build back-office` - PASS
- `docker compose run --rm back-office npm ci` - PASS
  - Known output remains: 35 npm audit vulnerabilities, including 1 critical.
- `docker compose run --rm back-office npm run build` - PASS
  - Known warnings remain: Node `[DEP0180]` deprecation warning and unresolved `/admin-template/assets/images/media/media-33.jpg` left for runtime resolution.
- `docker compose run --rm back-office npm run lint` - PASS
- `docker compose run --rm back-office npm run test` - PASS
- `docker compose up -d platform-api back-office` - PASS
- `curl -I --max-time 10 http://localhost:3100/login` - PASS, HTTP 200
- `curl -I --max-time 10 http://localhost:3100/admin/tenant/stock` - PASS, HTTP 302 to `/` without session
- `curl -I --max-time 10 http://localhost:3100/admin/central/partners` - PASS, HTTP 302 to `/` without session

## Static Inspection Notes

- Tenant and central catch-all pages exist and render `AdminOperationsPage` with the expected scope.
- `useAdminApi.ts` centralizes admin API calls and includes `X-Request-Id`, `X-Admin-Scope`, tenant `X-Tenant-Id`, authorization, and idempotency support.
- `AdminOperationsPage.vue` uses the shared admin API composable, confirmation modal flow, idempotency for mutating actions, and tenant scope/session data.
- No new support-access token localStorage persistence was found in the inspected back-office files.

## Recommendation

Return to Back Office to align the tenant growth catalog endpoints with `docs/openapi.yaml`, then strengthen the static check so catalog endpoint drift is caught automatically. After that, rerun the same Docker validation set.

## Next Agent

Coordinator
