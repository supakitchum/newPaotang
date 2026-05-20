# Handoff Protocol

ทุก agent ต้องส่งต่องานด้วยไฟล์ handoff/report ห้ามจบงานแบบไม่มีหลักฐาน

## Handoff File Naming

```text
ai-agents/handoffs/YYYYMMDD-<task-key>-<agent>-handoff.md
ai-agents/reports/YYYYMMDD-<task-key>-qa-report.md
ai-agents/decisions/YYYYMMDD-<task-key>-decision.md
```

## Required Handoff Sections

```markdown
# <Task Key> Handoff

## Agent

## Task

## Worktree / HEAD

## What Was Done

## Files Changed

## Validation

## Known Risks

## Questions For Coordinator

## Next Agent
```

## Worktree Evidence

หัวข้อ `Worktree / HEAD` ต้องมีข้อมูลขั้นต่ำ:

```text
canonical worktree path
branch
git rev-parse HEAD
git rev-parse origin/develop
git status --short --branch
```

ถ้า agent ไม่ได้อยู่ที่ `/Users/supakit/WorkSpace/www/newPaotang` หรือ HEAD ไม่ตรงกับ `origin/develop` โดยไม่มีคำสั่งเฉพาะงาน ให้หยุดและส่ง blocker กลับ Coordinator ก่อนทำงานต่อ

## Coordinator Dispatch Evidence

เมื่อ Coordinator เปิดงานใหม่ในบอร์ด/decision ต้องระบุ:

```text
latest pushed branch
latest pushed commit hash
dirty/untracked files ถ้ามีและเหตุผลว่าทำไมยังไม่ commit
Next Agent: Orchestrator
```

Coordinator ห้ามบันทึกว่างานถูก dispatch แล้วถ้าเป็นเพียง board instruction ให้เขียนชัดเจนว่า `user must send this to Orchestrator chat`

## Required QA Report Extra Section

QA report ทุกฉบับต้องเพิ่มหัวข้อนี้ก่อน `Recommendation`:

```markdown
## Runtime Restore / Login Smoke
```

หัวข้อนี้ต้องบันทึกว่า QA คืนสภาพ local Docker runtime แล้วหรือไม่ โดยเฉพาะ:

```text
worktree path และ HEAD ที่ใช้ทดสอบ
test database name used for destructive commands
confirmation that destructive DB commands used `newpaotang_test`, not runtime DB `newpaotang`
db:seed after DB-touching tests only for runtime smoke, never as a substitute for destructive restore on the main DB
platform:smoke result with seeded-logins
central admin login API status
back-office /login status
back-office /admin/login redirect target
back-office restart/recreate after Nuxt build/browser QA when applicable
```

ถ้าไม่ได้รันเพราะ task ไม่แตะ runtime เลย ต้องเขียนเหตุผลชัดเจน ถ้ารันแล้วไม่ผ่านห้ามสรุปเป็น clean PASS

## Next Agent Rule

ทุก handoff ต้องระบุ `Next Agent` เสมอ:

```text
Coordinator
Orchestrator
Backend Develop
BO Develop
Customer Develop
QA Tester
None
```

ถ้าไม่แน่ใจ ให้ใส่ `Coordinator` และอธิบายเหตุผล

## Blocker Rule

ถ้าเจอ blocker ที่เกินบทบาท:

```text
หยุดงานในส่วนนั้น
เขียน blocker ลง handoff
ระบุทางเลือก 1-3 ทางถ้ามี
ส่งต่อ Coordinator หรือ Orchestrator
```
