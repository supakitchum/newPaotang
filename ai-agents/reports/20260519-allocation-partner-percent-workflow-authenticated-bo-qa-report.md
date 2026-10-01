# 2026-05-19 Allocation Partner Percent Workflow Authenticated BO QA

## Result

PASS

## Scope

- Task: `allocation-partner-percent-workflow-authenticated-bo-qa`
- Tested commit: `13f6b8fe5524f7a19980fc977c27b16dc33fcce3`
- Worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- Browser tool: Playwright Chromium in Docker (`mcr.microsoft.com/playwright:v1.56.1-noble`, `playwright@1.56.1`)
- App target: `http://localhost:3100`

## Validation Summary

- Back-office checks passed:
  - `docker compose -p newpaotang run --rm back-office npm run lint`
  - `docker compose -p newpaotang run --rm back-office npm run test`
  - `docker compose -p newpaotang run --rm back-office npm run build`
- Authenticated BO browser workflow passed:
  - Real central admin login succeeded.
  - Allocation page loaded authenticated options.
  - Create allocation submitted `allocation_percent: 30` and did not submit `requested_count`.
  - Single-tenant partner auto-filled `ten_boqa_single`.
  - Redistribute was disabled before recall.
  - Recall-all moved allocation to `Recalled`.
  - Redistribute moved allocation back to `Allocated`.
  - Partner percent update of `80%` on another partner returned validation `422` because active total would exceed 100%.
  - Scoped action hrefs and routes were verified:
    - Remaining stock: `/admin/central/stock-generation?game_id=gam_boqa_alloc&partner_id=par_boqa_single&tenant_id=ten_boqa_single&allocation_id=...&status=allocated`
    - Stock coverage: `/admin/central/stock-pattern-coverage?game_id=gam_boqa_alloc&scope_type=partner&scope_id=par_boqa_single`

## Runtime DB Note

Runtime DB `newpaotang` was not wiped. During browser QA, the runtime schema was missing `2026_05_19_000005_add_percent_workflow_to_partner_stock_allocations`; it was `Pending` before QA migration and `Ran` after:

- `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/runtime/runtime-migrate-status-before.txt`
- `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/runtime/runtime-migrate-force.txt`
- `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/runtime/runtime-migrate-status-after.txt`

## Evidence

- Browser summary: `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/browser/workflow-summary.json`
- Network evidence: `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/browser/network-events.json`
- Create modal/table: `browser/04-create-allocation-empty-modal.png`, `browser/05-create-allocation-filled-modal.png`, `browser/06-allocation-created-table.png`
- Recall/redistribute: `browser/09-recall-all-modal.png`, `browser/10-after-recall-all-table.png`, `browser/11-redistribute-modal.png`, `browser/12-after-redistribute-table.png`
- Partner percent validation: `browser/16-partner-percent-over-100-modal.png`, `browser/17-partner-percent-over-100-error.png`
- Scoped actions: `browser/13-scoped-action-hrefs.json`, `browser/18-remaining-stock-scoped-route.png`, `browser/19-stock-coverage-scoped-route.png`
- BO checks: `back-office/npm-lint.txt`, `back-office/npm-test.txt`, `back-office/npm-build.txt`

## Runtime Restore / Smoke

After browser QA, runtime restore and smoke passed:

- `docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction`
- `docker compose -p newpaotang exec -T platform-api php artisan platform:smoke`
- Back-office container recreated.
- Customer `/login`: `200`
- Back-office `/login`: `200`
- Back-office `/admin/login`: `302` to `/login`, follow result `200`
- Central admin API login: `200`, access token present, secondary session token present

Evidence:

- `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/runtime/runtime-db-seed.txt`
- `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/runtime/runtime-platform-smoke.txt`
- `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/runtime/runtime-login-http-smoke.txt`
- `ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/runtime/runtime-central-admin-api-login-smoke.json`

## Defects

No product defects found in the authenticated BO allocation percent workflow.

## DB Isolation

No database wipe was performed. QA fixture setup was limited to deterministic `BOQA` partner/tenant/game records and cleanup of allocations/distributions scoped to `gam_boqa_alloc`.

## Next Agent

Coordinator
