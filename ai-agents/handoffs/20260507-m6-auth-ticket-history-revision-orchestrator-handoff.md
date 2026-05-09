# m6-auth-ticket-history-revision Orchestrator Handoff

## Agent

Orchestrator

## Task

Receive the Coordinator M6 QA review decision and create one focused Customer Develop revision task for D1/P2 and D2/P2.

## What Was Done

- Read current Board status.
- Listed latest decisions, handoffs, tasks, and reports.
- Read the Coordinator M6 QA review decision:
  - `ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md`
- Read the Coordinator M6 QA review handoff:
  - `ai-agents/handoffs/20260507-m6-customer-api-integration-qa-review-coordinator-handoff.md`
- Read the M6 QA report:
  - `ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md`
- Confirmed no existing focused revision Customer task/handoff file existed.
- Read `apps/customer/package.json` and confirmed Nuxt remains `3.11.2` and scripts are `dev`, `build`, `generate`, and `preview`.
- Confirmed the approved revision boundary files currently exist.
- Read the Orchestrator task template and Docker runtime policy.
- Created the focused Customer Develop revision task:
  - `ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md`
- Kept Orchestrator work limited to `ai-agents/tasks/**` and `ai-agents/handoffs/**`.
- Did not edit app code, source-of-truth docs, reports, decisions, or Board.

## Files Changed

```text
ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md
ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-orchestrator-handoff.md
```

## Validation

Read/inspection commands run:

```sh
sed -n '1,420p' ai-agents/BOARD.md
rg --files ai-agents/decisions ai-agents/handoffs ai-agents/tasks ai-agents/reports | sort | tail -620
git status --short ai-agents/BOARD.md ai-agents/decisions ai-agents/handoffs ai-agents/tasks ai-agents/reports apps/customer docs/customer-api-integration-map.md docs/buy-flow-adapter-contract.md
sed -n '1,720p' ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md
sed -n '1,560p' ai-agents/handoffs/20260507-m6-customer-api-integration-qa-review-coordinator-handoff.md
sed -n '1,720p' ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
test -e ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md; echo $?
test -e ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-orchestrator-handoff.md; echo $?
sed -n '1,220p' apps/customer/package.json
rg --files apps/customer/composables apps/customer/pages apps/customer/middleware apps/customer/plugins | sort | rg '(^apps/customer/composables/(usePlatformApi|useAuth|useUserTickets)\.ts$|^apps/customer/pages/tickets/history\.vue$|^apps/customer/pages/(login|profile)\.vue$|^apps/customer/middleware/init\.global\.ts$|^apps/customer/plugins/axios\.ts$)'
sed -n '1,260p' ai-agents/prompts/orchestrator-task-template.md
sed -n '1,260p' docs/docker-runtime-policy.md
```

Application runtime validation was not run by Orchestrator.

QA reported:

```text
docker compose run --rm customer npm run build: PASS
M6 result: CONDITIONAL PASS
D1/P2: auth lifecycle integration omits server me/refresh/logout
D2/P2: ticket history page never reaches GET /customer/tickets/history from mounted flow
```

Post-create verification commands run:

```sh
sed -n '1,620p' ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md
sed -n '1,360p' ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-orchestrator-handoff.md
git status --short ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-orchestrator-handoff.md
```

## Known Risks

```text
This revision is intentionally narrow; Customer Develop should not change checkout multi-reservation behavior, reward behavior, SEO page override behavior, LINE continuation behavior, backend code, package versions, or UI design.
Auth refresh should only be implemented if existing customer auth state has enough refresh-token material; no insecure refresh loop should be invented.
Ticket history historical draw grouping metadata remains backend-contract limited; the required fix is direct history endpoint reachability plus safe optional metadata fallback.
Docker-only runtime remains mandatory; no npm/Nuxt commands may run on host.
The workspace already contains unrelated dirty/untracked files from multi-agent workflow; Customer Develop should avoid reverting or touching unrelated changes.
```

## Proposed Board Update

```text
Active Task: 20260507-m6-auth-ticket-history-revision-customer
Coordinator: handoff_sent
Orchestrator: handoff_sent
Customer Develop: ready
QA Tester: waiting_customer_handoff
```

## Next Agent

Customer Develop
