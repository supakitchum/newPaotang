# M1 RBAC Menu Seeders Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m1-rbac-menu-seeders-decision.md
ai-agents/tasks/20260506-m1-rbac-menu-seeders-backend.md
ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md
ai-agents/tasks/20260506-m1-rbac-menu-seeders-qa.md
ai-agents/handoffs/20260506-m1-rbac-menu-seeders-qa-task-orchestrator-handoff.md
ai-agents/reports/20260506-m1-rbac-menu-seeders-qa-report.md
```

QA result:

```text
PASS
```

Docker validation evidence from QA:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=Rbac: PASS, 6 tests, 18 assertions
docker compose run --rm platform-api php artisan test: PASS, 15 tests, 44 assertions
```

QA reported no defects.

## Decision

Approve Milestone 1 RBAC/menu seeders slice.

The approved scope includes:

```text
default central permission seed data
default tenant permission seed data
default central menu seed data
default tenant menu seed data
idempotent seeding behavior
central/tenant scope separation for permission and menu rows
focused RBAC/menu seeder tests
```

## Approval Conditions

This approval is limited to default permission/menu definitions and tests.

Still out of scope:

```text
admin auth endpoints
admin menu API endpoints
role assignment to users
default central admin account
default tenant owner/admin accounts
partner provisioning
apps/customer changes
apps/back-office changes
stock, booking, checkout, wallet, payment, reward, support impersonation, and notification flows
admin_menus.parent_id schema/FK changes
```

## Reason

The seeders match the documented central/tenant permission and menu matrices in `docs/permissions.md`, preserve scope separation, and are idempotent under repeated seeding.

Docker runtime rules were followed.

No customer or back-office changes were reported by QA.

## Impact

Milestone 1 now has an approved platform core foundation plus approved RBAC/menu default seeders.

The next Milestone 1 backend slice can be planned by Coordinator before Orchestrator receives another task.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Coordinator
```
