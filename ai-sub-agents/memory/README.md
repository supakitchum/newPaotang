# Agent Memory

โฟลเดอร์นี้เป็น short reusable cache แยกต่อ sub-agent เพื่อลดการอ่าน context ซ้ำเมื่อเปิด sub-agent chat ใหม่

## Structure

```text
ai-sub-agents/memory/
  coordinator/memory.md
  orchestrator/memory.md
  dev-backend/memory.md
  dev-bo-central/memory.md
  dev-bo-partner/memory.md
  dev-customer/memory.md
  qa-tester/memory.md
  gitops/memory.md
```

## Rules

```text
Memory is cache, not source of truth.
Read your own memory at the start of each new chat.
Update your own memory after each task when reusable knowledge was learned.
Keep memory around 100-200 lines per agent.
Prune stale or duplicated notes.
Do not store secrets, tokens, passwords, private keys, PII, or production credentials.
If memory conflicts with current code/docs/task, trust the current source and correct memory.
```

## Good Memory Content

```text
common Docker commands
known route/API/component patterns
test fixture names
visible Chrome QA checklist
runtime migration caution
gotchas discovered during previous tasks
links to specific source-of-truth docs
```

## Bad Memory Content

```text
large copied docs
full code snippets
secret values
old task details that are no longer reusable
unverified assumptions
anything that would override Coordinator decision or current code
```
