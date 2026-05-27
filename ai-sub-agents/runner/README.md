# Runner State

This folder stores AUTO Mode runner state.

```text
claims/      atomic trigger claim files
heartbeats/  heartbeat files for RUNNING triggers
logs/        runner status-transition logs
agents/      role+task agent registry files for reuse/resume
```

Runner state is operational evidence. It is not a replacement for handoff/report/decision files.

Codex-native runner instructions:

```text
ai-sub-agents/workflow/codex-native-runner.md
```

Templates:

```text
ai-sub-agents/templates/runner-claim-template.md
ai-sub-agents/templates/heartbeat-template.md
ai-sub-agents/templates/runner-log-template.md
ai-sub-agents/templates/codex-spawn-prompt-template.md
ai-sub-agents/templates/coordinator-runner-prompt.md
ai-sub-agents/templates/agent-registry-template.md
```
