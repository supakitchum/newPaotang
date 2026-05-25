# Coordinator Memory

Memory is cache, not source of truth. Trust current task, decisions, docs, tests, and code over this file.

## Stable Context

- Coordinator owns scope, milestones, priority, acceptance criteria, approval, and remediation decisions.
- Coordinator must not write implementation code, tests, migrations, commits, pushes, or DB operations.
- Normal flow is `User -> Coordinator -> Orchestrator -> Dev Agents -> Orchestrator -> QA Tester -> Coordinator -> GitOps`.
- Coordinator triggers only Orchestrator for new work and GitOps after QA approval.
- Default execution mode is AUTO; user should be able to stay in one Coordinator chat while runner opens sub-agents from triggers.
- AUTO runner owns trigger status and must use atomic claim/heartbeat; Coordinator still owns approval decisions.

## Common Commands

- Use read-only repo inspection before making decisions.
- Do not run migration, seed, reset, build, test, commit, or push as Coordinator.

## Known Patterns

- New task decision should identify task key, objective, affected agents, acceptance criteria, source-of-truth docs, DB-change expectation, and `Next Agent: Orchestrator`.
- New task decision should declare `Execution Mode: AUTO` and `Fallback Mode: MANUAL if background runner is unavailable`.
- QA review decision should explicitly accept or reject QA evidence and route either to GitOps or Orchestrator.
- New work should include `ai-sub-agents/triggers/YYYYMMDD-<task-key>-orchestrator-trigger.md`.
- Approved QA should include `ai-sub-agents/triggers/YYYYMMDD-<task-key>-gitops-trigger.md`.

## Gotchas

- Missing test env evidence means no approval.
- Missing visible Google Chrome evidence for browser acceptance means no clean PASS approval.
- PASS WITH RISK should usually route back to Orchestrator unless the risk is explicitly acceptable.
- If GitOps fails after a local commit, Coordinator must decide remediation, amend, revert, or retry; GitOps must not do that alone.
- If runner heartbeat times out, Coordinator decides whether to retry, cancel, or create remediation.

## Last Useful Findings

- Local runtime DB updates happen only through GitOps after Coordinator approval.

## Do Not Trust Without Rechecking

- Current branch/worktree state.
- Current source-of-truth docs.
- Whether a previous QA report still applies after new commits.
