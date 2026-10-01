# M8 Affiliate, Agent, Reports, Settlement Coordinator Handoff

## Agent

Coordinator

## Task

Start the next main-plan implementation slice after M7 Reward Result Engine approval.

## What Was Done

Coordinator reviewed the execution plan, M7 approval decision, current Board, OpenAPI M8 admin/report/settlement endpoints, ERD and event references, permission mappings, affiliate partner docs, AI work instructions, and current platform-api structure.

Coordinator selected:

```text
m8-affiliate-agent-reports-settlement
```

Coordinator recorded the decision:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md
```

The approved slice targets Backend Develop and `apps/platform-api/**`. It implements tenant agent/affiliate/commission/payout APIs, commission calculation foundation, report/export job foundation, and central settlement APIs.

## Files Changed

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-coordinator-handoff.md
ai-agents/BOARD.md
```

## Required Orchestrator Action

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
```

Target Agent:

```text
Backend Develop
```

The task should cover:

```text
agent schema/API
agent quotas
affiliate accounts/programs/links/attributions
commission rules and transactions
command/service-driven commission calculation
affiliate payouts
tenant and central reports
report export jobs
central partner settlements
tests
```

## Validation

Coordinator review only. No application runtime commands were run.

Read-only evidence reviewed:

```text
document/15_EXECUTION_PLAN.md
document/08_IMPLEMENTATION_ROADMAP.md
document/03_PARTNER_STORE_MODULE.md
document/06_AFFILIATE_PARTNER.md
document/09_AI_WORK_INSTRUCTIONS.md
docs/openapi.yaml
docs/erd.md
docs/status-enums.md
docs/events.md
docs/permissions.md
docs/docker-runtime-policy.md
ai-agents/BOARD.md
ai-agents/decisions/20260507-m7-reward-result-engine-approval-decision.md
apps/platform-api routes/controllers/services/tests listing from recent context
```

Required Docker-only validation for Backend Develop:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Agent
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test --filter=Settlement
docker compose run --rm platform-api php artisan test
```

## Known Risks

```text
OpenAPI generic AdminResource shapes need stable documented fields in the Backend handoff.
Real external payout/bank transfer provider integration is out of scope.
Real export file storage/CDN can be deferred behind export job contract behavior if needed.
Customer/browser affiliate attribution may need a later customer slice; this task should still create the backend foundation and service hooks.
Back-office UI is still not part of this slice.
Docker-only runtime remains mandatory.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator
