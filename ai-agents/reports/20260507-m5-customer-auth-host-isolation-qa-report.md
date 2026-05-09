# QA Report: M5 Customer Auth Host Isolation

## Task

`20260507-m5-customer-auth-host-isolation-qa`

## Summary

Result: PASS

D1/P1 from the M5 checkout/wallet/sold-sync QA report is closed. Authenticated customer auth/profile routes now resolve the request tenant from `Host` in `customer.auth` middleware, compare the bearer token tenant before controller execution, and reject tenant A tokens used through tenant B host without leaking profile data or revoking the tenant A session.

## Scope Reviewed

Focused revision scope only:

- `POST /api/v1/customer/auth/logout`
- `GET /api/v1/customer/auth/me`
- `GET /api/v1/customer/profile`
- `PATCH /api/v1/customer/profile`
- `customer.auth` middleware host/session tenant enforcement
- Customer session resolver expected-tenant handling
- Customer auth regression coverage for same-host and cross-tenant host mismatch behavior
- Customer checkout/topup regression with the centralized middleware behavior

## Files Inspected

- `ai-agents/prompts/open-chat-qa-tester.md`
- `ai-agents/rules/global-rules.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md`
- `ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-qa-review-decision.md`
- `ai-agents/tasks/20260507-m5-customer-auth-host-isolation-backend.md`
- `ai-agents/tasks/20260507-m5-customer-auth-host-isolation-qa.md`
- `ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md`
- `ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-qa-task-orchestrator-handoff.md`
- `ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php`
- `apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php`
- `apps/platform-api/app/Shared/Auth/CustomerAuthService.php`
- `apps/platform-api/tests/Feature/CustomerAuthTest.php`
- `apps/platform-api/tests/Support/M5CommerceFixtures.php`

## Commands Run

All application/runtime commands were run through Docker only.

```sh
docker compose run --rm platform-api php artisan test --filter=CustomerAuth
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout
docker compose run --rm platform-api php artisan test --filter=CustomerTopup
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands included `git status --short`, `rg`, `sed`, `nl -ba`, and `ls`.

## Test Results

- `CustomerAuth`: PASS, 2 tests, 40 assertions
- `CustomerCheckout`: PASS, 1 test, 30 assertions
- `CustomerTopup`: PASS, 1 test, 21 assertions
- Full platform-api suite: PASS, 80 tests, 1140 assertions

## D1/P1 Closure Assessment

D1/P1 is closed.

Evidence:

- `AuthenticateCustomer` resolves tenant context from the request host before protected customer routes proceed: `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php:23-31`
- Middleware reads the bearer token tenant and returns `permission_denied` when it differs from the resolved host tenant before controller execution: `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php:32-42`
- Middleware sets both `customer_session` and `customer_tenant` only after successful tenant/session match: `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php:42-50`
- `CustomerSessionResolver::resolveAccessToken()` accepts an expected tenant and returns null before profile read or `last_used_at` mutation on mismatch: `apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php:24-57`
- The focused regression test covers tenant A token through tenant B host for `auth/me`, `profile`, profile patch, and logout: `apps/platform-api/tests/Feature/CustomerAuthTest.php:98-167`

## Tenant Host Resolution Findings

The revised `customer.auth` middleware calls `PartnerStoreService::tenantContextForRequest()` using the request host before invoking the controller. Unknown, inactive, suspended, and maintenance-blocked hosts therefore reuse existing tenant-resolution error handling. For auth/profile/logout paths, middleware blocks maintenance via the existing maintenance response path.

This centralizes host/session tenant matching for current protected customer routes. Customer commerce endpoints still run their controller-level tenant checks after middleware, so checkout and topup regressions were included.

## Session Tenant Comparison Findings

The middleware performs a token tenant preflight with `accessTokenTenantId()` and compares it to the resolved host tenant. On mismatch, it returns `permission_denied` immediately and does not call `resolveAccessToken()`, so no customer profile is loaded and `last_used_at` is not updated by the resolver mismatch path.

`resolveAccessToken()` also has a defensive expected-tenant check before customer lookup and before updating session usage timestamps.

## Cross-Tenant Access Findings

Focused coverage proves a tenant A bearer token sent to tenant B host receives `403 permission_denied` for:

- `GET /api/v1/customer/auth/me`
- `GET /api/v1/customer/profile`
- `PATCH /api/v1/customer/profile`
- `POST /api/v1/customer/auth/logout`

The test also asserts tenant A profile data is not included in cross-tenant responses and that the attempted profile patch does not mutate the tenant A customer.

## Cross-Tenant Logout Non-Revocation Findings

Focused coverage proves cross-tenant logout returns `permission_denied` and leaves the tenant A session `revoked_at` null. The same test then verifies the same tenant A token still works on tenant A host and that same-host logout revokes the session.

## Same-Host Regression Findings

Existing same-host register, login, refresh, `auth/me`, `profile`, profile patch, and logout behavior remains covered and passing in `CustomerAuth`.

## Customer Checkout / Topup Regression Findings

`CustomerCheckout` and `CustomerTopup` pass with the updated centralized `customer.auth` middleware. This confirms the host/session tenant enforcement did not break existing authenticated customer checkout/topup flows.

## Defects

None found.

## Known Risks / Coordinator Questions

- The workspace has broad dirty/untracked files from the multi-agent workflow, and `apps/platform-api/**` appears untracked in this checkout, so `git status` cannot precisely prove the focused Backend diff. QA verified the revision handoff, approved file list, and inspected the focused implementation/test files directly.
- Maintenance blocking is now centralized in customer auth middleware for auth/profile/logout paths, while other protected customer endpoints still rely on their existing controller-level maintenance behavior. QA did not find a regression, but Coordinator may want to keep that convention explicit in future customer auth middleware work.
- QA did not edit implementation, customer app, back-office app, source-of-truth docs, decisions, tasks, handoffs, or Board files.

## Recommendation

Recommend Coordinator approve the focused M5 customer auth host-isolation revision and resume M5 checkout/wallet/sold-sync Gate review with D1/P1 closed.

## Next Agent

Coordinator
