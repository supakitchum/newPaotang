# Back Office CRUD Coverage Audit Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch:

```text
back-office-crud-coverage-audit
```

## Coordinator Source

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-decision.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-coordinator-handoff.md
```

## What Was Done

Created BO Develop task:

```text
ai-agents/tasks/20260509-back-office-crud-coverage-audit-bo.md
```

## Superseded Task

The prior high-level gap-analysis task is superseded by Coordinator decision:

```text
ai-agents/tasks/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-bo.md
ai-agents/handoffs/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-planning-orchestrator-handoff.md
```

BO Develop should use the CRUD coverage audit task instead.

## Routing

Next agent:

```text
BO Develop
```

## Required BO Output

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

The coverage document must include every central and tenant menu item with:

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
UI implemented status
API connected status
form/modal implemented status
QA status
gap/blocker
completion status
```

Allowed completion statuses:

```text
complete
partial
not_started
api_gap
out_of_scope
```

## Important Rules

Coordinator corrected the BO progress model:

```text
Do not count route existence alone as completion.
Do not count operations catalog entry alone as completion.
Do not count a visible menu as completion.
Do not count backend OpenAPI availability as BO completion unless BO calls it and QA verifies the workflow.
QA must test real menus and workflows.
```

Backend remains frozen for BO:

```text
No backend/API contract changes without Coordinator approval.
If BO finds API gaps, report them instead of editing backend.
```

Customer frontend remains frozen.

## Validation Plan Given To BO

Docker-only application commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan route:list
```

Local static reads such as `git status --short`, `rg`, `sed`, and `ls` are allowed.

## Commit Expectation

Because BO Develop will create `docs/back-office-crud-coverage.md`, the Code Agent Commit Rule applies. BO Develop must commit only scoped files and record the commit hash in its handoff.

## Next Step After BO Handoff

Route to:

```text
Coordinator
```

Coordinator must recalculate BO percentage from the matrix and approve the first implementation priority before broad BO implementation continues.

## Next Agent

BO Develop
