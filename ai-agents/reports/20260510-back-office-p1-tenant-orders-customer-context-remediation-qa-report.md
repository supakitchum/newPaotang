# Back Office P1 Tenant Orders Customer Context Remediation QA Report

## Summary

Agent: QA Tester

Task: `back-office-p1-tenant-orders-customer-context-remediation`

Date: 2026-05-10

Branch: `develop`

HEAD under test: `0ed86a4bcfd73f21c45092d6432efb3de796ade8`

Implementation under test: `126a2ee94d609233e99be8099671300bf54c75f9`

Result: Original tenant orders P1 blocker is resolved. QA found one new P2 customer-context gap during the required shared-component smoke and routes it to Coordinator for scope/owner decision.

## Review Findings

### Finding 1 (apps/back-office/composables/useAdminOperationsCatalog.ts:169,438-453) [added]
[P2] Topup approve/cancel confirmations omit customer context

The tenant topup API response includes nested customer context, but the BO topup actions still use `moneyActionContext`, which only reads top-level `customer_id`. The seeded topup API response included `customer.id`, `customer.name`, `customer.phone`, and `customer.email`, while the BO approve modal showed topup id/reference/status/amount and reason guard but no customer/member identity. This is a customer-facing financial workflow, so Coordinator should decide whether to route a separate BO remediation. This is outside the focused tenant orders blocker, which passed.

Evidence:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/api/tenant-topups-list.sanitized.json
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/api/tenant-topups-api-summary.txt
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/browser/tenant-topups-approve-modal-smoke.snapshot.txt
```

## API-First Validation

API-first tenant order validation passed before BO browser testing.

```text
GET /admin/tenant/orders: 200
GET /admin/tenant/orders/{order_id}: 200
Tenant scope: X-Admin-Scope=tenant, X-Tenant-Id=ten_demo_alpha
Order: ord_qa_ctx_20260510
Nested customer: cus_qa_ctx_20260510 / QA Context Customer / +66020000010 / qa.ctx.20260510@example.test
Fallback note: fallback was not needed because seeded nested customer data was complete.
```

Artifacts:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/api/tenant-orders-api-summary.txt
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/api/tenant-orders-list.sanitized.json
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/api/tenant-orders-detail.sanitized.json
```

No Customer frontend was used. Login responses and bearer tokens were not written to artifacts.

## Tenant Orders Browser Retest

Tenant orders were opened from the real authenticated tenant menu at `/admin/tenant/orders`.

Passed:

```text
List Customer column renders "QA Context Customer | +66020000010 | cus_qa_ctx_20260510" instead of "-"
Detail page exposes tenant id, order id/reference/status/payment/amount, and nested customer id/name/phone/email
Update modal includes tenant/order/customer/status/payment/amount context, typed controls, and disabled Confirm with blank reason
Cancel modal includes tenant/order/customer/status/payment/amount context, typed controls, and disabled Confirm with blank reason
Refund modal includes tenant/order/customer/status/payment/amount context, typed controls, and disabled Confirm with blank reason
No generic JSON-only action modal was used for these order actions
No unrelated dashboard/settings/reports/partners/agents route fallback occurred
```

Artifacts:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/browser/tenant-orders-from-menu.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/browser/tenant-orders-detail.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/browser/tenant-orders-update-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/browser/tenant-orders-cancel-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/browser/tenant-orders-refund-modal.snapshot.txt
```

## Shared Smoke

Passed:

```text
tenant:wallets adjust modal shows wallet/customer/balance context, typed money controls, and disabled Confirm with blank reason
tenant:reservations cancel modal shows reservation/customer/status/expires context and disabled Confirm with blank reason
tenant:topups approve modal shows topup id/reference/status/amount context, typed controls, notify control, and disabled Confirm with blank reason
```

New issue:

```text
tenant:topups approve modal does not show customer/member context even though the API returns nested customer context.
```

## Docker Validation

All required Docker-only validation commands passed:

```text
git diff --check: PASS
docker compose up -d postgres valkey platform-api back-office: PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed: PASS
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest: PASS, 7 tests / 95 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest: PASS, 5 tests / 26 assertions
docker compose run --rm back-office npm run lint: PASS
docker compose run --rm back-office npm run test: PASS
docker compose run --rm back-office npm run build: PASS
docker compose up -d --force-recreate back-office: PASS
```

Build warnings carried forward:

```text
Node DEP0180 fs.Stats constructor deprecation warning
/admin-template/assets/images/media/media-33.jpg unresolved at build time; remains runtime-resolved
```

Validation artifacts:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/validation/
```

## Workspace Notes

Existing unrelated dirty files were left untouched:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
```

QA-created artifacts are under:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/
```

## Routing

Next agent: Coordinator

Reason: QA Tester must not directly assign work to BO or Backend. Coordinator should decide whether Finding 1 opens a separate BO remediation and whether the resolved tenant orders blocker is enough to continue the P1 BO workflow approval path.
