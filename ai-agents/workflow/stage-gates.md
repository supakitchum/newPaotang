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
กำหนด input/output และ validation command
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
```

Output goes to:

```text
ai-agents/handoffs/YYYYMMDD-<task-key>-<agent>-handoff.md
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

