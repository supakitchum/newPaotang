# Codex Native Runner

ไฟล์นี้ระบุวิธีทำ AUTO Mode runner ใน Codex โดยใช้ multi-agent spawn tool จาก Coordinator chat

## Purpose

Codex Native Runner คือพฤติกรรมของ Coordinator chat ที่เปิด sub-agent จาก trigger files ด้วยเครื่องมือ multi-agent ของ Codex

นี่ไม่ใช่ shell daemon ใน repo เพราะ repo script ไม่สามารถเรียก Codex `spawn_agent` ได้เองโดยตรง

## Runner Owner

```text
Coordinator chat acts as runner controller
background runner protocol controls status, claim, heartbeat, and logs
sub-agent is opened by Codex multi-agent spawn tool
```

Coordinator ยังห้ามทำ implementation เองเหมือนเดิม การ spawn sub-agent จาก trigger ไม่ถือว่า Coordinator ลงมือแก้โค้ด

## Required Tool

```text
multi_agent_v1.spawn_agent
```

ถ้า tool นี้ไม่พร้อม ให้ fallback เป็น MANUAL Mode ตาม `ai-sub-agents/workflow/execution-mode.md`

## Trigger Scan

Coordinator runner loop ต้อง scan:

```text
ai-sub-agents/triggers/**/*-trigger.md
```

เลือกเฉพาะ trigger ที่:

```text
status: PENDING
execution mode: AUTO
dependencies complete
no existing claim file
not CANCELLED
no reusable agent already handling the same trigger
if no registry/agent_id exists for this role+task, first spawn is allowed
if registry already has an old agent_id for this role+task, replacement spawn has spawn_new:<agent> or Coordinator/User decision
```

## Agent Type Mapping

ใช้ `spawn_agent` ด้วย `agent_type: worker` สำหรับทุก role execution:

```text
Orchestrator -> worker
Dev Backend -> worker
Dev BO Central -> worker
Dev BO Partner -> worker
Dev Customer -> worker
QA Tester -> worker
GitOps -> worker
```

ห้ามใช้ runner เปิด work ให้ agent ที่ไม่ได้ถูกระบุใน trigger

## Spawn Prompt Inputs

ทุก spawn prompt ต้องส่ง context เหล่านี้:

```text
canonical worktree path
role name
role file
memory file
trigger file
task file
source decision
expected output path
execution mode
status ownership rule
worktree start gate
test env/test DB rule
shared lock rule when relevant
QA browser env rule when relevant
task size and flow mode
reuse policy
spawn control
poll interval
```

ใช้ template:

```text
ai-sub-agents/templates/codex-spawn-prompt-template.md
```

## Claim And Heartbeat

ก่อน spawn:

```text
check ai-sub-agents/runner/agents for same task_key + role
reuse/resume existing active agent before spawning
if no registry/agent_id exists, first spawn automatically and store agent_id
if existing agent_id cannot be reused/resumed, request Coordinator/User replacement decision unless trigger/decision has matching spawn_new:<agent>
create claim file atomically
write initial heartbeat
update trigger status to RUNNING
write runner log status transition
```

ขณะ sub-agent ทำงาน:

```text
keep heartbeat fresh
poll expected handoff/report every 60-120 seconds
send follow-up input to the same agent if output needs protocol correction
wait for expected handoff/report
do not edit implementation files
do not duplicate sub-agent work locally
```

หลัง sub-agent จบ:

```text
validate expected output exists
validate handoff/report protocol sections
update trigger status to DONE or BLOCKED
update agent registry to IDLE_READY, BLOCKED, STALE, or CLOSED
write runner log
route next gate according to stage-gates.md
```

## Reuse Before Spawn

Codex runner controller must prefer reuse:

```text
same task_key + role with IDLE_READY/ASSIGNED registry -> send_input to that agent
closed but resumable session -> resume that agent
missing registry for role+task -> first spawn_agent allowed
matching spawn_new:<agent> -> spawn new generation and update registry history
STALE/CLOSED/BLOCKED registry without spawn_new:<agent> -> ask Coordinator/User whether to resume, retry, spawn replacement, or cancel
```

Never spawn a second agent only because the first one already wrote a handoff/report and returned control. Poll and close the trigger first.

## User-Controlled Replacement Spawn

If a registry file already has `agent_id`, runner must not spawn a replacement for the same role+task without either a matching `spawn_new:<agent>` command or a Coordinator/User decision.

Required decision evidence:

```text
old agent_id
reason reuse/resume is not possible
approved action: retry same agent | resume | spawn replacement | cancel | spawn_new:<agent>
replacement trigger path when applicable
```

Without that decision, mark the trigger `BLOCKED` or keep it `PENDING` and write the reason to runner log.

`spawn_new:<agent>` applies only when `<agent>` matches the trigger target slug. A `spawn_new:dev-customer` command must not replace `qa-tester`, `orchestrator`, or any other role.

## Wait Policy

Runner ควร wait เฉพาะ trigger ที่ block gate ถัดไป

```text
Orchestrator trigger blocks all later work
Dev triggers can run parallel only when dependency graph allows
QA trigger waits for all dev triggers DONE
GitOps trigger waits for Coordinator approval and QA PASS
```

## Safety

Runner must not:

```text
edit apps/**
run migrations
run tests itself unless acting as the spawned target agent is explicitly impossible
decide QA pass/fail
decide approval
commit or push outside GitOps trigger
start a trigger with incomplete dependencies
start a trigger with an existing claim
spawn duplicate role+task agents while a reusable/resumable agent exists
spawn replacement role+task agent without matching spawn_new:<agent> or Coordinator/User decision
```

## Completion

Coordinator can tell the user work is complete only after:

```text
all required trigger statuses are DONE
QA report is accepted by Coordinator
GitOps report exists when commit/push/runtime DB update was required
final worktree state is known
```
