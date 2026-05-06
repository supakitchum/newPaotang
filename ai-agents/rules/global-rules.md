# Global Rules For All Agents

## Chain Of Command

```text
User -> Coordinator -> Orchestrator -> Worker Agent -> QA Tester -> Coordinator
```

- Coordinator เป็นผู้ตัดสินใจแผนรวม, scope, policy, และ approval gate
- Orchestrator แปลงคำสั่งของ Coordinator เป็น task prompt ให้ agent อื่น
- Backend Develop, BO Develop, Customer Develop และ QA Tester รับงานผ่าน Orchestrator prompt เท่านั้น
- Agent ทุกตัวห้ามข้ามขั้นตอนหรือทำงานนอกบทบาทจนกว่า Coordinator จะสั่งชัดเจน

## Clarification Rule

Coordinator ต้องถามผู้ใช้หรือขอความเห็นเมื่อเจอข้อมูลไม่ชัดเจนในส่วนที่มีผลต่อ architecture, scope, security, tenant isolation, payment, wallet, reward, permission, หรือ customer flow

Coordinator ห้ามเดาเองในเรื่องที่:

```text
เปลี่ยน business flow
เปลี่ยน API contract ที่กระทบ frontend/backend หลายส่วน
เปลี่ยน permission/security model
เปลี่ยน tenant/domain behavior
เปลี่ยน payment/wallet/reward logic
เปลี่ยน customer UI flow เดิม
```

## Completion Report Rule

เมื่อ agent ทำงานเสร็จ ต้องรายงานทุกครั้ง:

```text
1. ทำอะไรไป
2. แก้ไฟล์อะไรบ้าง
3. ตรวจสอบอะไรแล้ว
4. ยังเหลือความเสี่ยงหรือคำถามอะไร
5. งานถัดไปควรเป็นของ Agent ตัวไหน
```

รายงานต้องเขียนลง `ai-agents/handoffs` หรือ `ai-agents/reports` ตามชนิดงาน

## No Cross Role Rule

```text
Backend Develop ห้ามแก้ UI ยกเว้น Coordinator สั่งชัดเจน
BO Develop ห้ามแก้ backend logic ยกเว้น Coordinator สั่งชัดเจน
Customer Develop ห้าม rewrite customer flow เดิม ยกเว้น Coordinator อนุมัติ
QA Tester ห้ามแก้ implementation ยกเว้น Coordinator สั่งให้ช่วยแก้ test fixture หรือ test code
Orchestrator ห้าม implement code ยกเว้น Coordinator สั่งชัดเจน
```

## Contract Rule

- API ต้องอ้างอิง `docs/openapi.yaml`
- Permission ต้องอ้างอิง `docs/permissions.md`
- Customer flow ต้องอ้างอิง `docs/customer-api-integration-map.md`
- Back-office UI ต้องอ้างอิง `docs/admin-dashboard-template-guidelines.md`
- ถ้าเอกสารไม่ตรงกัน ให้หยุดและส่งคำถามให้ Coordinator

## Tenant And Security Rule

ทุกงานต้องรักษากฎเหล่านี้:

```text
tenant isolation is mandatory
backend authorization is source of truth
menu visibility is not authorization
customer must never write Central Stock directly
support impersonation must never expose real passwords
wallet/payment/reward writes require idempotency and audit where applicable
```

