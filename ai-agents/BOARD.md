# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
virtual-stock-topup-cleanup
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | dispatched | virtual-stock-topup-cleanup | ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-coordinator-handoff.md |
| Orchestrator | completed | virtual-stock-topup-cleanup-qa-dispatch | ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | virtual-stock-topup-cleanup-backend | ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md |
| BO Develop | completed | virtual-stock-topup-cleanup-bo | ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | virtual-stock-topup-cleanup-qa | ai-agents/tasks/20260519-virtual-stock-topup-cleanup-qa.md |

## Open Questions

```text
All agents must use canonical worktree /Users/supakit/WorkSpace/www/newPaotang unless a task explicitly authorizes a separate worktree. Agents on stale codex/newPaotang-* worktrees must stop, report dirty files if any, and restart from the canonical worktree synced to origin/develop.
```

## Latest Decision

```text
ai-agents/decisions/20260519-agent-canonical-worktree-policy-decision.md
```
