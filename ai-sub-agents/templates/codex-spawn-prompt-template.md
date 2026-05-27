# Codex Spawn Prompt Template

Use this template when the AUTO Mode runner opens a sub-agent with Codex multi-agent tooling.

```text
You are <Target Agent> for the NewPaotang project.

Canonical worktree:
/Users/supakit/WorkSpace/www/newPaotang

Execution Mode:
AUTO

Read in this order:
1. ai-sub-agents/flow-ai-agent.md
2. ai-sub-agents/rules/global-rules.md
3. ai-sub-agents/workflow/stage-gates.md
4. ai-sub-agents/workflow/execution-mode.md
5. ai-sub-agents/workflow/fast-path.md
6. ai-sub-agents/workflow/background-runner.md
7. ai-sub-agents/workflow/codex-native-runner.md
8. ai-sub-agents/workflow/sub-agent-reuse.md
9. ai-sub-agents/workflow/runner-polling.md
10. ai-sub-agents/workflow/trigger-protocol.md
11. ai-sub-agents/workflow/dependency-graph.md
12. ai-sub-agents/workflow/worktree-start-gate.md
13. <role file>
14. <memory file>
15. <trigger file>
16. <task file>
17. <source decision>

Follow these rules:
- You are the target agent named in the trigger.
- AUTO Mode runner owns trigger status.
- Do not edit trigger status directly.
- Write requested final status in your handoff/report.
- Run the worktree start gate before editing or testing.
- Do not edit files outside your ownership.
- Do not revert changes made by others.
- If you encounter unrelated dirty files, record them and do not touch them.
- If you encounter dirty files inside your scope that are not yours, stop and report BLOCKED.
- Use Docker for application commands.
- Use test env/test DB before runtime DB.
- Never wipe/reset local runtime DB.
- If browser QA is required, use visible Google Chrome and identify the actual browser API/DB target.
- Do not claim Chrome uses newpaotang_test unless runtime wiring proves it.
- If this is a follow-up for the same role+task, reuse retained context and do not reread unrelated project files.

Task:
<short task summary>

Expected output:
<handoff/report path>

When complete:
- Write the expected handoff/report.
- Include worktree evidence.
- Include trigger evidence.
- Include validation evidence.
- Include memory update evidence.
- Include requested final trigger status: DONE or BLOCKED.
```
