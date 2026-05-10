# Back Office P1 Tenant Orders Customer Context Remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator reviewed the P1 money/stock BO workflow QA report and accepted the QA evidence, but the P1 slice is not approved yet.

Open remediation:

```text
back-office-p1-tenant-orders-customer-context-remediation
```

Source decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit: 934a48013b8366430b34ac624de3dbdb64831cca
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

Sync to the latest `origin/develop` before implementation. This Orchestrator dispatch may advance `develop` with task and handoff files only.

Known unrelated dirty files may already exist in the shared workspace. Do not modify, stage, commit, or clean them as part of this task. If new or overlapping dirty files appear in BO-owned files before you edit, stop and report them to Orchestrator.

Known unrelated dirty files from Coordinator/QA context:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
apps/platform-api/storage/framework/views/*.php
```

## Objective

Fix the BO tenant orders customer context mapping so operators can safely review customer/member context before order update, cancel, and refund actions.

QA found:

```text
Tenant order list renders Customer as "-"
Update/Cancel/Refund confirmations do not include customer context
```

Root cause from Coordinator:

```text
The admin order API response already supplies customer data as a nested customer object.
The BO catalog reads customer_id as if it were top-level.
This is a BO mapping/context issue, not a backend contract gap.
```

Backend remains frozen. Customer frontend remains frozen.

## Required Remediation

Update tenant orders in the BO admin operations catalog and related BO UI only.

Required behavior:

```text
read customer context from the nested customer object returned by the admin order API
preserve compatibility with top-level customer/member identifiers if they exist
show customer/member context in the tenant orders list Customer column
show enough customer/member context in order detail and Update/Cancel/Refund confirmations
preserve order id, order status, payment/status amount context, and tenant scope context
keep typed controls and reason guards intact
do not submit destructive or financial actions without the existing required reason behavior
```

Minimum acceptable customer context when available:

```text
customer id or member id
customer display name or phone/email
order id
order status
payment/status amount context
tenant scope remains clear
```

If the nested `customer` payload still cannot provide enough context for safe operator decisions, stop and report the exact missing API fields to Orchestrator. Do not change backend.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
ai-agents/tasks/20260510-back-office-p1-money-stock-crud-workflows-bo.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/package.json
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminDataTable.vue
apps/back-office/components/AdminModal.vue
apps/back-office/pages/admin/tenant/[...slug].vue
```

QA evidence artifacts:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-from-menu.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-update-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-cancel-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-refund-modal.snapshot.txt
```

Backend/OpenAPI files are read-only references only.

## Allowed Files

Allowed implementation scope:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo-handoff.md
```

Update `docs/back-office-crud-coverage.md` only if the `tenant:orders` QA/remediation notes need to change.

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

Do not use the Customer frontend for this remediation. Customer UI regression is out of scope unless Coordinator explicitly adds it later.

Do not route directly to QA. BO must hand back to Orchestrator.

## Implementation Notes

Expected primary area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

QA pointed at the old behavior around:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts:168
apps/back-office/composables/useAdminOperationsCatalog.ts:286-328
```

Look for tenant order columns, row summary/context helpers, and `moneyActionContext`. Prefer a small reusable formatter/helper if it reduces duplicated nested customer fallback logic. Keep existing Meno/admin operation catalog patterns.

## Required Validation

Application commands must be Docker-only.

Run the focused checks that fit the changed scope:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, or migrations.

Local static reads are allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Evidence To Prepare For QA

After remediation, QA will retest with API-first customer-related workflow validation. Prepare BO handoff notes that make this easy.

Include:

```text
implementation commit hash
changed files
exact customer/member fields now read from nested customer data
tenant order list customer column behavior
order detail customer context behavior
Update modal customer context behavior
Cancel modal customer context behavior
Refund modal customer context behavior
reason guard behavior remains required
Docker validation commands and results
confirmation that no backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decisions, tasks, or reports files were changed
known unrelated dirty files left untouched
```

## Handoff Requirement

Write:

```text
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo-handoff.md
```

Then commit and push scoped BO changes so other agents can see them.

Next agent:

```text
Orchestrator
```
