# Execution Mode

ระบบ `ai-sub-agents` รองรับ 2 execution modes

ค่าเริ่มต้นคือ `AUTO`

## Modes

```text
AUTO
MANUAL
```

## Default: AUTO Mode

ใน AUTO Mode ผู้ใช้คุยกับ Coordinator chat เดียว และ background sub-agent runner เป็นผู้เปิด/รัน sub-agent จาก trigger files

Expected flow:

```text
User -> Coordinator chat
Coordinator creates Orchestrator trigger
runner starts Orchestrator
Orchestrator creates dev-agent triggers
runner starts dev-agents
Orchestrator creates QA trigger
runner starts QA Tester
Coordinator reviews QA
Coordinator creates GitOps trigger
runner starts GitOps
Coordinator summarizes completion to user
```

AUTO Mode rules:

```text
Coordinator does not manually run dev-agent work
Orchestrator does not manually run GitOps
runner must read trigger files and status before starting agents
runner owns trigger status in AUTO Mode
runner must atomically claim trigger before starting agents
runner must write heartbeat while trigger is RUNNING
runner must enforce dependencies before starting agents
runner must not start CANCELLED triggers
runner must not start an agent without a matching trigger file
runner must report BLOCKED trigger status back through Markdown handoff/report
```

## Manual Mode

Manual Mode เป็น fallback เมื่อ background runner ยังไม่พร้อม หรือ Coordinator/User สั่งใช้ manual ชัดเจน

ใน Manual Mode:

```text
Coordinator still creates trigger files
User or operator opens the target sub-agent chat manually
Target sub-agent reads its trigger/task/memory and continues the same protocol
All handoff/report/decision files are still required
```

Manual Mode ไม่อนุญาตให้ข้าม Orchestrator, QA, หรือ GitOps gate

## Mode Declaration

ทุก Coordinator decision ที่เปิดงานใหม่ต้องระบุ:

```text
Execution Mode: AUTO
Fallback Mode: MANUAL if background runner is unavailable
```

ถ้าต้องใช้ Manual Mode ตั้งแต่แรก ต้องระบุเหตุผลใน decision

## Runner Contract For AUTO Mode

background runner ต้องทำตามนี้:

```text
watch ai-sub-agents/triggers/**
start only PENDING triggers
create atomic claim before starting agent
verify depends_on and blocking_outputs
set trigger status to RUNNING before starting agent
pass trigger path, task path, role path, memory path, and source decision to agent
write heartbeat while agent is running
wait for expected handoff/report
set status DONE only when expected output exists
set status BLOCKED if agent reports blocker
never edit implementation code itself
```

Runner ไม่ใช่ agent และห้ามตัดสิน scope, QA, approval, git, หรือ DB เอง

## Completion In One Chat

ใน AUTO Mode งานควรจบใน Coordinator chat เดียวจากมุมผู้ใช้

Coordinator final summary ต้องอ้างอิง:

```text
Coordinator decision
Orchestrator handoff
dev-agent handoffs
QA report
GitOps report when applicable
```
