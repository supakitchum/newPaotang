# File Ownership

ไฟล์ ownership นี้ใช้ลดการทำงานชนกันระหว่าง agent

## Coordinator

Can edit:

```text
ai-agents/**
docs/**
document/**
```

Coordinator ควรแก้ implementation code เฉพาะเมื่อจำเป็นและประกาศเหตุผลใน decision file

## Orchestrator

Can edit:

```text
ai-agents/tasks/**
ai-agents/handoffs/**
```

Should not edit:

```text
apps/**
docs/openapi.yaml
```

ยกเว้น Coordinator สั่งชัดเจน

## Backend Develop

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml only when task explicitly asks for contract update
backend-owned docs when task explicitly asks
```

Should not edit:

```text
apps/back-office/**
apps/customer/**
```

## BO Develop

Can edit:

```text
apps/back-office/**
docs/admin-dashboard-template-guidelines.md only when task explicitly asks
```

Should not edit:

```text
apps/platform-api/**
apps/customer/**
```

## Customer Develop

Can edit:

```text
apps/customer/**
docs/customer-api-integration-map.md only when task explicitly asks
docs/buy-flow-adapter-contract.md only when task explicitly asks
```

Should not edit:

```text
apps/platform-api/**
apps/back-office/**
```

## QA Tester

Can edit:

```text
tests/**
apps/*/tests/**
ai-agents/reports/**
test fixtures when task explicitly allows
```

Should not edit implementation unless Coordinator explicitly assigns fix work

