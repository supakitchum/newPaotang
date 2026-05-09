# m5-customer-auth-host-isolation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused M5 revision for:

```text
D1/P1 - Customer auth/profile endpoints ignore the tenant host for existing bearer sessions
```

Validate the revision against the Coordinator QA review decision, the Backend revision task, the Backend revision handoff, the original M5 customer auth/profile tenant-host contract, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-qa-review-decision.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-qa-review-coordinator-handoff.md
ai-agents/tasks/20260507-m5-customer-auth-host-isolation-backend.md
ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md
ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md
```

## Objective

Validate that authenticated customer auth/profile endpoints now resolve the active tenant from the request host and reject bearer sessions whose tenant does not match that host before returning, updating, or revoking customer/session data.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md
- ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
- ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
- ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-qa.md
- ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md
- ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-qa-review-decision.md
- ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-qa-review-coordinator-handoff.md
- ai-agents/tasks/20260507-m5-customer-auth-host-isolation-backend.md
- ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md

## Scope

Validate only the focused revision for customer bearer-session host/tenant isolation on:

```text
POST /api/v1/customer/auth/logout
GET /api/v1/customer/auth/me
GET /api/v1/customer/profile
PATCH /api/v1/customer/profile
```

Inspect only approved revision files and related evidence:

```text
apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php
apps/platform-api/app/Shared/Auth/CustomerAuthService.php
apps/platform-api/tests/Feature/CustomerAuthTest.php
apps/platform-api/tests/Support/M5CommerceFixtures.php
ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md
```

Validate that:

- Customer auth middleware resolves request tenant from `Host`/`TenantHostHeader` before protected customer routes proceed.
- Unknown, inactive, suspended, or maintenance-blocked tenant hosts are rejected consistently with existing customer endpoint conventions.
- Bearer token `tenant_id` must match resolved request tenant before controller execution.
- Tenant A token used through tenant B host cannot access `auth/me`, `profile`, `profile update`, or `logout`.
- Cross-tenant host mismatch returns the existing `permission_denied` or equivalent approved error without leaking tenant A profile data.
- Cross-tenant logout attempt does not revoke tenant A session and does not update sensitive session state.
- Same-host `me`, `profile`, `profile update`, and `logout` behavior remains unchanged.
- Existing customer checkout and topup authenticated endpoints still pass with the centralized middleware behavior.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates another follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not create or edit `apps/back-office/**`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not change checkout, wallet ledger, orders, tickets, topups, webhooks, sold sync, tenant admin commerce behavior, or schema.
- Do not implement LINE login, realtime auth, reward, affiliate, reports, settlement, real payment SDKs, or UI.
- Do not broaden QA into a full auth redesign review beyond host/session tenant enforcement and relevant regression checks.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code changes, record it in the QA report with severity, evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Backend revision handoff against the Backend revision task and Coordinator QA review decision.
4. Inspect `git status --short` and confirm whether the revision changed only approved files plus the Backend handoff.
5. Inspect `AuthenticateCustomer` and confirm tenant host resolution and session tenant comparison occur before controller execution.
6. Inspect `CustomerSessionResolver` and confirm expected-tenant resolution blocks cross-tenant mismatch before profile read/session mutation and does not touch `last_used_at` on mismatch if Backend claims that behavior.
7. Inspect `CustomerAuthController` and `CustomerAuthService` as needed to verify same-host behavior remains unchanged and controller methods no longer need to carry the isolation check themselves.
8. Inspect `CustomerAuthTest` and fixtures for regression coverage across tenant A token + tenant B host for `me`, `profile`, `profile update`, and `logout`.
9. Verify failed cross-tenant logout does not revoke tenant A session.
10. Verify same-host `me`, `profile`, `profile update`, and `logout` still work.
11. Run all required validation commands through Docker only.
12. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m5-customer-auth-host-isolation-qa-report.md`.
- QA report states whether the focused revision passes, conditionally passes, or fails.
- QA report verifies D1/P1 is closed or identifies why it remains open.
- QA report confirms tenant A token cannot access `auth/me`, `profile`, `profile update`, or `logout` through tenant B host.
- QA report confirms failed cross-tenant logout does not revoke tenant A session.
- QA report confirms same-host `me`, `profile`, `profile update`, and `logout` still work.
- QA report confirms `CustomerAuth`, `CustomerCheckout`, `CustomerTopup`, and full `platform-api` validation results.
- QA report confirms no out-of-scope app, docs, decision, task, handoff, or Board changes were made by QA.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=CustomerAuth
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout
docker compose run --rm platform-api php artisan test --filter=CustomerTopup
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
sed -n '1,260p' apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
sed -n '1,320p' apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
sed -n '1,220p' apps/platform-api/app/Shared/Auth/CustomerAuthService.php
sed -n '1,260p' apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php
sed -n '1,560p' apps/platform-api/tests/Feature/CustomerAuthTest.php
sed -n '1,360p' apps/platform-api/tests/Support/M5CommerceFixtures.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m5-customer-auth-host-isolation-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
D1/P1 closure assessment
tenant host resolution findings
session tenant comparison findings
cross-tenant access findings
cross-tenant logout non-revocation findings
same-host regression findings
customer checkout/topup regression findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```
