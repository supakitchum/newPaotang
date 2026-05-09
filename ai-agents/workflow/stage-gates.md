# Stage Gates

งานทุกชิ้นต้องผ่าน gate ตามลำดับ ห้ามข้าม gate ถ้า Coordinator ยังไม่อนุมัติ

## Gate 0: Intake

Owner: Coordinator

```text
อ่าน requirement
ตรวจเอกสารที่เกี่ยวข้อง
ระบุ scope และ out-of-scope
ถามกลับถ้าข้อมูลไม่ชัด
```

Output:

```text
task objective
affected areas
agent assignment plan
acceptance criteria
```

## Gate 1: Task Breakdown

Owner: Orchestrator

```text
แยกงานเป็น prompt เฉพาะ agent
กำหนดไฟล์ที่เป็น ownership
กำหนด input/output และ validation command แบบ Docker เท่านั้น
กำหนด handoff target
```

Output goes to:

```text
ai-agents/tasks/YYYYMMDD-<task-key>-<agent>.md
```

## Gate 2: Implementation

Owner: Backend Develop, BO Develop, Customer Develop

```text
ทำเฉพาะงานที่ได้รับ
ห้ามแก้ไฟล์นอก ownership โดยไม่แจ้ง
ถ้าเจอ blocker ให้ทำ handoff กลับ Orchestrator/Coordinator
เมื่อ implementation และ validation ตาม task ผ่านแล้ว ต้อง stage/commit เฉพาะ scope ของตัวเองก่อนส่ง handoff
ห้ามรวม unrelated dirty files ใน commit ของตัวเอง
```

Output goes to:

```text
ai-agents/handoffs/YYYYMMDD-<task-key>-<agent>-handoff.md
```

Implementation handoff ต้องระบุ:

```text
commit hash
ไฟล์ที่ commit
validation ที่รันผ่าน Docker
unrelated dirty files ที่ยังไม่ได้แตะ ถ้ามี
```

## Gate 3: QA

Owner: QA Tester

```text
อ่าน task + handoff
เขียน/รันทดสอบตาม acceptance criteria
บันทึกผลผ่าน/ไม่ผ่าน
แยก defect เป็น actionable items
```

Output goes to:

```text
ai-agents/reports/YYYYMMDD-<task-key>-qa-report.md
```

## Gate 4: Coordinator Review

Owner: Coordinator

```text
อ่าน implementation handoff
อ่าน QA report
ตรวจ rule และ source of truth
ตัดสินใจ approve, revise, หรือ ask user
```

Output goes to:

```text
ai-agents/decisions/YYYYMMDD-<task-key>-decision.md
```

## Gate 5: Git Boundary Before New Milestone

Owner: Coordinator

ใช้ gate นี้เมื่อ task/milestone ล่าสุดผ่าน Coordinator approval แล้ว และกำลังจะขึ้น M ใหม่

```text
หยุดงานใหม่ก่อน
ตรวจ git status
แยก approved scope ออกจาก unrelated workspace noise
stage เฉพาะงานที่ผ่าน approval และเกี่ยวข้อง
commit ด้วยข้อความที่สะท้อน milestone/task ที่ปิด
push branch ปัจจุบัน
ยืนยันว่า push สำเร็จก่อนสั่ง Orchestrator เปิด M ถัดไป
```

ถ้า commit/push ไม่สำเร็จ:

```text
ห้ามเริ่ม M ใหม่
รายงาน blocker ให้ผู้ใช้
รอคำสั่งผู้ใช้หรือแก้ปัญหา git ให้เรียบร้อยก่อน
```
