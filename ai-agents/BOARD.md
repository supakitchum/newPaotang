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
| Orchestrator | pending | lottery-image-central-ops-usability-zip-preview | ai-agents/handoffs/20260514-lottery-image-central-ops-usability-zip-preview-coordinator-handoff.md |
| Backend Develop | completed | lottery-image-production-ops-readiness | ai-agents/handoffs/20260514-lottery-image-production-ops-readiness-backend-handoff.md |
| BO Develop | completed | lottery-image-operations-management-ui | ai-agents/handoffs/20260514-lottery-image-operations-management-ui-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | completed | lottery-image-generation-expanded-delivery-launch-gate-rerun-qa | ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-rerun-qa-report.md |

## Open Questions

```text
New lottery-image central operations usability phase opened. Orchestrator must split Backend and BO work for PNG zip background import, backend-generated full/thumb variants, game-name selection, central-only lottery-images/lottery-branding access, Games/Partners table actions, and manual-number preview flows. Expanded delivery launch gate remains approved; production rollout still needs real S3/R2-compatible object storage, queue workers, credential redaction checks, and authenticated UAT.
```

## Latest Decision

```text
ai-agents/decisions/20260514-lottery-image-central-ops-usability-zip-preview-decision.md
```
