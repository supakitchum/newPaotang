# Runner Agent Registry

This folder stores AUTO Mode sub-agent registry files for reuse/resume decisions.

```text
YYYYMMDD-<task-key>-<role>.md
```

Registry files are operational state only. They do not replace trigger, handoff, report, decision, or memory files.

If no registry/agent_id exists for a role+task, runner may first-spawn automatically and store the returned `agent_id`.

If a registry file already has an `agent_id`, runner must reuse/resume that agent when possible. Replacement spawn for the same role+task requires matching `spawn_new:<agent>` or Coordinator/User decision evidence.

See:

```text
ai-sub-agents/workflow/sub-agent-reuse.md
ai-sub-agents/templates/agent-registry-template.md
```
