# QA Report: Backend Model Adoption Remediation

- Task: `20260507-backend-model-adoption-remediation`
- QA task: `ai-agents/tasks/20260507-backend-model-adoption-remediation-qa.md`
- Backend handoff: `ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md`
- Decision: `ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md`
- Reviewed at: `2026-05-07 22:37:41 +0700`
- QA verdict: FAIL
- Next agent: Coordinator

## Summary

Docker validation is green, including the full platform-api feature/unit suite. Controller-level Query Builder removal also passes static inspection.

The acceptance gate is still blocked because `docs/backend-query-builder-exceptions.md` does not document every remaining service-level `DB::table()` usage by exact service/method/reason. Several services still contain Query Builder calls but have no exception rows in the documentation, so Coordinator cannot distinguish approved lock/aggregate/idempotency paths from unremediated model-adoption gaps.

## Scope Reviewed

- Backend model adoption QA task and orchestrator handoff.
- Backend Develop handoff for claimed implementation scope.
- Decision record requirements for model adoption and Query Builder exception documentation.
- Platform API controllers, shared service layer, model compliance tests, and Query Builder exception documentation.
- Docker-only validation commands required by the QA task.

## Files Inspected

- `ai-agents/tasks/20260507-backend-model-adoption-remediation-qa.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-qa-task-orchestrator-handoff.md`
- `ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-model-layer.md`
- `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php`
- `apps/platform-api/app/Shared/**/*Service.php`
- `apps/platform-api/app/Models/**/*.php`

## Validation Commands

All required runtime validation was executed through Docker.

- PASS: `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing`
- PASS: `docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest`
  - `7 passed (213 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Model`
  - `7 passed (213 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Tenant`
  - `37 passed (644 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Admin`
  - `42 passed (472 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Rbac`
  - `6 passed (18 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Checkout`
  - `1 passed (30 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Reward`
  - `7 passed (321 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Growth`
  - `1 passed (4 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test`
  - `111 passed (1927 assertions)`

Note: an earlier parallel test attempt caused a database cleanup collision while `Rbac` and `Checkout` were running at the same time. `Checkout` was rerun sequentially and passed cleanly, so that earlier failure is treated as a QA-run artifact, not a product defect.

## Controller Query Builder Removal

PASS.

Static check:

```bash
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
```

Result: no matches. Platform controllers no longer call Query Builder directly.

## Controller-To-Service Partner Lookup

PASS.

`TenantReservationController` and `TenantStockSyncController` call `PartnerStoreService::partnerIdForTenant($tenantId)` instead of resolving partner IDs in controller code.

## Service Model Adoption

PARTIAL PASS.

Representative safe CRUD/read/detail/update paths now import and use Eloquent models across the shared service layer, including support access, maintenance, partner provisioning, tenant configuration, RBAC user/role/menu services, commerce, reward, growth, and partner store paths.

The compliance test verifies representative adoption, but it does not prove that every remaining service-level Query Builder call has a documented method-level exception.

## Tenant Isolation And Global Scope Review

PASS for reviewed scope.

No unexpected Eloquent global tenant scopes or soft-delete behavior were introduced in the inspected model layer. Tenant scoping remains explicit through service/controller context and local `scopeForTenant` helpers.

## API Contract And Behavior Regression Review

PASS by automated coverage.

The required focused filters and full suite passed, covering admin auth, RBAC, tenant access, checkout, reward, growth, idempotency, locks, and response-shape-sensitive feature tests.

## Remaining Query Builder Exceptions

FAIL.

The acceptance criteria require every remaining Query Builder usage to be documented with exact service, method, and reason. The current documentation omits several files that still contain `DB::table()` calls.

Evidence:

```bash
rg -l -F "DB::table(" apps/platform-api/app/Shared -g "*.php" | sort
```

Still reports, among others:

- `apps/platform-api/app/Shared/Admin/AdminOperationsService.php`
- `apps/platform-api/app/Shared/Auth/AdminAuthService.php`
- `apps/platform-api/app/Shared/Auth/CustomerAuthService.php`
- `apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php`
- `apps/platform-api/app/Shared/CentralStock/CentralStockService.php`
- `apps/platform-api/app/Shared/Idempotency/IdempotencyService.php`

But:

```bash
rg -n "CentralStockService|AdminOperationsService|AdminAuthService|CustomerAuthService|CustomerSessionResolver|IdempotencyService" docs/backend-query-builder-exceptions.md
```

Result: no matches.

This means the exception document is not aligned with the actual remaining Query Builder surface.

## Documentation Findings

FAIL.

`docs/backend-query-builder-exceptions.md` contains method-specific rows for some services, but it is incomplete. Missing rows include services with auth/session/idempotency/central-stock/admin-operations Query Builder usage.

`docs/backend-model-layer.md` was inspected and does not offset the missing exception inventory because the QA acceptance requires the exception list itself to document remaining Query Builder usage.

## Test Coverage Findings

PARTIAL PASS.

`BackendModelComplianceTest` catches controller-level `DB::table()` usage and representative service model adoption. However, it does not assert that all remaining `apps/platform-api/app/Shared/**` `DB::table()` calls have a matching row in `docs/backend-query-builder-exceptions.md`. The current documentation defect passed the focused compliance test and full suite.

## Docker Policy Findings

PASS.

All runtime validation used Docker commands. No host PHP/Artisan/Composer/Node test command was used.

## Scope Drift Findings

PASS.

No implementation files were modified by QA. This report is the only QA-owned file created during validation.

## Defects

### [P1] Query Builder exception documentation omits remaining service usage

File: `docs/backend-query-builder-exceptions.md`

The QA acceptance criteria require every remaining Query Builder use to be documented by exact service/method/reason. The doc has no entries for services that still call `DB::table()`, including `CentralStockService`, `AdminOperationsService`, `AdminAuthService`, `CustomerAuthService`, `CustomerSessionResolver`, and `IdempotencyService`. This blocks Coordinator gate approval because the remaining Query Builder surface is not auditable against the approved exception list.

### [P2] Compliance test does not guard exception-document completeness

File: `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`

The compliance test proves representative model adoption and controller Query Builder removal, but it does not fail when a service-level `DB::table()` use lacks a method-specific exception row. The missing documentation rows passed the focused compliance test and full suite.

## Known Risks And Questions

- `CentralStockService` remains heavily Query Builder-based. Some paths may be valid aggregate/lock/bulk exceptions, but the current documentation does not provide enough method-level traceability to confirm.
- The decision record called out Query Builder exception documentation as part of the remediation, so this should return to Backend Develop before Coordinator approval.

## Recommendation For Coordinator Gate Review

Do not approve this remediation yet.

Send back to Backend Develop to:

1. Add method-specific exception rows for all remaining `apps/platform-api/app/Shared/**` `DB::table()` calls, including exact reason and lock/aggregate/idempotency justification.
2. Either adopt models for remaining safe read/detail/update paths or document why each method must stay on Query Builder.
3. Add or extend compliance coverage so future omissions in `docs/backend-query-builder-exceptions.md` fail automatically.

After Backend Develop updates the remediation, route back to QA Tester for another Docker validation pass.
