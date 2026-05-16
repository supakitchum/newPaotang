# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
queue-worker-runtime-hotfix
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | queue-worker-runtime-hotfix | ai-agents/handoffs/20260516-queue-worker-runtime-hotfix-coordinator-handoff.md |
| Orchestrator | completed | large-async-stock-generation-qa-dispatch | ai-agents/handoffs/20260516-large-async-stock-generation-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | large-async-stock-generation-backend | ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md |
| BO Develop | completed | large-async-stock-generation-bo | ai-agents/handoffs/20260516-large-async-stock-generation-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | completed | large-async-stock-generation-qa | ai-agents/reports/20260516-large-async-stock-generation-qa-report.md |

## Open Questions

```text
Applied queue worker runtime hotfix. Docker worker defaults, .env.example, and queue profile catalog now include stock-generation, stock-image-generation, and stock-partner-image-generation. Started platform-api-worker with the worker profile, platform:smoke passed, and worker logs show GenerateStockBatchChunkJob processing the active async stock generation batch.
```

## Latest Decision

```text
ai-agents/decisions/20260516-queue-worker-runtime-hotfix-decision.md
```
