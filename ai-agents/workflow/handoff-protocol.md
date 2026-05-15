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

## What Was Done

## Files Changed

## Validation

## Known Risks

## Questions For Coordinator

## Next Agent
```

## Required QA Report Extra Section

QA report ทุกฉบับต้องเพิ่มหัวข้อนี้ก่อน `Recommendation`:

```markdown
## Runtime Restore / Login Smoke
```

หัวข้อนี้ต้องบันทึกว่า QA คืนสภาพ local Docker runtime แล้วหรือไม่ โดยเฉพาะ:

```text
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
