# Affiliate BO Usability Ref Links QA Review Decision

## Decision

Approve `affiliate-bo-usability-ref-links` as QA PASS with documented limitations.

## Coordinator

Coordinator

## Date

2026-05-22

## Evidence Reviewed

```text
QA report: ai-agents/reports/20260522-affiliate-bo-usability-ref-links-qa-report.md
QA dispatch handoff: ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-qa-dispatch-handoff.md
HEAD under QA: b54502247b9f974ade2a073d96cb233992a55e73
origin/develop under QA: b54502247b9f974ade2a073d96cb233992a55e73
```

## Result

QA found no implementation defect.

Approved coverage includes:

```text
Backend short 6-character Base62 affiliate/link codes
Backend canonical /?ref=CODE URL responses
Tenant-scoped ref resolution and inactive/cross-tenant rejection
Last-click 30-day attribution behavior
Paid-order commission conversion from attribution
BO Affiliate/Growth menus remain registered
BO Affiliate/Growth forms avoid raw JSON for normal workflows
BO Affiliate/Growth detail views avoid raw JSON dumps
Customer ?ref capture, tenant-scoped cookie, last-click behavior, and apply wiring
Runtime restore/login smoke after QA
```

## Accepted Limitations

These limitations are accepted for this gate and should be considered residual QA risk, not blockers:

```text
Authenticated customer browser e2e for /affiliate register/apply/checkout was not executed because safe seeded customer credentials were unavailable.
Interactive BO browser session was not executed because Playwright/browser automation was not available in the QA runtime.
Customer-affiliate account attempting BO/admin APIs was not run as authenticated customer runtime smoke due missing safe seeded customer credentials.
```

Backend PHPUnit, frontend static guardrails, runtime API smoke, and runtime restore/login smoke are sufficient for this pass decision.

## Dirty Worktree Note

The QA report notes pre-existing dirty implementation files from prior Hotfix work. QA did not stage, commit, push, or modify implementation code. Coordinator also must not stage/revert those unrelated dirty files as part of this decision.

## Next Agent

None
