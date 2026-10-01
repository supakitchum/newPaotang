# m5-customer-auth-host-isolation QA Task Handoff

## Agent

Orchestrator

## Task

Create a focused QA Tester task after Backend Develop completed the M5 customer auth/profile host-isolation revision.

## What Was Done

- Confirmed the Backend revision handoff exists:
  - `ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md`
- Read the Backend revision task:
  - `ai-agents/tasks/20260507-m5-customer-auth-host-isolation-backend.md`
- Read current Board status.
- Read the Backend revision handoff and confirmed Backend reports the focused D1/P1 fix is complete.
- Backend reported:
  - `customer.auth` middleware resolves request tenant from `Host`
  - tenant A customer token through tenant B host returns `permission_denied` before controller execution
  - `CustomerSessionResolver` supports expected-tenant resolution
  - cross-tenant mismatch does not read profile data or touch `last_used_at`
  - failed cross-tenant logout does not revoke source tenant session
  - same-host auth/profile/logout behavior remains unchanged
- Backend reported Docker-only validation success:
  - `CustomerAuth`: PASS, 2 tests, 40 assertions
  - `CustomerCheckout`: PASS, 1 test, 30 assertions
  - `CustomerTopup`: PASS, 1 test, 21 assertions
  - Full `platform-api` suite: PASS, 80 tests, 1140 assertions
- Created a focused QA Tester task:
  - `ai-agents/tasks/20260507-m5-customer-auth-host-isolation-qa.md`
- Kept Orchestrator work limited to `ai-agents/tasks/**` and `ai-agents/handoffs/**`.
- Did not edit app code, source-of-truth docs, reports, decisions, or Board.

## Files Changed

```text
ai-agents/tasks/20260507-m5-customer-auth-host-isolation-qa.md
ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-qa-task-orchestrator-handoff.md
```

## Validation

Read/inspection commands run:

```sh
test -e ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md; echo $?
sed -n '1,460p' ai-agents/tasks/20260507-m5-customer-auth-host-isolation-backend.md
sed -n '1,360p' ai-agents/BOARD.md
sed -n '1,520p' ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md
test -e ai-agents/tasks/20260507-m5-customer-auth-host-isolation-qa.md; echo $?
test -e ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-qa-task-orchestrator-handoff.md; echo $?
```

Application runtime validation was not run by Orchestrator.

Backend reported these Docker-only validation results:

```text
CustomerAuth: PASS, 2 tests, 40 assertions
CustomerCheckout: PASS, 1 test, 30 assertions
CustomerTopup: PASS, 1 test, 21 assertions
Full platform-api suite: PASS, 80 tests, 1140 assertions
```

Post-create verification commands run:

```sh
sed -n '1,420p' ai-agents/tasks/20260507-m5-customer-auth-host-isolation-qa.md
sed -n '1,320p' ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-qa-task-orchestrator-handoff.md
git status --short ai-agents/tasks/20260507-m5-customer-auth-host-isolation-qa.md ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-qa-task-orchestrator-handoff.md
```

## Known Risks

```text
M5 Checkout, Wallet, Payment Contract, Sold Sync remains unapproved until focused QA passes and Coordinator approves Gate review.
The active blocker is limited to customer auth/profile host/session tenant isolation.
Payment provider behavior remains contract/stub based and sold sync remains explicit command/service based; those are accepted M5 risks, not active blockers for this focused QA.
Maintenance blocking is now applied in customer auth middleware for auth/profile/logout endpoints while other customer bearer endpoints retain their existing controller-specific maintenance behavior; QA should verify this is consistent enough for this revision and report residual risk if needed.
The workspace already contains unrelated dirty/untracked files from multi-agent workflow; QA should report scope drift only if this revision changed forbidden paths.
```

## Proposed Board Update

```text
Active Task: 20260507-m5-customer-auth-host-isolation-qa
Coordinator: handoff_sent
Orchestrator: handoff_sent
Backend Develop: handoff_sent
QA Tester: ready
```

## Next Agent

QA Tester
