# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
stock-generation-progress-socket-hotfix
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | stock-generation-progress-socket-hotfix | ai-agents/handoffs/20260516-stock-generation-progress-socket-hotfix-coordinator-handoff.md |
| Orchestrator | completed | stock-generation-realtime-runtime-readiness | ai-agents/handoffs/20260516-stock-generation-realtime-runtime-readiness-coordinator-handoff.md |
| Backend Develop | completed | stock-generation-realtime-progress-backend | ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md |
| BO Develop | completed | stock-generation-realtime-progress-bo | ai-agents/handoffs/20260516-stock-generation-realtime-progress-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | stock-generation-progress-socket-hotfix | ai-agents/handoffs/20260516-stock-generation-progress-socket-hotfix-coordinator-handoff.md |

## Open Questions

```text
Hotfix applied directly by Coordinator: local Docker Reverb runtime is installed/configured, BO waits for subscription_succeeded before connected, fallback stays active until realtime is really connected, and a socket probe received stock.generation.progress.updated with 75000 / 100000 progress. QA Tester should verify the hotfix.
```

## Latest Decision

```text
ai-agents/decisions/20260516-stock-generation-progress-socket-hotfix-decision.md
```
