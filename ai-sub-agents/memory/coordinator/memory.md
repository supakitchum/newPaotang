# Coordinator Memory

Memory is cache, not source of truth. Trust current task, decisions, docs, tests, and code over this file.

## Stable Context

- Coordinator owns scope, milestones, priority, acceptance criteria, approval, and remediation decisions.
- Coordinator must not write implementation code, tests, migrations, commits, pushes, or DB operations.
- Normal flow is `User -> Coordinator -> Orchestrator -> Dev Agents -> Orchestrator -> QA Tester -> Coordinator -> GitOps`.
- For SMALL single-owner work, prefer `FAST_PATH`: Coordinator can trigger the owning dev-agent directly and skip Orchestrator initial breakdown.
- Coordinator triggers only Orchestrator for new work and GitOps after QA approval.
- Exception: Coordinator may trigger one owning dev-agent directly for FAST_PATH SMALL work with documented reason and boundary.
- FAST_PATH QA trigger may be created by Coordinator after the owning dev-agent handoff is ready.
- Default execution mode is AUTO; user should be able to stay in one Coordinator chat while runner opens sub-agents from triggers.
- AUTO runner owns trigger status and must use atomic claim/heartbeat; Coordinator still owns approval decisions.
- In Codex, Coordinator chat can act as runner controller using multi-agent spawn for valid triggers only.
- Runner should reuse/resume same task+role agent and poll expected handoff/report before spawning another agent.
- If no registry/agent_id exists for role+task, runner may first-spawn automatically and save the agent_id.
- If a role+task already has an agent_id, replacement spawn requires matching `spawn_new:<agent>` or Coordinator/User decision; runner should not decide silently.

## Common Commands

- Use read-only repo inspection before making decisions.
- Do not run migration, seed, reset, build, test, commit, or push as Coordinator.

## Known Patterns

- New task decision should identify task key, objective, affected agents, acceptance criteria, source-of-truth docs, DB-change expectation, and `Next Agent: Orchestrator`.
- New task decision should classify `Task Size` and `Flow Mode`; SMALL/single-owner/no-risk work should use FAST_PATH by default.
- New task decision should declare `Execution Mode: AUTO` and `Fallback Mode: MANUAL if background runner is unavailable`.
- QA review decision should explicitly accept or reject QA evidence and route either to GitOps or Orchestrator.
- New work should include `ai-sub-agents/triggers/YYYYMMDD-<task-key>-orchestrator-trigger.md`.
- Approved QA should include `ai-sub-agents/triggers/YYYYMMDD-<task-key>-gitops-trigger.md`.
- Use `ai-sub-agents/templates/codex-spawn-prompt-template.md` when spawning target agents.

## Gotchas

- Missing test env evidence means no approval.
- Missing visible Google Chrome evidence for browser acceptance means no clean PASS approval.
- QA browser evidence must separate automated test DB (`newpaotang_test`) from visible browser runtime DB, often `newpaotang` on localhost.
- Do not open backend just because a frontend flow calls API; require evidence or a scope-expansion decision.
- PASS WITH RISK should usually route back to Orchestrator unless the risk is explicitly acceptable.
- If GitOps fails after a local commit, Coordinator must decide remediation, amend, revert, or retry; GitOps must not do that alone.
- If runner heartbeat times out, Coordinator decides whether to retry, cancel, or create remediation.

## Last Useful Findings

- Local runtime DB updates happen only through GitOps after Coordinator approval.

## Do Not Trust Without Rechecking

- Current branch/worktree state.
- Current source-of-truth docs.
- Whether a previous QA report still applies after new commits.
