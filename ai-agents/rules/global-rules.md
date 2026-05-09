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

## Code Agent Commit Rule

Agent ที่แก้ implementation code ต้อง commit งานของตัวเองเมื่อทำงานเสร็จและ validation ตาม task ผ่านแล้ว เพื่อไม่ให้ worktree สะสมงานค้าง

ใช้กับ agent เหล่านี้:

```text
Backend Develop
BO Develop
Customer Develop
agent อื่นที่ Coordinator สั่งให้แก้ implementation code โดยตรง
```

กติกา:

```text
1. ก่อน commit ต้องตรวจ git status --short
2. stage เฉพาะไฟล์ใน ownership/scope ของ task รวมถึง tests, docs, task handoff ที่เกี่ยวข้อง
3. ห้าม stage ไฟล์ unrelated หรือไฟล์ของ agent อื่นโดยไม่แจ้ง Coordinator
4. commit message ต้องขึ้นต้นด้วย task key และสรุปชัดว่าทำอะไรไป
5. handoff ต้องระบุ commit hash หรือถ้า commit ไม่สำเร็จต้องระบุ blocker
6. ถ้า QA พบ defect ทีหลัง ให้แก้เป็น remediation task และ commit เพิ่มอีกหนึ่งครั้ง
7. ถ้า worktree มี unrelated dirty changes ให้ commit เฉพาะ scope ของตัวเองและบันทึก unrelated changes ไว้ใน handoff
```

Coordinator ยังต้องคุม Gate 5 ก่อนขึ้น milestone ใหม่ แต่ worker code commit เป็นกฎประจำ task เพื่อรักษา worktree ให้สะอาดระหว่างทาง

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
- Runtime/command ต้องอ้างอิง `docs/docker-runtime-policy.md`
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

## Docker Runtime Rule

```text
ทุก application command ต้อง run ผ่าน Docker container เท่านั้น
ห้าม run PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration บน host machine
Orchestrator ต้องเขียน validation command เป็น docker compose exec หรือ docker compose run --rm เท่านั้น
Backend Develop ใช้ service platform-api
BO Develop ใช้ service back-office
Customer Develop ใช้ service customer
QA Tester ทดสอบผ่าน Docker service ที่เกี่ยวข้องเท่านั้น
```

## Git Boundary Rule

```text
เมื่อ task/milestone ล่าสุดผ่าน Coordinator approval แล้ว และสถานะพร้อมขึ้น M ใหม่:
1. หยุด dispatch งานใหม่ทันที
2. Coordinator ต้องตรวจ git status และสรุป scope ที่จะ commit
3. ต้อง stage/commit/push งานที่ผ่าน approval แล้วก่อนเริ่ม M ใหม่
4. ห้าม Orchestrator เปิด task ใหม่ของ M ถัดไปจนกว่า push สำเร็จ หรือผู้ใช้สั่งข้ามเป็นลายลักษณ์อักษร
```
