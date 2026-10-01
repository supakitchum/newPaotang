# back-office-p2-partner-billing-alerts-write-submission-qa - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator accepted the P2 partner/billing/alerts QA result as a non-destructive workflow pass with no new implementation defects, but did not promote the six completion-candidate rows to complete because browser create/update/action writes were not submitted.

Open focused QA task:

```text
back-office-p2-partner-billing-alerts-write-submission-qa
```

Coordinator source:

```text
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
```

Prior Orchestrator/BO/QA context:

```text
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-qa.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-qa-task-orchestrator-handoff.md
```

## Objective

Perform focused write-submission QA for the six P2 completion-candidate rows by submitting safe create/update/action mutations through real authenticated BO central menu workflows.

Capture before/after API evidence and browser evidence for each submitted write/action. If this focused QA passes, Coordinator can promote the six rows to `complete`, moving official BO completion to 17/56 menus, or 30.4%.

## Implementation Under Test

Implementation commit:

```text
3c6750af9448cc72e56167231b750046ee6e6c19
```

BO handoff commit:

```text
3c33e44b515a1ddb118061e1dcd7c828f4e256e0
```

Prior non-destructive QA head:

```text
3c7d5796d374e008156f62f06b073908e1a78e93
```

Coordinator review/gate commits:

```text
02e43d2
15bf36dd737bb0ce20194b6a92e529e5c1fb216d
```

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-qa.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
```

Prior QA evidence:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/
```

## Current Dirty Workspace Note

At Orchestrator dispatch time, these unrelated local files were dirty and must not be edited, staged, committed, cleaned, or included as QA scope:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
```

If they are still dirty in QA's worktree, record them as unrelated existing changes in the QA report and leave them untouched.

## Write-Submission Scope

Test these six completion-candidate rows:

```text
central:partners
central:partner_provisioning
central:partner_quotas
central:billing_plans
central:alert_policies
central:alert_events
```

Out of scope for this focused write-submission QA:

```text
central:partner_monitoring
central:partner_usage
```

Those two remain partial permission/UX decision items because seeded menus are view-only while backend PATCH routes require manage permissions. Do not expose or test update workflows for them in this task.

## Required Write Checks

Use local Docker QA fixture data only. Prefer creating dedicated QA fixture records with unique ids/names containing:

```text
p2_write_qa_20260510
```

Do not mutate real, shared, production, staging, or unknown user data. Do not copy bearer tokens or secrets into artifacts.

For each row, capture before/after API evidence and browser evidence.

### central:partners

Submit through the real central menu:

```text
create partner
update the QA-created partner
suspend the QA-created partner, or a dedicated safe QA partner if create response is not suspendable
```

Evidence must include:

```text
before API list/detail where applicable
submitted browser form/modal evidence
after API detail showing created/updated/suspended state
reason guard behavior for suspend
```

### central:partner_provisioning

Submit through the real central menu:

```text
provision a dedicated safe QA partner fixture
suspend that QA partner fixture if the provisioned state supports it safely
```

Evidence must include:

```text
before API partner detail
submitted provision browser evidence
after API partner/detail evidence showing provisioned or expected state
suspend modal/action evidence if executed
exact API/browser response if validation blocks submission
```

### central:partner_quotas

Submit through the real central menu:

```text
create partner quota
update the QA-created quota
```

Evidence must include:

```text
before API list
submitted typed create/update browser evidence
after API list/detail showing quota values changed
```

### central:billing_plans

Submit through the real central menu:

```text
create billing plan
update the QA-created billing plan
```

Evidence must include:

```text
before API list
submitted typed create/update browser evidence
after API list/detail showing fee/currency/status/features/limits values
```

### central:alert_policies

Submit through the real central menu:

```text
create alert policy
update the QA-created alert policy
```

Evidence must include:

```text
before API list
submitted typed create/update browser evidence
after API list/detail showing policy/severity/status/config values
```

### central:alert_events

Submit through the real central menu against a safe QA-created alert event:

```text
acknowledge alert event
resolve alert event
```

Evidence must include:

```text
before API detail
submitted acknowledge/resolve browser modal evidence
after API detail showing acknowledged/resolved state or expected status transition
reason guard behavior
```

## Failure Handling

If any write path fails due validation, payload mismatch, backend API response, permission mismatch, missing seeded data, or UI submit behavior:

```text
record the exact row/action
capture sanitized request payload shape where available
capture sanitized response/status/error text
capture browser evidence
state likely owner: BO, Backend, Coordinator permission/UX decision, or unclear
do not patch implementation
do not change backend/OpenAPI/permissions
```

## Out Of Scope

Do not:

```text
edit implementation code
edit apps/back-office/**
edit apps/platform-api/**
edit apps/customer/**
edit docs/**
edit docs/openapi.yaml
edit compose.yaml
edit .github/**
edit ai-agents/BOARD.md
edit ai-agents/decisions/**
edit ai-agents/tasks/**
edit ai-agents/handoffs/**
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit or Meno legal/license closure
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
copy real secrets, tokens, bearer tokens, customer data, or private keys into artifacts
change permission/security semantics
use Customer frontend
```

## File Ownership

Can edit:

```text
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/**
```

Must not edit:

```text
apps/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ops/**
scripts/**
load-tests/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-report.md and ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `3c6750af9448cc72e56167231b750046ee6e6c19`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Prepare dedicated safe QA fixture records for write submission.
8. Capture before API evidence for each target row.
9. Submit writes/actions through real authenticated BO central menus.
10. Capture browser evidence for submitted forms/modals and success/error states.
11. Capture after API evidence for each target row.
12. Verify no Customer frontend was used.
13. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Local static reads/checks are allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, migrations, queues, or scheduler commands.

## Expected QA Output

Write:

```text
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
before/after API evidence summary
browser write-submission evidence summary
row-by-row result for all six write-submission rows
exact failure payload/response details for any failing write path
whether each row is a completion candidate after write-submission QA
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
```

## Routing

Next agent after QA:

```text
Coordinator
```

If this focused QA passes, Coordinator can decide whether the six rows count toward BO completion. If QA finds defects, permission mismatches, or backend contract blockers, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.
