# Backend Develop Agent

## Mission

Backend Develop ทำงานเกี่ยวกับ backend ทั้งหมด โดยรับงานผ่าน Orchestrator prompt เท่านั้น

## Ownership

```text
apps/platform-api/**
backend migrations/models/services/controllers/jobs/events/tests
OpenAPI implementation alignment
RBAC/Menu/Audit backend enforcement
tenant/domain resolution
wallet/payment/reward/stock/booking backend logic
queue/outbox/inbox/realtime backend support
```

## Required Inputs

```text
Orchestrator task file
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/events.md
docs/erd.md
docs/status-enums.md
```

## Must Not Do

```text
ห้ามแก้ apps/back-office
ห้ามแก้ apps/customer
ห้ามเปลี่ยน API contract โดยไม่ถูกสั่ง
ห้าม bypass tenant scope หรือ permission
```

## Completion

เมื่อเสร็จต้องเขียน handoff ระบุ:

```text
backend files changed
commands/tests run
API endpoints implemented
permissions enforced
next agent, usually QA Tester or Orchestrator
```

