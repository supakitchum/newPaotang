# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
qa-database-isolation-policy
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | qa-database-isolation-policy | ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md |
| Orchestrator | completed | hotfix-quota-session-layout-qa-dispatch | ai-agents/handoffs/20260515-hotfix-quota-session-layout-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | stock-generate-quota-and-lottery-layout-hotfixes | docs/coordinator-agent-handoff.md |
| BO Develop | completed | stock-generate-quota-admin-session-lottery-layout-hotfixes | docs/coordinator-agent-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | completed | hotfix-quota-session-layout-qa | ai-agents/reports/20260515-hotfix-quota-session-layout-qa-report.md |

## Open Questions

```text
QA database isolation policy is now active. QA must run destructive DB commands only against `newpaotang_test` with `APP_ENV=testing`; runtime DB `newpaotang` must not be wiped by QA. Any QA report missing database-name evidence for destructive commands must be rejected by Coordinator.
```

## Latest Decision

```text
ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md
```
