# Decision: virtual-stock-topup-cleanup QA Review

Date: 2026-05-19

Decision: ACCEPT QA AS PASS WITH RISK

## Scope Reviewed

Coordinator reviewed QA report:

```text
ai-agents/reports/20260519-virtual-stock-topup-cleanup-qa-report.md
```

QA validated implementation commits:

```text
Backend: c61b8ef5bd6612d1734616acb8a6f1d259e4d5c4
Back-office: c1e92e26c9d98dae6eab71c0f722d702d4a65565
QA report HEAD after canonical import: 5a55817125fec64c6177f742b19896165be9a0a6
```

Covered scope:

```text
virtual stock top-up creates additive supply instead of replacing profile/counters
stock generate no longer exposes seed and no longer exposes physical/quota modes
idempotency replay and changed-payload conflict behavior
customer availability increases after top-up where limits allow
reservation lazily materializes real tickets
stock generation detail shows owner/no-agent and real image data only when present
coverage limits cannot exceed generated combined supply
Stock Pattern Coverage receives realtime websocket updates
two-browser realtime behavior after top-up
runtime restore/login smoke after QA
```

## QA Result

Accepted as PASS WITH RISK.

Evidence from QA:

```text
git diff --check passed
Docker build platform-api/back-office passed
test DB migrate:fresh --seed used APP_ENV=testing, DB_DATABASE=newpaotang_test, and --env=testing
Tests\Feature\CentralStockTest passed with 144 assertions
Tests\Feature\VirtualStockRealtimeTest passed with 227 assertions
OpenAPI YAML parse passed
Back-office lint/test/build passed
artifact secret scan passed
runtime db:seed/platform:smoke/login smoke passed after restore
```

QA reported no implementation defect.

## Accepted Risks

- PHPUnit suites pass but emit dotenv warnings for missing `/var/www/html/.env` in the Docker test container.
- Customer `/login` initially returned 500 during runtime restore because a long-running customer dev server had stale Nuxt/Nitro state. Recreating the customer container restored `/login` to 200.
- QA used one non-mutating host-side PHP hash helper while preparing a customer auth fixture. It did not mutate application state and did not write token material to artifacts.
- QA evidence was first executed before the canonical-worktree policy was fully enforced. The report and artifacts are now committed from `/Users/supakit/WorkSpace/www/newPaotang`. Future QA must execute from the canonical worktree unless Coordinator explicitly authorizes otherwise.

## Coordinator Decision

No remediation task is required for this QA result.

The `virtual-stock-topup-cleanup` scope is closed from Coordinator review. Future work may start from `develop` after pulling the latest commit.

## Mandatory Carry-Forward Rule

Before any new task starts, every agent must run the canonical start gate from:

```text
ai-agents/decisions/20260519-agent-canonical-worktree-policy-decision.md
```

Agents must also commit and push their completed handoff/report artifacts before the next agent starts, so no agent reads stale or missing files.

## Next Agent

Coordinator
