# m2-partner-suspend-admin-access - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused revision handoff for QA defect D1/P1:

```text
ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md
```

Validate that suspended partner/tenant admin access is blocked across login, refresh/session resolution, and tenant admin endpoint authorization, while central admin partner management remains usable.

## Objective

Test and report whether the focused suspend-admin-access revision closes D1/P1 without introducing unrelated changes to partner create/provision/site-config/API-client behavior, schema, source-of-truth docs, customer, or back-office behavior.

## Source Of Truth

- ai-agents/decisions/20260506-m2-partner-provisioning-core-qa-review-decision.md
- ai-agents/handoffs/20260506-m2-partner-provisioning-core-qa-review-coordinator-handoff.md
- ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md
- ai-agents/tasks/20260506-m2-partner-suspend-admin-access-backend.md
- ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md
- ai-agents/tasks/20260506-m2-partner-provisioning-core-backend.md
- ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md
- docs/docker-runtime-policy.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

- Review Coordinator QA review decision, original QA report, Backend revision task, and Backend revision handoff.
- Verify changed backend files stay within the approved revision scope:
  - `apps/platform-api/app/Shared/Auth/**`
  - `apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerProvisioningController.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantConfigurationController.php`
  - `apps/platform-api/tests/Feature/PartnerProvisioningTest.php`
  - `apps/platform-api/tests/Feature/AdminAuthTest.php`
  - `apps/platform-api/tests/Feature/TenantSettingsTest.php`
- Validate the focused D1/P1 fix:
  - owner admin can log in under tenant scope before partner suspend
  - owner admin cannot log in under tenant scope after partner suspend
  - suspended `partner_tenants` cannot be selected during tenant-scope admin login
  - suspended `partners` cannot be selected during tenant-scope admin login
  - an existing tenant admin access token cannot access tenant settings after partner suspend
  - an existing tenant admin access token cannot access tenant theme after partner suspend
  - refreshing an existing tenant session after partner suspend is rejected or produces no usable suspended tenant scope
  - tenant admin endpoints return the project safe permission/auth error format after suspension
  - central admin can still view/manage the suspended partner according to central permissions
  - public site-config suspended-domain behavior remains safe
- Run required Docker-only validation.
- Report pass/fail, remaining defects, risks, and recommended next agent.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/platform-api/**` except test fixtures only if Coordinator explicitly authorizes it.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not retest the full M2 Partner Provisioning Core surface beyond regression evidence needed for this access-control revision.
- Do not require schema changes, hard delete, broad token revocation infrastructure, general idempotency persistence/replay semantics, Cloudflare/DNS/SSL workers, quotas, stock, checkout, wallet, payment, reward, support, or frontend work.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/**
tests/** only if Coordinator explicitly allows test fixture updates
apps/*/tests/** only if Coordinator explicitly allows test fixture updates
```

Must not edit:

```text
apps/platform-api/app/**
apps/platform-api/bootstrap/**
apps/platform-api/config/**
apps/platform-api/database/**
apps/platform-api/routes/**
apps/platform-api/tests/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
```

This task should be read-only except for writing the QA report.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `ai-agents/roles/qa-tester.md`, `ai-agents/rules/global-rules.md`, `ai-agents/workflow/stage-gates.md`, `ai-agents/workflow/handoff-protocol.md`, and `ai-agents/workflow/file-ownership.md`.
3. Compare Backend revision handoff against `ai-agents/tasks/20260506-m2-partner-suspend-admin-access-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved revision scope.
5. Inspect `AdminAuthService`, `AdminSessionResolver`, `RequireAdminScope`, and the focused regression tests.
6. Verify tenant admin scope listing excludes tenant scopes whose `partner_tenants.status` or parent `partners.status` is not active.
7. Verify tenant-scope login rejects suspended/inactive tenant or partner.
8. Verify tenant session resolution rejects/revokes the current session when the tenant scope becomes unusable after suspension.
9. Verify tenant scope middleware rechecks active tenant/partner status before tenant admin requests.
10. Verify refresh after suspension cannot reissue a usable tenant scope.
11. Verify central admin partner management remains usable after partner suspension.
12. Verify public site-config suspended-domain behavior remains safe.
13. Run validation commands through Docker only.
14. If a validation command fails, capture the failure and continue any safe read-only checks.
15. Record defects as actionable items with evidence.
16. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m2-partner-suspend-admin-access-qa-report.md`.
- QA confirms D1/P1 is closed.
- QA confirms suspended `partner_tenants` cannot be selected during tenant-scope admin login.
- QA confirms suspended `partners` cannot be selected during tenant-scope admin login.
- QA confirms existing tenant admin access tokens cannot access tenant settings/theme after partner suspend.
- QA confirms refreshing an existing tenant session after partner suspend is rejected or produces no usable suspended tenant scope.
- QA confirms tenant admin endpoints return the project safe permission/auth error format after suspension.
- QA confirms central admin can still view/manage the suspended partner according to central permissions.
- QA confirms public site-config behavior for suspended/inactive domains remains safe.
- QA confirms no customer/back-office/source-of-truth doc/schema changes were made for this revision.
- QA confirms focused Docker validation passes.
- QA confirms full platform-api test suite passes through Docker.
- QA confirms Docker runtime policy was followed.
- QA identifies remaining defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
sed -n '1,420p' apps/platform-api/app/Shared/Auth/AdminAuthService.php
sed -n '1,360p' apps/platform-api/app/Shared/Auth/AdminSessionResolver.php
sed -n '1,220p' apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php
sed -n '1,880p' apps/platform-api/tests/Feature/PartnerProvisioningTest.php
sed -n '1,360p' apps/platform-api/tests/Feature/AdminAuthTest.php
sed -n '1,260p' apps/platform-api/tests/Feature/TenantSettingsTest.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m2-partner-suspend-admin-access-qa-report.md
```

Must include:

```text
task
scope tested
commands run
test results
defects
risks / not tested
recommendation
next agent
```

Next Agent should be:

```text
Coordinator
```
