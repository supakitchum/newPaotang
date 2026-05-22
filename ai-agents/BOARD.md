# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
affiliate-bo-usability-ref-links
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | dispatched | affiliate-bo-usability-ref-links | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-orchestrator.md |
| Orchestrator | completed | affiliate-bo-usability-ref-links-bo-customer-dispatch | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-bo-customer-dispatch-handoff.md |
| Backend Develop | completed | affiliate-bo-usability-ref-links-backend | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md |
| BO Develop | completed | affiliate-bo-usability-ref-links-bo | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-bo-handoff.md |
| Customer Develop | pending | affiliate-bo-usability-ref-links-customer | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md |
| QA Tester | waiting-implementation | affiliate-bo-usability-ref-links-qa | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-qa.md |

## Open Questions

```text
The canonical worktree has pre-existing dirty implementation files from prior Hotfix work. Downstream agents must not stage/revert unrelated dirty files and must work carefully with overlapping files only if they are part of the intended current state.
```

## Latest Decision

```text
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md
```

## Next Instruction

```text
Next Agent: Customer Develop. Customer must complete ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md before Orchestrator can dispatch QA.
```
