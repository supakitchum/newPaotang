# NewPaotang AI Agent Workspace

โฟลเดอร์นี้เป็นพื้นที่กลางสำหรับ AI Agent ทุกตัวที่ทำงานในโปรเจค NewPaotang

## Agent Roster

| Agent | Role File | Purpose |
| --- | --- | --- |
| Coordinator | `roles/coordinator.md` | วางแผน ตรวจสอบ ออกกฎกลาง และคุมทีม agent ทั้งหมด |
| Orchestrator | `roles/orchestrator.md` | แปลงคำสั่งของ Coordinator เป็น prompt/task brief ให้ agent อื่นทำงาน |
| Backend Develop | `roles/backend-develop.md` | ทำ backend และ `apps/platform-api` เท่านั้น |
| BO Develop | `roles/bo-develop.md` | ทำ frontend back-office และ `apps/back-office` เท่านั้น |
| Customer Develop | `roles/customer-develop.md` | ทำ frontend customer และ `apps/customer` เท่านั้น |
| QA Tester | `roles/qa-tester.md` | วางแผนทดสอบ ทดสอบ และรายงานผลให้ Coordinator |

## Must Read Order

Agent ทุกตัวต้องอ่านตามลำดับนี้ก่อนเริ่มงาน:

```text
1. ai-agents/README.md
2. ai-agents/rules/global-rules.md
3. ai-agents/workflow/stage-gates.md
4. ai-agents/workflow/handoff-protocol.md
5. ai-agents/workflow/file-ownership.md
6. docs/docker-runtime-policy.md
7. role file ของตัวเองใน ai-agents/roles
8. task/prompt ที่ได้รับจาก Orchestrator
9. docs/openapi.yaml และเอกสาร docs/document ที่ task อ้างถึง
```

## Source Of Truth

```text
API contract: docs/openapi.yaml
Backend/API conventions: docs/api-conventions.md
Docker runtime policy: docs/docker-runtime-policy.md
Permissions: docs/permissions.md
Events: docs/events.md
ERD: docs/erd.md
Status enums: docs/status-enums.md
Customer adapter: docs/customer-api-integration-map.md, docs/buy-flow-adapter-contract.md
Back-office template: docs/admin-dashboard-template-guidelines.md
System documents: document/*.md
```

## Working Areas

```text
ai-agents/tasks       งานที่ Coordinator/Orchestrator แตกไว้
ai-agents/handoffs    บันทึกส่งต่องานระหว่าง agent
ai-agents/reports     รายงานผลจาก agent โดยเฉพาะ QA
ai-agents/decisions   ข้อสรุป/ข้อจำกัด/คำถามที่ Coordinator ตัดสินใจแล้ว
ai-agents/prompts     template สำหรับ Orchestrator ใช้สร้าง prompt
```

## Current Implementation State

```text
apps/customer exists and must preserve its existing UI flow.
apps/platform-api is planned as the backend API project.
apps/back-office is planned as the admin dashboard frontend project.
```

Agent ห้ามสร้าง business rule ใหม่เองเมื่อเอกสารยังไม่ชัด ให้ส่งคำถามกลับ Coordinator ผ่าน handoff/report.
