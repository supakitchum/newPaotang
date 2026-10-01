# Back Office P1 Topups Customer Context Remediation QA Report

Date: 2026-05-10
Task: `back-office-p1-topups-customer-context-remediation`
QA: Open Chat QA Tester

## Result

PASS - no new defects found.

The topups approve/reject/cancel confirmations now show meaningful tenant topup customer context from the API-backed record instead of falling back to a generic JSON-only workflow. Shared Orders and Wallets confirmation smoke checks also still pass.

## Scope

- Implementation commit under test: `fd57c58de28d885de4c2dc69d24b190f0434a10b`
- BO handoff commit: `8f3e3b794ed3df18faf3584826287c5e470193b2`
- Focused tenant topups customer context gap.
- Shared smoke for tenant orders and wallets confirmation actions.
- API-first validation only; no Customer frontend work was tested or requested.

## API-First Evidence

Validated with tenant admin scope headers:

- `X-Admin-Scope: tenant`
- `X-Tenant-Id: ten_demo_alpha`

Validated endpoints:

- `GET /api/v1/admin/tenant/topups?limit=50`
- `GET /api/v1/admin/tenant/topups/top_qa_ctx_20260510`

Both list and detail responses include the nested customer object for the seeded topup:

- Topup: `top_qa_ctx_20260510`
- Reference: `QA-TOPUP-CTX-20260510`
- Customer id: `cus_qa_ctx_20260510`
- Customer name: `QA Context Customer`
- Customer phone: `+66020000010`
- Customer email: `qa.ctx.20260510@example.test`

Fallback note: this seeded row does not require fallback behavior because the API returns complete nested customer context. BO should therefore render structured context fields and avoid a generic JSON-only workflow for this case.

Artifacts:

- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/api/tenant-topups-api-summary.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/api/tenant-topups-list.raw.json`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/api/tenant-topups-detail.raw.json`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/api/tenant-topups-list.sanitized.json`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/api/tenant-topups-detail.sanitized.json`

## Browser QA

Tenant browser checks were performed from an authenticated tenant session.

Topups:

- Opened Topups from the real tenant menu.
- Seeded topup row rendered and kept Detail / Approve / Reject / Cancel actions.
- Detail page remained available at `/admin/tenant/topups/top_qa_ctx_20260510`.
- Detail page showed nested customer id/name/phone/email, tenant id, reference, channel, amount, currency, and wallet context.
- Approve modal showed topup id, tenant id, reference, customer id/name/phone/email, status, amount, currency, channel, optional approved amount, optional bonus amount, currency controls, notify customer, and required reason guard.
- Reject modal showed the same topup/customer/money/channel context, notify customer, and required reason guard.
- Cancel modal showed the same topup/customer/money/channel context, notify customer, and required reason guard.
- Confirm remained disabled with blank reason in all tested topup modals.

Shared smoke:

- Tenant Orders list still rendered customer context as `QA Context Customer | +66020000010 | cus_qa_ctx_20260510`.
- Tenant Orders Update modal still showed order/customer/payment/total context and required reason guard.
- Tenant Wallets list still rendered the seeded wallet/customer/balance row.
- Tenant Wallets Adjust modal still showed wallet/customer/balance/currency context and required reason guard.

Key browser artifacts:

- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/browser/tenant-topups-from-menu.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/browser/tenant-topups-detail.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/browser/tenant-topups-approve-modal.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/browser/tenant-topups-reject-modal.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/browser/tenant-topups-cancel-modal.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/browser/tenant-orders-update-modal-smoke.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/browser/tenant-wallets-adjust-modal-smoke.snapshot.txt`

PNG screenshots are saved alongside each browser snapshot in the same artifact directory.

## Validation Commands

Passed:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest`
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`
- Final `docker compose run --rm platform-api php artisan migrate:fresh --seed` before API/browser QA

Note: the first backend focused test attempt ran `AdminOperationsTest` and `AdminMenuTest` concurrently and hit a database refresh/migration collision. That attempt was invalidated, the database was reseeded, and both tests were rerun sequentially successfully.

Build warnings observed and carried forward:

- Node `DEP0180` deprecation warning for `fs.Stats` constructor.
- `/admin-template/assets/images/media/media-33.jpg` unresolved at build time and left for runtime resolution.

## Findings

None.

## Recommendation

Send this report to Coordinator for review/decision. No Backend, BO, or Customer follow-up is requested directly from QA.
