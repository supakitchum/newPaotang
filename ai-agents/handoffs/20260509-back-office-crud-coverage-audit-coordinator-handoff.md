# Back Office CRUD Coverage Audit Coordinator Handoff

## Agent

Coordinator

## Task

Open Back Office CRUD Coverage Audit and replace the earlier high-level BO gap-analysis plan.

## What Was Done

Recorded the decision:

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-decision.md
```

Updated the Board active task to:

```text
back-office-crud-coverage-audit
```

## Coordinator Assessment

Prior Back Office percentage is no longer valid.

Reason:

```text
layout/auth/dashboard/menu/catalog/generic operations pages exist,
but BO completeness must be based on end-to-end CRUD/API workflow coverage per menu.
```

Coordinator will recalculate BO percentage only after the matrix exists in:

```text
docs/back-office-crud-coverage.md
```

## Required Audit Output

BO Develop must build a matrix for every central and tenant menu from backend menu/permissions/OpenAPI/current BO code.

Each row must include:

```text
menu key
frontend route
required permission
list API
detail API
create API
update API
delete/action APIs
export API
UI implemented
API connected
form/modal implemented
QA status
gap/blocker
completion status
```

## Rules

```text
Do not count route/catalog/menu existence as completion.
Count only working end-to-end CRUD/API workflows.
Backend contract is frozen for BO.
If BO finds backend API gaps, report them to Coordinator instead of editing backend.
Customer frontend remains frozen.
All BO runtime/build/test commands must use Docker.
QA must test real menus and workflows.
```

## Validation

No application runtime command was required for this Coordinator update.

## Next Agent

Orchestrator

## Required Orchestrator Action

Create a focused BO Develop task:

```text
back-office-crud-coverage-audit
```

Expected deliverable:

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

After BO handoff, route back to Coordinator so Coordinator can recalculate BO percentage and approve the first implementation priority.
