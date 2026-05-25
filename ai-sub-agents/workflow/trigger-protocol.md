# Trigger Protocol

Trigger protocol ทำให้การเปิด sub-agent เป็นหลักฐานชัดเจน ไม่ใช่แค่เขียน task แล้วถือว่างานเริ่มเอง

Default execution mode is AUTO. In AUTO Mode, a background runner watches trigger files and starts target agents.

## Trigger File Naming

```text
ai-sub-agents/triggers/YYYYMMDD-<task-key>-<agent>-trigger.md
```

## Trigger Status

ใช้สถานะเหล่านี้เท่านั้น:

```text
PENDING
RUNNING
DONE
BLOCKED
CANCELLED
```

## Who Can Trigger Whom

```text
Coordinator -> Orchestrator only
Orchestrator -> Dev Backend / Dev BO Central / Dev BO Partner / Dev Customer / QA Tester
Coordinator -> GitOps only after QA PASS is accepted
```

Coordinator ห้าม trigger dev-agent โดยตรง และ Orchestrator ห้าม trigger GitOps

## Required Trigger Fields

ทุก trigger file ต้องระบุ:

```text
execution mode
task key
target agent
status
source decision
task file
required memory file
required source-of-truth docs
expected handoff/report
worktree start gate
test env/test DB requirement
DB change declaration
shared file locks required, if any
Next Agent
```

## Lifecycle

```text
PENDING -> RUNNING -> DONE
PENDING -> RUNNING -> BLOCKED
PENDING -> CANCELLED
RUNNING -> CANCELLED only by Coordinator decision
```

Rules:

```text
AUTO Mode: runner marks trigger RUNNING before implementation/testing work starts
AUTO Mode: runner marks trigger DONE only after required handoff/report exists
AUTO Mode: runner marks trigger BLOCKED when a blocker prevents completion
AUTO Mode: agent must not edit trigger status directly
MANUAL Mode: target agent/operator may update trigger status
agent must not work from an old trigger if a newer trigger exists for the same task and agent
AUTO runner must follow the same status lifecycle
```

## Claim / Heartbeat / Timeout

AUTO runner must use:

```text
claim file: ai-sub-agents/runner/claims/YYYYMMDD-<task-key>-<agent>-trigger.claim.md
heartbeat file: ai-sub-agents/runner/heartbeats/YYYYMMDD-<task-key>-<agent>-trigger.heartbeat.md
runner log: ai-sub-agents/runner/logs/YYYYMMDD-<task-key>-<agent>-runner-log.md
```

Default:

```text
timeout_minutes: 30
max_retries: 1
```

If heartbeat is stale past timeout, runner marks trigger `BLOCKED` and sends blocker to Coordinator/Orchestrator according to gate ownership.

## Trigger Is Not Completion

สร้าง trigger file ไม่ได้แปลว่างานเสร็จ

งานจะข้าม gate ได้ต่อเมื่อมี:

```text
trigger status DONE
required handoff/report exists
Next Agent matches the stage gate
```

## Cancellation

Coordinator เท่านั้นที่ cancel trigger ได้

เมื่อ cancel:

```text
set status CANCELLED
record reason
record replacement trigger or decision if any
do not continue work from cancelled trigger
```
