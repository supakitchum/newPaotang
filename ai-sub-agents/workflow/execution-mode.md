# Execution Mode

ระบบ `ai-sub-agents` รองรับ execution mode และ flow mode แยกกัน

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
Coordinator classifies Task Size and Flow Mode
FAST_PATH SMALL: Coordinator creates owning dev-agent trigger directly
STANDARD/FULL: Coordinator creates Orchestrator trigger
runner starts the target agent from trigger
STANDARD/FULL: Orchestrator creates dev-agent triggers
runner starts dev-agents
FAST_PATH: Coordinator creates QA trigger after owning dev-agent handoff when QA is required
STANDARD/FULL: Orchestrator creates QA trigger
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
runner must reuse/resume existing role+task agents before spawning duplicates
runner must poll expected handoff/report while trigger is RUNNING
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

Manual Mode ไม่อนุญาตให้ข้าม QA หรือ GitOps gate
Orchestrator ข้ามได้เฉพาะ `FAST_PATH SMALL` ที่ Coordinator decision ระบุครบ

## Mode Declaration

ทุก Coordinator decision ที่เปิดงานใหม่ต้องระบุ:

```text
Execution Mode: AUTO
Task Size: SMALL/STANDARD/FULL
Flow Mode: FAST_PATH/STANDARD/FULL
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
poll expected handoff/report every 60-120 seconds
reuse/resume existing registered agent before spawn_agent
wait for expected handoff/report
set status DONE only when expected output exists
set status BLOCKED if agent reports blocker
never edit implementation code itself
```

Runner ไม่ใช่ agent และห้ามตัดสิน scope, QA, approval, git, หรือ DB เอง

## Codex Native Runner

ใน Codex ให้ใช้ Coordinator chat เป็น runner controller และเปิด sub-agent ด้วย multi-agent spawn tool ตาม:

```text
ai-sub-agents/workflow/codex-native-runner.md
```

ถ้า multi-agent spawn tool ไม่พร้อมใช้งาน ให้ fallback เป็น MANUAL Mode

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
