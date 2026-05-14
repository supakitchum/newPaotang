# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
lottery-image-central-ops-usability-zip-preview-complete
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260514-qa-runtime-restore-login-smoke-rule | ai-agents/decisions/20260514-qa-runtime-restore-login-smoke-rule-decision.md |
| Orchestrator | completed | lottery-image-central-ops-zip-preview-qa-dispatch | ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | lottery-image-central-ops-zip-preview-backend | ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md |
| BO Develop | completed | lottery-image-central-ops-zip-preview-bo | ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | completed | lottery-image-central-ops-zip-preview-qa | ai-agents/reports/20260514-lottery-image-central-ops-zip-preview-qa-report.md |

## Open Questions

```text
Lottery-image central ops usability ZIP preview passed QA and is Coordinator-approved. Coordinator added a mandatory QA runtime restore/login smoke rule: future QA tasks that touch DB/Docker/BO dev server must reseed, run platform:smoke, verify seeded-logins, restart/recreate back-office when applicable, and prove /login plus /admin/login are healthy before reporting clean PASS. Production rollout still needs real S3/R2-compatible object storage, queue workers, credential redaction checks, environment-specific readiness validation, and authenticated BO/customer UAT once credentials or a session are supplied.
```

## Latest Decision

```text
ai-agents/decisions/20260514-qa-runtime-restore-login-smoke-rule-decision.md
```
