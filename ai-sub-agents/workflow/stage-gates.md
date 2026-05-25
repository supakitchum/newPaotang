# Stage Gates

งานทุกชิ้นต้องผ่าน gate ตามลำดับ ห้ามข้าม gate

## Gate 0: Intake

Owner: Coordinator

```text
รับ requirement จาก user
ระบุ Execution Mode: AUTO ใน decision
อ่าน Coordinator memory เป็น cache
อ่าน source of truth
กำหนด scope และ out-of-scope
กำหนด milestone/lifecycle
กำหนด acceptance criteria
กำหนด agent assignment
เขียน trigger ให้ Orchestrator เท่านั้น
อัปเดต Coordinator memory ถ้ามี reusable decision pattern ใหม่
```

Output:

```text
ai-sub-agents/decisions/YYYYMMDD-<task-key>-decision.md
ai-sub-agents/triggers/YYYYMMDD-<task-key>-orchestrator-trigger.md
Next Agent: Orchestrator
```

Coordinator ห้ามเขียนโค้ดใน gate นี้

## Gate 1: Task Breakdown

Owner: Orchestrator

```text
อ่าน Coordinator decision
อ่าน Orchestrator memory เป็น cache
อ่าน Orchestrator trigger; AUTO runner owns trigger status
แตกงานเป็น task prompt ตาม agent ownership
สร้าง trigger ให้ dev-agent ที่เกี่ยวข้อง
สร้าง shared file lock ถ้ามี shared risk
กำหนด depends_on, can_run_parallel, blocking_outputs, unblocks
กำหนด input/output และ acceptance criteria ต่อ agent
กำหนด automated test expectation
กำหนด test env/test DB requirement
กำหนด handoff target
ส่ง handoff ให้ runner mark Orchestrator trigger DONE เมื่อ task/trigger/handoff ครบ
อัปเดต Orchestrator memory ถ้ามี reusable breakdown pattern ใหม่
```

Output:

```text
ai-sub-agents/tasks/YYYYMMDD-<task-key>-<agent>.md
ai-sub-agents/triggers/YYYYMMDD-<task-key>-<agent>-trigger.md
ai-sub-agents/locks/YYYYMMDD-<task-key>-<agent>-lock.md when needed
ai-sub-agents/handoffs/YYYYMMDD-<task-key>-orchestrator-handoff.md
```

## Gate 2: Implementation

Owner: Dev Backend, Dev BO Central, Dev BO Partner, Dev Customer

```text
ทำเฉพาะ task ที่ได้รับจาก Orchestrator
อ่าน memory ของตัวเองเป็น cache
อ่าน trigger ของตัวเอง; AUTO runner owns trigger status
ผ่าน worktree start gate ก่อนแก้ไฟล์
ยืนยัน shared file lock ก่อนแก้ shared file
แก้เฉพาะไฟล์ตาม ownership
เพิ่มหรืออัปเดต automated test ประกอบ feature
รัน validation บน test env/test DB เมื่อ task เกี่ยวกับ backend/data
ห้ามอัปเดต local runtime DB จริง
release lock เมื่อจบงานหรือบันทึก blocker
เขียน requested trigger final status ใน handoff
อัปเดต memory ของตัวเองถ้ามี reusable pattern/gotcha/command ใหม่
```

Output:

```text
ai-sub-agents/handoffs/YYYYMMDD-<task-key>-<agent>-handoff.md
Next Agent: Orchestrator
```

## Gate 3: Orchestrator Completion Check

Owner: Orchestrator

```text
รวบรวม handoff จาก dev-agent ทุกตัว
อ่าน Orchestrator memory เป็น cache
ตรวจ trigger ของ dev-agent เป็น DONE หรือ BLOCKED พร้อม blocker
ตรวจ dependency graph และ blocking outputs
ตรวจว่า task ครบตาม assignment
ตรวจว่า automated test evidence มีครบหรือมี risk note
ตรวจว่าไม่มี cross-role change ที่ไม่ได้รับอนุมัติ
ตรวจว่า shared locks RELEASED
สร้าง QA task และ QA trigger เมื่อพร้อม
ส่ง QA task เมื่อพร้อม
อัปเดต Orchestrator memory ถ้ามี reusable completion-check pattern ใหม่
```

Output:

```text
ai-sub-agents/tasks/YYYYMMDD-<task-key>-qa-tester.md
ai-sub-agents/triggers/YYYYMMDD-<task-key>-qa-tester-trigger.md
ai-sub-agents/handoffs/YYYYMMDD-<task-key>-orchestrator-ready-for-qa-handoff.md
Next Agent: QA Tester
```

ถ้างานยังไม่ครบ ให้ส่งกลับ dev-agent ที่เกี่ยวข้องผ่าน remediation task

## Gate 4: QA

Owner: QA Tester

```text
อ่าน Coordinator decision, Orchestrator task, และ dev handoff
อ่าน QA Tester memory เป็น cache
อ่าน QA trigger; AUTO runner owns trigger status
ผ่าน worktree start gate ก่อนทดสอบ
ยืนยัน QA browser env/test DB wiring ก่อน visible Chrome QA
ทดสอบทุกอย่างบน test env/test DB ก่อนเสมอ
รัน automated/focused regression ตาม acceptance criteria
เปิด Google Chrome จริงแบบ visible สำหรับ browser acceptance
บันทึก evidence และผล PASS/FAIL
เขียน requested trigger final status ใน QA report
อัปเดต QA Tester memory ถ้ามี reusable QA pattern/gotcha/test data ใหม่
```

Output:

```text
ai-sub-agents/reports/YYYYMMDD-<task-key>-qa-report.md
Next Agent: Coordinator
```

QA ห้ามอัปเดต local runtime DB จริง

## Gate 5: Coordinator Review

Owner: Coordinator

```text
อ่าน QA report
อ่าน Coordinator memory เป็น cache
ตรวจ risk, defect, evidence, และ test env compliance
ตัดสิน PASS, FAIL, PASS WITH RISK, หรือ ASK USER
ถ้า PASS ให้สร้าง GitOps trigger
อัปเดต Coordinator memory ถ้ามี reusable approval/remediation pattern ใหม่
```

Output:

```text
ai-sub-agents/decisions/YYYYMMDD-<task-key>-qa-review-decision.md
ai-sub-agents/triggers/YYYYMMDD-<task-key>-gitops-trigger.md when approved
```

Decision:

```text
PASS -> Next Agent: GitOps
FAIL/PASS WITH RISK -> Next Agent: Orchestrator
ASK USER -> hold until user answers
```

Coordinator ห้ามแก้โค้ดเองแม้ QA fail

## Gate 6: GitOps

Owner: GitOps

```text
อ่าน Coordinator approval
อ่าน GitOps memory เป็น cache
อ่าน GitOps trigger; AUTO runner owns trigger status
ผ่าน worktree start gate ก่อน stage
ตรวจ worktree
stage เฉพาะ approved scope
commit approved scope
ถ้างานมี migration/schema/data contract change ให้ migrate local runtime DB ด้วย non-destructive command
รัน smoke check หลัง local runtime DB update
push หลัง commit/migrate/smoke ผ่าน
รายงาน final worktree state
เขียน requested trigger final status ใน GitOps report
อัปเดต GitOps memory ถ้ามี reusable git/runtime/smoke pattern ใหม่
```

Output:

```text
ai-sub-agents/gitops/YYYYMMDD-<task-key>-gitops-report.md
Next Agent: Coordinator
```

ถ้า commit, migrate, smoke, หรือ push fail ให้ส่ง blocker กลับ Coordinator

ถ้า fail หลัง commit:

```text
ห้าม reset/revert/amend เอง
ห้าม push
บันทึก commit hash ใน GitOps report
ส่งกลับ Coordinator เพื่อตัดสิน remediation, amend, revert, หรือ retry
```

## Remediation Loop

เมื่อ QA ไม่ผ่าน:

```text
QA Tester -> Coordinator -> Orchestrator -> affected Dev Agent(s) -> Orchestrator -> QA Tester -> Coordinator
```

ห้ามส่ง GitOps จนกว่า Coordinator จะ approve จาก QA report ล่าสุด
