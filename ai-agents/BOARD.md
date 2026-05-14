# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
lottery-image-central-ops-usability-zip-preview
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260514-lottery-image-central-ops-usability-zip-preview-open | ai-agents/handoffs/20260514-lottery-image-central-ops-usability-zip-preview-coordinator-handoff.md |
| Orchestrator | completed | lottery-image-central-ops-zip-preview-qa-dispatch | ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | lottery-image-central-ops-zip-preview-backend | ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md |
| BO Develop | completed | lottery-image-central-ops-zip-preview-bo | ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | lottery-image-central-ops-zip-preview-qa | ai-agents/tasks/20260514-lottery-image-central-ops-zip-preview-qa.md |

## Open Questions

```text
Backend and BO completed the lottery-image central operations usability zip preview implementation. Orchestrator registered both handoffs and routed the prepared QA task. QA Tester must validate central-only enforcement, Games/Partners deep links, game-name selection, PNG zip import and generated variants, preview modes, side-effect safety, OpenAPI parse, and credential/artifact scan. Expanded delivery launch gate remains approved; production rollout still needs real S3/R2-compatible object storage, queue workers, credential redaction checks, and authenticated UAT.
```

## Latest Decision

```text
ai-agents/decisions/20260514-lottery-image-central-ops-usability-zip-preview-decision.md
```
