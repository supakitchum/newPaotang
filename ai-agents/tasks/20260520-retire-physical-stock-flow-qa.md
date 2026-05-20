# retire-physical-stock-flow-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
retire-physical-stock-flow
```

Backend Develop and BO Develop have completed and pushed their implementation handoffs. QA Tester is now the next agent.

## QA Start Gate

QA Tester must start from the canonical worktree only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or testing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
```

Stop and report a blocker to Coordinator if:

```text
git top-level is not /Users/supakit/WorkSpace/www/newPaotang
the worktree is under .codex/worktrees/*, newPaotang-qa-*, newPaotang-orch-*, newPaotang-bo-*, or detached HEAD
git merge --ff-only origin/develop fails
there are uncommitted changes that QA did not create and they overlap this task
```

The QA report must include the worktree path and HEAD used for testing.

Do not start until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
```

## Objective

Validate the active physical stock flow is retired from API and BO while virtual stock generation/allocation/materialization still works:

```text
physical/quota generation payloads are rejected
requested_count allocation payload is rejected
virtual allocation creates snapshot/distribution without physical bulk allocation rows
partner/customer visibility reads virtual distribution/generated counts
partner-sync/allocations returns virtual allocation metadata
Partner Quotas BO active navigation/write UI is retired
stale Partner Quotas deep link shows retired guidance or otherwise cannot write
BO allocation and stock generation remain virtual-only
runtime restore/login smoke passes
```

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
ai-agents/decisions/20260520-coordinator-role-rules-decision.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
docs/openapi.yaml
ai-agents/tasks/20260520-retire-physical-stock-flow-backend.md
ai-agents/tasks/20260520-retire-physical-stock-flow-bo.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
```

Relevant sections:

```text
docs/coordinator-agent-handoff.md#2026-05-20-retire-physical-stock-flow
docs/virtual-stock-realtime.md#retire-physical-stock-flow
```

## Commits Under Test

Backend:

```text
9876c9226410becc13136dfc7308bb3b721b1137
c2774dc186f262b94ddac8130c458cc7b7a6101b
```

BO:

```text
3d46de9e5f656dcc8e480dc338302219315ea783
40e03dc1edfedb2cb81db4b00b20f8489c67cba7
```

## Scope

Validate:

```text
POST /admin/central/stock/generate rejects quota_random/quota/physical and legacy physical fields
POST /admin/central/allocations rejects requested_count
POST /admin/central/allocations accepts allocation_percent
virtual allocation writes partner_stock_allocations and stock_partner_distributions
virtual allocation does not bulk assign stock_items
virtual allocation does not create partner_stock_allocation_items as source-of-truth rows
customer search/reservation visibility reflects stock_partner_distributions
reservation still lazily materializes stock_items/local_stock_items
GET /partner-sync/allocations returns virtual allocation/distribution metadata
GET /admin/central/partner-quotas is legacy read-only
POST/PATCH /admin/central/partner-quotas returns 410 retired_flow
BO active navigation no longer shows Central Partner Quotas
BO operation catalog does not show Partner Quotas create/update write actions
stale /admin/central/partner-quotas deep link shows retired guidance or cannot present retired writes as active success paths
BO retired_flow/410 errors show retired workflow copy
BO allocation create has no requested_count and still uses allocation_percent
BO Stock Generation remains virtual_profile only and retired physical fields are not visible
BO stock coverage/remaining stock actions stay scoped to virtual distribution-backed views
```

## Out Of Scope

```text
fixing implementation defects directly
editing implementation code unless Coordinator explicitly assigns QA fixture/test-code work
wiping runtime DB newpaotang
dropping legacy tables
```

## QA Database Isolation Guardrail

Runtime DB `newpaotang` must not be wiped.

All destructive database commands must explicitly target test DB `newpaotang_test`:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend tests must run with:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

Do not run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` against runtime DB `newpaotang`.

## Required Evidence

QA report must include:

```text
worktree path
current HEAD and origin/develop
Backend and BO commit hashes under test
test DB isolation evidence with DB_DATABASE=newpaotang_test
physical/quota generation rejection evidence
requested_count allocation rejection evidence
allocation_percent success evidence
virtual allocation snapshot/distribution evidence
no physical bulk stock_items/partner_stock_allocation_items allocation evidence
customer/partner visibility evidence from virtual distribution/generated counts
lazy materialization evidence for reservation-created stock_items/local_stock_items
partner-sync virtual allocation metadata evidence
Partner Quotas read-only/retired API evidence
Partner Quotas 410 retired_flow write evidence
BO navigation evidence showing Partner Quotas absent/disabled
BO stale deep-link retired guidance evidence
BO retired_flow warning display evidence if feasible
BO allocation create no requested_count evidence
BO Stock Generation virtual-only evidence
BO lint/test/build evidence
backend focused test evidence
runtime restore/login smoke evidence
defects with owner recommendation
```

## Validation Commands

Use Docker commands only.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerSyncAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PublicStockSearchTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerQuotaTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=LocalStockSyncTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

Manual/API workflow evidence may use Docker-hosted runtime and HTTP/browser checks. Prefer authenticated BO workflow evidence for navigation/deep-link checks.

Mandatory runtime restore/login smoke before clean PASS:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260520-retire-physical-stock-flow-qa-report.md
```

Result must be one of:

```text
PASS
FAIL
PASS WITH RISK
BLOCKED
```

The report must include the required `Runtime Restore / Login Smoke` section from `ai-agents/workflow/handoff-protocol.md`.

Must include the next agent:

```text
Coordinator
```

## Next Agent

QA Tester
