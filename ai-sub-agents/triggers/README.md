# Triggers

Trigger files are the written instruction that opens work for a target agent.

Naming:

```text
YYYYMMDD-<task-key>-<agent>-trigger.md
```

Status values:

```text
PENDING
RUNNING
DONE
BLOCKED
CANCELLED
```

Rules:

```text
Coordinator may trigger Orchestrator for STANDARD/FULL work.
Coordinator may trigger one owning dev-agent directly only for FAST_PATH SMALL work.
Orchestrator may trigger dev-agents and QA Tester.
Coordinator may trigger QA Tester only for FAST_PATH after owning dev-agent handoff is ready.
Coordinator may trigger GitOps only after QA PASS is accepted.
```

Status ownership:

```text
AUTO Mode: background runner owns trigger status.
MANUAL Mode: target agent/operator may update trigger status.
Agents write requested final status in handoff/report.
```

AUTO runner must use claim and heartbeat files under:

```text
ai-sub-agents/runner/claims/
ai-sub-agents/runner/heartbeats/
ai-sub-agents/runner/logs/
```
