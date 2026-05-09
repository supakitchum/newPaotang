# M1 Platform Core QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/tasks/20260506-m1-platform-core-backend.md
ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md
ai-agents/tasks/20260506-m1-platform-core-qa.md
ai-agents/handoffs/20260506-m1-platform-core-qa-task-orchestrator-handoff.md
ai-agents/reports/20260506-m1-platform-core-qa-report.md
```

QA result:

```text
PASS WITH RISKS
```

QA validation passed Docker-only build/install/migration/test commands, and confirmed that `apps/customer` and `apps/back-office` were not changed.

QA found one actionable defect:

```text
D1 - Missing automated coverage for inactive tenant and inactive partner host resolution
```

The implementation exposes safe `tenant_inactive` behavior for inactive tenant/partner states, but automated regression tests currently cover only unknown host, inactive domain, and active host success.

## Decision

Revise before approval.

Do not approve Milestone 1 platform core foundation yet. The remaining work is small and should stay inside Backend Develop ownership.

## Required Revision

Orchestrator must create a Backend Develop revision task to add automated tests for:

```text
inactive partner_tenants.status returns tenant_inactive
inactive partners.status returns tenant_inactive
```

The implementation logic should not be changed unless the new tests reveal a real behavior bug.

## Orchestrator Instruction

Create a revision task brief for Backend Develop:

```text
ai-agents/tasks/20260506-m1-platform-core-tenant-resolution-tests-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

Scope:

```text
apps/platform-api/tests/Feature/TenantResolutionTest.php
```

Optional scope only if tests reveal a behavior bug:

```text
apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php
```

Out of scope:

```text
Do not edit apps/customer.
Do not edit apps/back-office.
Do not modify business flows.
Do not alter source-of-truth docs.
Do not add default permission/menu seeders in this revision.
Do not change admin_menus.parent_id schema in this revision.
```

Validation commands must use Docker only:

```sh
docker compose run --rm platform-api php artisan test --filter=TenantResolutionTest
docker compose run --rm platform-api php artisan test
```

Backend Develop must write handoff to:

```text
ai-agents/handoffs/20260506-m1-platform-core-tenant-resolution-tests-backend-handoff.md
```

Then Orchestrator should create a focused QA task for QA Tester to rerun the relevant Docker validation and write a follow-up QA report.

## Coordinator Answers To Backend Questions

Question:

```text
Should the next Backend task seed default central/tenant permissions and menus, or should seeding wait for partner provisioning in Milestone 2?
```

Decision:

```text
Do not include permission/menu seeding in this revision. Treat default central/tenant permission and menu seeding as a separate Milestone 1 follow-up after the current foundation is approved.
```

Question:

```text
Should admin_menus.parent_id be made a strict self-referencing FK in a follow-up migration after menu hierarchy behavior is finalized?
```

Decision:

```text
Do not change admin_menus.parent_id in this revision. Keep it as a documented schema risk and revisit in a later RBAC/menu hierarchy task after hierarchy behavior is finalized.
```

## Reason

Tenant isolation is a critical project rule. The inactive tenant and inactive partner paths are security-adjacent safety behavior, so they should have automated coverage before Coordinator approval.

The missing coverage is narrow and does not require a scope or architecture change.

## Impact

Current Milestone 1 platform core foundation remains unapproved until the revision and focused QA pass.

No customer flow changes are approved.

No back-office work is approved.

No new business module work is approved.

## Follow-Up Owner

```text
Orchestrator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Orchestrator
```
