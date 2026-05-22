# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
affiliate-bo-usability-ref-links - Coordinator dispatched to Orchestrator, waiting Orchestrator task split
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | dispatched | affiliate-bo-usability-ref-links | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-orchestrator.md |
| Orchestrator | pending | affiliate-bo-usability-ref-links | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-orchestrator.md |
| Backend Develop | completed | partner-bo-domain-auth-branding-backend | ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md |
| BO Develop | completed | partner-bo-domain-auth-branding-bo | ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-bo-handoff.md |
| Customer Develop | completed | customer-tenant-domain-api-integration | ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-customer-handoff.md |
| QA Tester | completed | customer-tenant-domain-api-integration | ai-agents/reports/20260521-customer-tenant-domain-api-integration-qa-report.md |

## Open Questions

```text
Before Orchestrator starts, run start gate in canonical worktree. Current Coordinator dispatch happened on develop HEAD 6bdb2a9654aba9f57cb250aedf83fa6b98c4c487 matching origin/develop, but local worktree has uncommitted implementation changes from prior Hotfix work. Orchestrator must not stage/revert unrelated dirty files; if dirty overlap blocks task split or agent work, return blocker to Coordinator.
```

## Latest Decision

```text
ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-decision.md
```

## Next Instruction

```text
Next Agent: Orchestrator. Orchestrator must pick up ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-orchestrator.md and split Backend/BO/Customer/QA work after start gate passes.
```
