# BO Develop Handoff: P1 Tenant Topups Customer Context Remediation

- Task: `back-office-p1-topups-customer-context-remediation`
- Agent: BO Develop Agent
- Date: 2026-05-10
- Implementation commit: `fd57c58de28d885de4c2dc69d24b190f0434a10b`
- Next Agent: Orchestrator

## Summary

Tenant topup approve/reject/cancel confirmations now use a topup-specific action context instead of the generic money context. The confirmation modal can show nested customer payload fields from the API while preserving top-level customer/member compatibility.

## Files Changed

- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminConfirmAction.vue`
- `apps/back-office/scripts/check.mjs`
- `docs/back-office-crud-coverage.md`

## Behavior Implemented

- Added `topupActionContext` for tenant topups.
- Topup approve/reject/cancel confirmation context now includes:
  - `id`
  - `tenant_id`
  - `reference`
  - `customer_id`
  - `member_id`
  - `customer.id`
  - `customer.name`
  - `customer.phone`
  - `status`
  - `amount.amount`
  - `amount.currency`
  - `channel`
  - `customer.email`
- Kept existing topup approve optional amount/bonus fields, reason guard, and notify customer control.
- Increased confirmation context display limit from 10 to 13 so the full topup customer and payment context can render after blank values are filtered.
- Added a BO check guardrail for topup nested customer context.
- Updated CRUD coverage notes for `tenant:topups`; status remains `partial` pending QA retest.

## Validation

- `git diff --check` passed.
- `docker compose up -d postgres valkey platform-api back-office` passed.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` passed.
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest` passed: 7 tests, 95 assertions.
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` passed: 5 tests, 26 assertions.
- `docker compose run --rm back-office npm run lint` passed.
- `docker compose run --rm back-office npm run test` passed.
- `docker compose run --rm back-office npm run build` passed.
- `docker compose up -d --force-recreate back-office` passed.

## Notes For Orchestrator

- No backend, customer app, OpenAPI, compose, GitHub workflow, board, decision, task, or report files were edited for this remediation.
- Existing unrelated dirty files were left untouched:
  - `ai-agents/prompts/open-chat-bo-develop.md`
  - `ai-agents/roles/bo-develop.md`
  - `ai-agents/rules/global-rules.md`
  - `apps/platform-api/.phpunit.result.cache`
  - `docs/admin-dashboard-template-guidelines.md`
  - `docs/back-office-admin-foundation.md`
  - `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
  - `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- Nuxt build emitted the existing runtime asset warning for `/admin-template/assets/images/media/media-33.jpg`; build completed successfully.
- `git commit` emitted a repository maintenance warning about `.git/gc.log` and loose objects; no cleanup was performed because it is outside this task scope.

## Suggested QA Focus

- Log in to BO tenant admin and open Tenant Topups.
- Confirm the seeded/nested customer topup row (for example `QA-TOPUP-CTX-20260510`) shows meaningful customer/member context in approve, reject, and cancel confirmations.
- Verify visible confirmation context includes topup reference, nested customer name/phone or email, amount/currency, channel, and status.
- Confirm approve/reject/cancel still preserve reason requirements and notify customer controls.
