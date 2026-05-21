# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
customer-tenant-domain-api-integration - opened by Coordinator, Next Agent: Orchestrator
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | customer-tenant-domain-api-integration-open | ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-coordinator-handoff.md |
| Orchestrator | pending | customer-tenant-domain-api-integration | ai-agents/tasks/20260521-customer-tenant-domain-api-integration-orchestrator.md |
| Backend Develop | completed | partner-bo-domain-auth-branding-backend | ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md |
| BO Develop | completed | partner-bo-domain-auth-branding-bo | ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-bo-handoff.md |
| Customer Develop | pending | customer-tenant-domain-api-integration | ai-agents/tasks/20260521-customer-tenant-domain-api-integration-customer.md |
| QA Tester | pending | customer-tenant-domain-api-integration | ai-agents/tasks/20260521-customer-tenant-domain-api-integration-qa.md |

## Open Questions

```text
Customer domain/API integration must close the prior QA caveat where local customer dev blocked alpha.newpaotang.test through Vite/Nuxt allowedHosts. Orchestrator must keep scope to apps/customer and local customer dev/proxy config; backend/BO gaps should be reported, not patched, unless Coordinator opens a separate task.
```

## Latest Decision

```text
ai-agents/decisions/20260521-customer-tenant-domain-api-integration-decision.md
```
