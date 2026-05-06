# no-coordinator-instruction Handoff

## Agent

Orchestrator

## Task

Read `ai-agents/prompts/open-chat-orchestrator.md` and follow the Orchestrator startup protocol.

## What Was Done

- Read the Orchestrator prompt and required workflow/rule files.
- Checked `ai-agents/decisions` for the latest Coordinator instruction.
- Checked `ai-agents/tasks` for existing task briefs.
- Checked `ai-agents/BOARD.md` for active task status.
- Reviewed the latest Backend Develop handoff that reports no backend task exists.
- Stopped before creating implementation tasks because no Coordinator instruction exists in `ai-agents/decisions` or `ai-agents/tasks`.

## Files Changed

- `ai-agents/handoffs/20260506-no-coordinator-instruction-orchestrator-handoff.md`

## Validation

Commands run:

```sh
rg --files -g 'open-chat-orchestrator.md' -g '!node_modules'
sed -n '1,260p' ai-agents/prompts/open-chat-orchestrator.md
sed -n '1,260p' ai-agents/README.md
sed -n '1,260p' ai-agents/rules/global-rules.md
sed -n '1,260p' ai-agents/workflow/stage-gates.md
sed -n '1,260p' ai-agents/workflow/handoff-protocol.md
sed -n '1,260p' ai-agents/workflow/file-ownership.md
sed -n '1,260p' ai-agents/roles/orchestrator.md
sed -n '1,260p' ai-agents/prompts/orchestrator-task-template.md
sed -n '1,260p' ai-agents/BOARD.md
find ai-agents/decisions -maxdepth 1 -type f -name '*.md' -print | sort
find ai-agents/tasks -maxdepth 1 -type f -name '*.md' -print | sort
sed -n '1,220p' ai-agents/decisions/README.md
sed -n '1,220p' ai-agents/tasks/README.md
sed -n '1,260p' ai-agents/handoffs/20260506-no-backend-task-backend-develop-handoff.md
```

Result:

- `ai-agents/decisions` contains only `README.md`.
- `ai-agents/tasks` contains only `README.md`.
- `ai-agents/BOARD.md` shows `Active Task: none`.
- No Coordinator instruction is available to break down into agent task files.

## Known Risks

- Backend Develop is blocked until Coordinator provides a scoped instruction.
- Creating a task from the Backend Develop handoff alone would violate the chain of command because Orchestrator must receive instructions from Coordinator only.

## Questions For Coordinator

- What task objective should Orchestrator break down next?
- Which target area should be assigned: Backend Develop, BO Develop, Customer Develop, QA Tester, or multiple agents?
- What are the required scope, out-of-scope items, acceptance criteria, and validation commands?

## Proposed Board Update

```text
Active Task: awaiting Coordinator instruction
Orchestrator: blocked | no-coordinator-instruction | ai-agents/handoffs/20260506-no-coordinator-instruction-orchestrator-handoff.md
Backend Develop: blocked | no backend task | ai-agents/handoffs/20260506-no-backend-task-backend-develop-handoff.md
Open Questions: Coordinator must provide task objective and target agent ownership before Orchestrator can create task files.
Latest Decision: none
```

## Next Agent

Coordinator
