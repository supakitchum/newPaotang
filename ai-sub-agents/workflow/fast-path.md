# Fast Path Workflow

Fast Path ลด overhead สำหรับงานเล็กที่มี owner ชัดเจน โดยยังคงกฎสำคัญ: Coordinator ไม่เขียนโค้ด, dev-agent ต้องทำ test, QA ต้องตรวจตามความเสี่ยง, และ GitOps ทำหลัง approval เท่านั้น

## Task Size

Coordinator ต้อง classify ทุกงานก่อนเปิด trigger:

```text
SMALL
STANDARD
FULL
```

## SMALL Criteria

ใช้ `SMALL` ได้เมื่อครบทุกข้อ:

```text
มี owner หลักเพียง agent เดียว
คาดว่าแตะไฟล์ไม่เกิน 3-5 ไฟล์
acceptance criteria ชัดเจนและทดสอบแบบ focused ได้
ไม่มี migration/schema/data-contract change
ไม่มี payment, wallet, ledger, tenant isolation, auth, permission, security, หรือ privacy risk
ไม่มี shared file lock risk ที่ชนกับงานอื่น
ไม่มี requirement คลุมเครือที่ต้องแตก milestone
```

ถ้าข้อใดข้อหนึ่งไม่จริง ให้ใช้ `STANDARD` หรือ `FULL`

## Flow Mode

Coordinator decision ต้องระบุ:

```text
Task Size:
Flow Mode:
Primary Owner:
Conditional Agents:
Fast Path Eligibility:
```

Allowed values:

```text
FAST_PATH
STANDARD
FULL
```

## FAST_PATH Flow

สำหรับงาน `SMALL` Coordinator สามารถเปิด trigger ให้ dev-agent owner โดยตรงได้ โดยไม่ต้องเปิด Orchestrator ก่อน

```text
User
  -> Coordinator
  -> Trigger owning Dev Agent directly
  -> Dev Agent
  -> Coordinator verifies dev handoff
  -> Trigger QA Tester when browser/data/user-facing behavior needs QA
  -> Coordinator
  -> GitOps after approval
```

Coordinator ยังห้ามเขียนโค้ดและห้ามรัน test/build/migration เอง

## Direct Dev Trigger Rule

Coordinator เปิด dev-agent โดยตรงได้เฉพาะเมื่อ decision ระบุ `Flow Mode: FAST_PATH` และ `Task Size: SMALL`

Direct trigger ต้องมี:

```text
reason for bypassing Orchestrator
primary owner
explicit file ownership boundary
acceptance criteria
automated test expectation
QA expectation
scope expansion rule
```

ถ้า dev-agent พบว่างานเกิน scope ต้องหยุดและส่ง blocker กลับ Coordinator ไม่ขยาย scope เอง

## Conditional Agent Expansion

ห้ามเปิด backend, BO, customer, หรือ QA agent เผื่อไว้โดยไม่มีเหตุ

เปิด agent เพิ่มได้เมื่อมี evidence:

```text
owner dev-agent handoff ระบุ blocker ที่ต้องใช้ agent อื่น
test evidence ชี้ว่า root cause อยู่นอก ownership เดิม
API/contract evidence ชี้ว่าต้องแก้ backend หรือ frontend อีกฝั่ง
Coordinator ออก decision อนุมัติ scope expansion แล้ว
```

## Backend Expansion Guard

สำหรับงาน customer/frontend ที่ดูเหมือนอาจเกี่ยว backend:

```text
เริ่มที่ dev-customer ถ้า symptom อยู่ใน customer UI/adapter และ API contract ยังไม่พิสูจน์ว่าเสีย
ห้ามเปิด dev-backend เพียงเพราะ API ถูกเรียกใน flow
เปิด dev-backend เมื่อมี failing backend test, contract mismatch, API response defect, หรือ Coordinator approval จาก evidence
```

## QA For FAST_PATH

QA requirement ตาม risk:

```text
browser/user-facing change -> QA Tester ทำ focused visible Chrome QA
backend/data change -> QA Tester ตรวจ test env/test DB evidence
pure non-user-facing frontend utility with dev automated evidence -> Coordinator อาจใช้ focused QA review แทน full QA แต่ต้องบันทึกเหตุผล
```

ถ้ามี Chrome QA ต้องทำตาม `ai-sub-agents/workflow/qa-browser-env.md`

## When To Escalate

FAST_PATH ต้อง escalate เป็น `STANDARD` เมื่อ:

```text
แตะหลาย ownership
พบ DB/schema/data contract change
ต้องใช้ shared file lock
automated test ไม่พอพิสูจน์ acceptance
QA เจอ FAIL/PASS WITH RISK ที่ต้องแตก remediation
มี worktree conflict หรือ dirty file ใน scope ที่ไม่ใช่งานตัวเอง
```
