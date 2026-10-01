# QA Report

## Task

`m2-partner-suspend-admin-access - QA Tester`

Task file: `ai-agents/tasks/20260506-m2-partner-suspend-admin-access-qa.md`

Backend handoff: `ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md`

Date: 2026-05-06

## Scope Tested

Result: PASS

QA validated the focused D1/P1 revision for suspended partner tenant admin access.

Reviewed source-of-truth and workflow files:

- `ai-agents/decisions/20260506-m2-partner-provisioning-core-qa-review-decision.md`
- `ai-agents/handoffs/20260506-m2-partner-provisioning-core-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md`
- `ai-agents/tasks/20260506-m2-partner-suspend-admin-access-backend.md`
- `ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md`
- `ai-agents/tasks/20260506-m2-partner-suspend-admin-access-qa.md`
- `ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-qa-task-orchestrator-handoff.md`
- `ai-agents/roles/qa-tester.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/stage-gates.md`
- `ai-agents/workflow/handoff-protocol.md`
- `ai-agents/workflow/file-ownership.md`
- `docs/docker-runtime-policy.md`

Reviewed implementation/test evidence:

- `apps/platform-api/app/Shared/Auth/AdminAuthService.php`
- `apps/platform-api/app/Shared/Auth/AdminSessionResolver.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php`
- `apps/platform-api/tests/Feature/PartnerProvisioningTest.php`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`

Confirmed by source review:

- Tenant admin scope listing now excludes tenant scopes unless both `partner_tenants.status` and parent `partners.status` are active.
- Tenant-scope login cannot select a suspended/inactive tenant or partner because unusable tenant scopes are filtered before active-scope selection.
- Existing tenant admin access tokens are rejected and the current session is revoked when session resolution finds the tenant scope unusable.
- Tenant scope middleware rechecks active tenant/partner status before allowing tenant admin requests.
- Refresh after suspension cannot reissue a usable tenant session because the original tenant scope is no longer present in the usable scope list.
- Central admin sessions remain usable because central scopes are not tied to tenant/partner active status.
- Public site-config suspended-domain behavior remains safe and covered.

## Commands Run

All validation commands were run through Docker only:

```sh
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands used host file inspection only:

```sh
rg ...
sed -n ...
git status --short ...
```

## Test Results

- `PartnerProvisioning`: PASS, 4 tests, 145 assertions
- `AdminAuth`: PASS, 9 tests, 78 assertions
- `TenantSettings`: PASS, 1 test, 25 assertions
- `SiteConfig`: PASS, 1 test, 44 assertions
- `PartnerApiClient`: PASS, 1 test, 27 assertions
- Full platform-api suite: PASS, 57 tests, 545 assertions

Focused regression coverage now proves:

- Owner admin can log in under tenant scope before partner suspend.
- Owner admin cannot log in under tenant scope after partner suspend.
- Existing tenant admin access token cannot access tenant settings after partner suspend.
- Existing tenant admin access token cannot access tenant theme after partner suspend.
- Refreshing an existing tenant session after partner suspend is rejected.
- Central admin can still view and update the suspended partner.
- Suspended partner domain returns the safe public site-config error.

## Defects

None found.

D1/P1 is closed by this revision.

## Risks / Not Tested

- The worktree has pre-existing dirty/untracked source-of-truth docs and platform-api paths from the broader agent workflow. QA did not modify them and did not attribute those existing changes to this focused revision.
- Because `apps/platform-api/**` is broadly untracked in this workspace, `git status --short` cannot precisely isolate every revision delta. QA compared the Backend handoff against the approved revision scope and inspected the declared changed files directly.
- No customer or back-office validation was run because both are out of scope for this backend access-control revision.
- No schema migration was needed or tested beyond the full platform-api suite using the existing migrations.

## Recommendation

Recommend Coordinator approve the focused `m2-partner-suspend-admin-access` revision and continue the M2 Partner Provisioning Core approval gate.

## Next Agent

Coordinator
