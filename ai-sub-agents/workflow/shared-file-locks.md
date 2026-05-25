# Shared File Locks

กฎนี้ป้องกันงานชนกัน โดยเฉพาะ `apps/back-office/**` ที่ Dev BO Central และ Dev BO Partner ใช้ร่วมกัน

## Lock File Naming

```text
ai-sub-agents/locks/YYYYMMDD-<task-key>-<agent>-lock.md
```

## When Lock Is Required

ต้องสร้าง lock เมื่อ task จะแก้:

```text
shared apps/back-office components/composables/utils/layouts/plugins
files used by both central and partner/tenant flows
docs/templates/rules shared by multiple agents
any file Orchestrator marks as shared risk
```

## Lock Owner

```text
Orchestrator approves lock before dev-agent edits shared files
Dev agent records locked files in handoff
Orchestrator verifies release before sending QA
```

## Lock Fields

ทุก lock file ต้องระบุ:

```text
task key
agent
status: LOCKED | RELEASED | BLOCKED
locked files
reason
approved by Orchestrator decision/handoff
expected release handoff
```

## Conflict Rule

```text
ห้าม Dev BO Central และ Dev BO Partner แก้ shared file เดียวกันพร้อมกัน
ถ้า file เดียวกันต้องแก้ทั้งสอง flow Orchestrator ต้องกำหนดลำดับ agent ชัดเจน
agent ที่สองต้องอ่าน handoff ของ agent แรกก่อนเริ่ม
```

## Release Rule

agent release lock ได้เมื่อ:

```text
implementation done
validation completed or blocker recorded
handoff lists locked files and release status
```

Orchestrator ห้ามส่ง QA ถ้า lock ยังเป็น `LOCKED` หรือไม่มี release evidence
