# File Ownership

ไฟล์ ownership นี้ใช้ลดการทำงานชนกันระหว่าง agent

## Coordinator

Can edit:

```text
ai-sub-agents/decisions/**
ai-sub-agents/handoffs/*coordinator*.md
ai-sub-agents/triggers/*orchestrator-trigger.md
ai-sub-agents/triggers/*gitops-trigger.md after QA approval
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/**
ai-sub-agents/workflow/**
ai-sub-agents/memory/coordinator/memory.md
```

Must not edit:

```text
apps/**
implementation tests
database migrations
```

Coordinator ห้ามเขียนโค้ด

## Orchestrator

Can edit:

```text
ai-sub-agents/tasks/**
ai-sub-agents/handoffs/**
ai-sub-agents/triggers/*orchestrator-trigger.md read-only in AUTO Mode; status updates only in MANUAL Mode
ai-sub-agents/triggers/*dev-*-trigger.md create/update non-status fields before RUNNING; status read-only in AUTO Mode
ai-sub-agents/triggers/*qa-tester-trigger.md create/update non-status fields before RUNNING; status read-only in AUTO Mode
ai-sub-agents/locks/**
ai-sub-agents/memory/orchestrator/memory.md
```

Must not edit:

```text
apps/**
docs/openapi.yaml
database migrations
ai-sub-agents/triggers/*gitops-trigger.md
```

## Dev Backend

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml only when task explicitly requires API contract update
backend-owned docs only when task explicitly requires documentation update
ai-sub-agents/handoffs/**
ai-sub-agents/triggers/*dev-backend-trigger.md read-only in AUTO Mode; status updates only in MANUAL Mode
ai-sub-agents/memory/dev-backend/memory.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
```

## Dev BO Central

Can edit:

```text
apps/back-office/**
central admin routes/pages/components/composables
central-only operation UI
ai-sub-agents/handoffs/**
ai-sub-agents/triggers/*dev-bo-central-trigger.md read-only in AUTO Mode; status updates only in MANUAL Mode
ai-sub-agents/locks/*dev-bo-central-lock.md status updates only
ai-sub-agents/memory/dev-bo-central/memory.md
```

Shared BO components may be edited only when Orchestrator task explicitly assigns the shared change.

Must not edit:

```text
apps/platform-api/**
apps/customer/**
partner/tenant-only BO flow unless assigned
```

## Dev BO Partner

Can edit:

```text
apps/back-office/**
partner/tenant admin routes/pages/components/composables
partner/tenant-only operation UI
ai-sub-agents/handoffs/**
ai-sub-agents/triggers/*dev-bo-partner-trigger.md read-only in AUTO Mode; status updates only in MANUAL Mode
ai-sub-agents/locks/*dev-bo-partner-lock.md status updates only
ai-sub-agents/memory/dev-bo-partner/memory.md
```

Shared BO components may be edited only when Orchestrator task explicitly assigns the shared change.

Must not edit:

```text
apps/platform-api/**
apps/customer/**
central-only BO flow unless assigned
```

## Dev Customer

Can edit:

```text
apps/customer/**
customer API adapter/composables
customer pages/components/layouts
ai-sub-agents/handoffs/**
ai-sub-agents/triggers/*dev-customer-trigger.md read-only in AUTO Mode; status updates only in MANUAL Mode
ai-sub-agents/memory/dev-customer/memory.md
```

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
```

## QA Tester

Can edit:

```text
ai-sub-agents/reports/**
ai-sub-agents/handoffs/*qa*.md
QA evidence files under ai-sub-agents/reports/**
ai-sub-agents/triggers/*qa-tester-trigger.md read-only in AUTO Mode; status updates only in MANUAL Mode
ai-sub-agents/memory/qa-tester/memory.md
```

Must not edit:

```text
implementation code
database migrations
production/staging/runtime DB state
```

QA may edit tests or fixtures only when Coordinator explicitly assigns a remediation task for QA-owned test work.

## GitOps

Can edit:

```text
ai-sub-agents/gitops/**
ai-sub-agents/handoffs/*gitops*.md
ai-sub-agents/triggers/*gitops-trigger.md read-only in AUTO Mode; status updates only in MANUAL Mode
ai-sub-agents/memory/gitops/memory.md
```

Can operate:

```text
git status/stage/commit/push approved scope
non-destructive local runtime DB migration after Coordinator approval
smoke checks after migration
```

Must not edit:

```text
implementation code
business docs
agent rules without Coordinator assignment
```

## Background Runner

Can edit:

```text
ai-sub-agents/triggers/** status fields only
ai-sub-agents/runner/claims/**
ai-sub-agents/runner/heartbeats/**
ai-sub-agents/runner/logs/**
```

Must not edit:

```text
apps/**
ai-sub-agents/tasks/**
ai-sub-agents/decisions/**
ai-sub-agents/handoffs/**
ai-sub-agents/reports/**
ai-sub-agents/gitops/**
agent memory files
```

Runner ห้ามตัดสิน scope, QA result, approval, git policy, หรือ DB policy
