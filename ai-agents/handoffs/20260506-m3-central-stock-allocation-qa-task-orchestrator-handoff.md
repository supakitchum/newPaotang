# m3-central-stock-allocation QA Task Handoff

## Agent

Orchestrator

## Task

Create a QA Tester task after Backend Develop completed the M3 Central Stock And Allocation backend handoff.

## What Was Done

- Read the Orchestrator task template.
- Read the M3 Coordinator decision and Backend task.
- Read the Backend Develop handoff at `ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md`.
- Confirmed Backend reported Docker-only validation success:
  - `migrate:fresh --seed --env=testing`: PASS
  - `CentralGame`: PASS, 1 test, 25 assertions
  - `CentralStock`: PASS, 1 test, 32 assertions
  - `PartnerQuota`: PASS, 1 test, 24 assertions
  - `CentralAllocation`: PASS, 1 test, 46 assertions
  - Full `platform-api` suite: PASS, 61 tests, 672 assertions
- Created a QA Tester task for M3 validation.
- Kept Orchestrator work limited to `ai-agents/tasks/**` and `ai-agents/handoffs/**`.
- Did not edit app code or source-of-truth docs.

## Files Changed

```text
ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-task-orchestrator-handoff.md
```

## Validation

Read/inspection commands run:

```sh
sed -n '1,260p' ai-agents/prompts/orchestrator-task-template.md
sed -n '1,260p' ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
sed -n '1,320p' ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
test -e ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md; echo $?
test -e ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-task-orchestrator-handoff.md; echo $?
sed -n '1,360p' ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
```

Post-create verification commands run:

```sh
sed -n '1,360p' ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md
sed -n '1,260p' ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-task-orchestrator-handoff.md
git status --short ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-task-orchestrator-handoff.md
```

## Known Risks

```text
Backend handoff states stock import/export are synchronous/skeleton behavior, which is allowed for this slice but needs QA confirmation against the contract.
Backend handoff states broad idempotency persistence/replay/conflict semantics are out of scope; QA should verify the approved narrower behavior and header validation.
Backend handoff states allocation status starts pending after central rows are allocated because partner-local sync consumer is Milestone 4.
Backend handoff states no real async dispatcher/worker is implemented; events are persisted in sync_outbox only.
QA should scrutinize transaction boundaries, lockForUpdate use, quota enforcement, and double-allocation prevention.
The workspace already contains unrelated dirty/untracked files; QA should report scope drift only if M3 implementation changed forbidden paths.
```

## Proposed Board Update

```text
Active Task: 20260506-m3-central-stock-allocation-qa
Orchestrator: handoff_sent
Backend Develop: handoff_sent
QA Tester: ready
```

## Next Agent

QA Tester
