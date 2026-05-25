# Memory Maintenance

Memory ช่วยลด context แต่ต้องไม่กลายเป็น source of truth ปลอมหรือ context ก้อนใหม่

## Maintenance Triggers

ให้ทำ memory maintenance เมื่อ:

```text
memory.md เกินประมาณ 200 บรรทัด
มี QA/Coordinator flag ว่า memory stale
memory ขัดกับ source of truth ปัจจุบัน
ครบทุก 10 task ของ agent นั้น
Orchestrator เปิด memory-maintenance task รายเดือน
```

## Maintenance Rules

```text
prune task-specific details ที่หมดอายุเร็ว
รวม duplicate notes
ลบ assumption ที่ไม่ได้ verify
เพิ่ม last verified/source ให้ gotcha สำคัญ
ห้ามเก็บ secret/token/password/private key/PII/production credential
```

## Memory Entry Quality

Good entry:

```text
short
reusable
has source or last verified note when possible
points to file/doc rather than copying long content
```

Bad entry:

```text
large pasted docs
full implementation snippets
temporary task chatter
unverified assumptions
anything that overrides current task/docs/code
```

## Review Ownership

```text
each agent owns its own memory
Coordinator can flag any memory as stale
QA Tester can flag memory that caused wrong test assumptions
Orchestrator can create a memory-maintenance task
```

## Handoff Requirement

When memory is pruned or corrected, handoff/report must include:

```text
memory file changed
reason
summary of removed/corrected/added entries
source used to verify correction
```
