# Orchestrator Memory

Memory is cache, not source of truth. Trust current Coordinator decision, tasks, docs, tests, and code over this file.

## Stable Context

- Orchestrator breaks Coordinator decisions into task prompts for the correct sub-agents.
- Orchestrator does not implement code, change scope, run GitOps, or skip QA.
- Orchestrator creates triggers for dev-agents and QA Tester.
- Orchestrator owns shared file lock creation/verification before QA.
- Default execution mode is AUTO; runner opens PENDING triggers.
- In AUTO Mode, runner owns trigger status; Orchestrator writes requested final status in handoff.
- Every task/trigger should include depends_on, can_run_parallel, blocking_outputs, and unblocks.

## Common Commands

- Inspect role ownership and current file paths before assigning work.
- Do not run app build/test/migrate commands unless the Coordinator task explicitly makes Orchestrator responsible for non-mutating validation.

## Known Patterns

- Dev task prompts must include ownership, acceptance criteria, automated test requirement, test env/test DB requirement, DB change declaration, and expected handoff.
- QA task should be created only after all required dev handoffs are present.
- Trigger files live in `ai-sub-agents/triggers/YYYYMMDD-<task-key>-<agent>-trigger.md`.
- Shared locks live in `ai-sub-agents/locks/YYYYMMDD-<task-key>-<agent>-lock.md`.
- Frontend triggers depending on backend API changes should depend_on backend handoff and contract evidence.
- If backend work only fixes behavior under an already stable opaque-cursor API contract, frontend and backend tasks can run parallel; QA should depend on both dev handoffs.
- Completion handoffs should carry any non-blocking adjacent validation failure into the QA task with command, failing assertion, and scope assessment.

## Gotchas

- Shared `apps/back-office/**` files can belong to central or partner flows; assign shared component changes explicitly.
- If a dev handoff lacks automated test evidence or a reason for no test, send it back before QA.
- Do not send QA while a shared lock is still `LOCKED` or an assigned trigger is not `DONE`.

## Last Useful Findings

- QA must use test env/test DB first and visible Google Chrome for browser acceptance.

## Do Not Trust Without Rechecking

- Whether all assigned dev-agent handoffs exist.
- Whether task scope changed in a newer Coordinator decision.
