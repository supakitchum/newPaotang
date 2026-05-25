# Handoff Protocol

ทุก agent ต้องส่งต่องานด้วยไฟล์ Markdown ห้ามจบงานแบบไม่มีหลักฐาน

## File Naming

```text
Task:      ai-sub-agents/tasks/YYYYMMDD-<task-key>-<agent>.md
Handoff:   ai-sub-agents/handoffs/YYYYMMDD-<task-key>-<agent>-handoff.md
QA Report: ai-sub-agents/reports/YYYYMMDD-<task-key>-qa-report.md
Decision:  ai-sub-agents/decisions/YYYYMMDD-<task-key>-decision.md
GitOps:    ai-sub-agents/gitops/YYYYMMDD-<task-key>-gitops-report.md
```

## Required Handoff Sections

```markdown
# <Task Key> Handoff

## Agent

## Task

## Worktree / HEAD

## Trigger Status

## What Was Done

## Files Changed

## Automated Tests Added Or Updated

## Validation

## Test Env / DB Safety

## Shared File Locks

## Memory Updates

## Known Risks

## Questions For Coordinator

## Next Agent
```

## Worktree Evidence

ทุก handoff/report ต้องบันทึก:

```text
canonical worktree path
branch
git rev-parse HEAD
git rev-parse origin/develop
git status --short --branch
worktree start gate commands run
dirty files before work
dirty files after work
```

ถ้าไม่ได้อยู่ที่ `/Users/supakit/WorkSpace/www/newPaotang` ต้องหยุดและส่ง blocker กลับ Coordinator

## Trigger Evidence

ทุก handoff/report ต้องบันทึก:

```text
trigger file
trigger status before work
trigger status after work
trigger status owner
requested final status
runner claim file
heartbeat file
```

ถ้าไม่มี trigger file หรือ trigger ถูก CANCELLED ต้องหยุดและส่ง blocker

ใน AUTO Mode runner เป็นเจ้าของ trigger status; agent ต้องเขียน requested final status ใน handoff/report แทนการแก้ status เอง

## Test Env Evidence

ถ้างานแตะ backend, database, migration, seed, data contract, API, หรือ browser flow ที่ mutate data ต้องบันทึก:

```text
APP_ENV used
DB_DATABASE used
confirmation that destructive DB commands used test DB only
confirmation that local runtime DB was not destructively reset
```

## QA Browser Env Evidence

ถ้ามี visible Chrome QA ต้องบันทึก:

```text
browser URL
frontend service
API base URL
APP_ENV
DB_DATABASE
tenant/domain
account/role
test API/test DB proof
evidence path
```

ถ้าพิสูจน์ไม่ได้ว่า browser ใช้ test env/test DB ห้าม clean PASS

## Memory Update Evidence

ทุก handoff/report ต้องระบุ:

```text
memory file read
memory file updated: Yes/No
summary of reusable facts added or corrected
```

ถ้า memory ขัดกับ source of truth ระหว่างทำงาน ต้องแก้ memory หรือบันทึก blocker ให้ Coordinator

## Shared Lock Evidence

ถ้า task แก้ shared file ต้องบันทึก:

```text
lock file
locked files
lock status before work
lock status after work
release evidence
```

ถ้า lock ยังไม่ RELEASED Orchestrator ห้ามส่ง QA

## QA Report Extra Requirements

QA report ต้องมีหัวข้อ:

```markdown
## Test Env / Test DB Evidence

## Visible Google Chrome Evidence

## QA Browser Env Evidence

## Memory Updates

## Runtime DB Safety
```

ถ้าไม่มี evidence เหล่านี้ ห้ามสรุป clean PASS

## GitOps Report Extra Requirements

GitOps report ต้องมีหัวข้อ:

```markdown
## Coordinator Approval

## Commit / Push

## Failure After Commit

## Local Runtime DB Update

## Smoke Check

## Memory Updates

## Final Worktree State
```

ถ้ามี migration/schema/data contract change แต่ไม่ได้อัปเดต local runtime DB ต้องระบุเหตุผลและส่งกลับ Coordinator

## Next Agent Values

ใช้ชื่อเหล่านี้เท่านั้น:

```text
Coordinator
Orchestrator
Dev Backend
Dev BO Central
Dev BO Partner
Dev Customer
QA Tester
GitOps
None
```

ถ้าไม่แน่ใจ ให้ใส่ `Coordinator` และอธิบายเหตุผล

## Blocker Rule

ถ้าเจอ blocker ที่เกินบทบาท:

```text
หยุดงานในส่วนนั้น
เขียน blocker ลง handoff/report
ระบุผลกระทบ
เสนอทางเลือกถ้ามี
ส่งต่อ Coordinator หรือ Orchestrator
```
