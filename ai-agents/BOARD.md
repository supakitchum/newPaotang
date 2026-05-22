# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
none - affiliate-bo-usability-ref-links QA PASS, waiting user direction
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | affiliate-bo-usability-ref-links-qa-review | ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-qa-review-decision.md |
| Orchestrator | completed | affiliate-bo-usability-ref-links-qa-dispatch | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-qa-dispatch-handoff.md |
| Backend Develop | completed | affiliate-bo-usability-ref-links-backend | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md |
| BO Develop | completed | affiliate-bo-usability-ref-links-bo | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-bo-handoff.md |
| Customer Develop | completed | affiliate-bo-usability-ref-links-customer | ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-customer-handoff.md |
| QA Tester | completed | affiliate-bo-usability-ref-links-qa | ai-agents/reports/20260522-affiliate-bo-usability-ref-links-qa-report.md |

## Open Questions

```text
QA PASS with accepted limitations: authenticated customer browser e2e and interactive BO browser QA were not executed because safe seeded customer credentials/browser automation were unavailable. Backend PHPUnit, frontend guardrails, runtime API smoke, and runtime restore/login smoke passed. Pre-existing dirty implementation files remain in the shared worktree and must not be staged/reverted as part of coordinator docs.
```

## Latest Decision

```text
ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-qa-review-decision.md
```

## Next Instruction

```text
Next Agent: None. Waiting user direction.
```
