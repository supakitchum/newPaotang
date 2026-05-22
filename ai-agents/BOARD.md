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
| Orchestrator | completed | affiliate-bo-usability-ref-links | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-handoff.md |
| Backend Develop | pending | affiliate-bo-usability-ref-links-backend | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md |
| BO Develop | waiting-backend | affiliate-bo-usability-ref-links-bo | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md |
| Customer Develop | waiting-backend | affiliate-bo-usability-ref-links-customer | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md |
| QA Tester | waiting-implementation | affiliate-bo-usability-ref-links-qa | ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-qa.md |

## Open Questions

```text
The canonical worktree has pre-existing dirty implementation files from prior Hotfix work. Downstream agents must not stage/revert unrelated dirty files and must work carefully with overlapping files only if they are part of the intended current state.
```

## Latest Decision

```text
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md
```

## Next Instruction

```text
Next Agent: Backend Develop. Backend must start from ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md.
```
