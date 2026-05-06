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
