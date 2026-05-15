# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
hotfix-quota-session-layout-qa
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260515-hotfix-quota-session-layout-handoff | docs/coordinator-agent-handoff.md |
| Orchestrator | completed | hotfix-quota-session-layout-qa-dispatch | ai-agents/handoffs/20260515-hotfix-quota-session-layout-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | stock-generate-quota-and-lottery-layout-hotfixes | docs/coordinator-agent-handoff.md |
| BO Develop | completed | stock-generate-quota-admin-session-lottery-layout-hotfixes | docs/coordinator-agent-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | hotfix-quota-session-layout-qa | ai-agents/tasks/20260515-hotfix-quota-session-layout-qa.md |

## Open Questions

```text
Coordinator hotfix handoff for 2026-05-15 has been routed to QA. QA must validate quota-based central stock generation, BO Generate Stock form contract, admin session replacement handling, lottery image layout/logo_num_set behavior, BO lottery image page layout ordering, OpenAPI/docs alignment, credential/artifact scan, and the mandatory Runtime Restore / Login Smoke rule before reporting PASS. Production rollout still needs real S3/R2-compatible object storage, queue workers, credential redaction checks, environment-specific readiness validation, and authenticated BO/customer UAT once credentials or a session are supplied.
```

## Latest Decision

```text
docs/coordinator-agent-handoff.md
```
