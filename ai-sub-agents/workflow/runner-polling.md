# Runner Polling And Trigger Closure

Runner ต้องไม่รอแค่ sub-agent final notification เพราะ sub-agent อาจเขียน handoff/report สำเร็จแล้วแต่ session ถูกปิดหรือ timeout

## Poll Loop

สำหรับ trigger ที่เป็น `RUNNING` runner ต้อง poll expected output:

```text
default poll interval: 60-120 seconds
poll expected handoff/report path from trigger
refresh heartbeat each poll while runner still owns the trigger
write runner log for important state changes
```

## DONE Closure

ถ้า expected output มีอยู่แล้ว runner ต้อง validate protocol ทันที

Mark trigger `DONE` เมื่อ:

```text
expected handoff/report exists
requested final status is DONE or PASS-equivalent for the role
required protocol sections exist
worktree evidence exists
trigger evidence exists
validation/test evidence exists or risk is explicitly recorded
Next Agent is valid for the current stage gate
```

กรณีนี้ช่วยปิด trigger ที่ handoff/report เสร็จแล้วแต่ agent chat ถูกปิดหรือไม่ได้ส่ง final signal

## BLOCKED Closure

Mark trigger `BLOCKED` เมื่อ:

```text
expected output requests BLOCKED
handoff/report ระบุ blocker ที่ต้องใช้ Coordinator/Orchestrator decision
heartbeat stale past timeout
dependency กลายเป็น BLOCKED/CANCELLED
protocol validation failed and cannot be fixed by polling
```

## No Duplicate Spawn Rule

ห้าม spawn agent ใหม่สำหรับ trigger เดิมถ้า:

```text
trigger status is RUNNING
claim file exists and heartbeat is fresh
expected handoff/report already exists and is waiting validation
registry has ASSIGNED/IDLE_READY agent for same role+task
registry has any previous agent_id and no matching spawn_new:<agent> or Coordinator/User replacement decision exists
```

ให้ poll/validate/reuse agent เดิมก่อน

## Output Validation Failure

ถ้า output มีแต่ขาด section:

```text
runner should send one correction request to the same reusable agent when possible
do not open a second agent unless the first agent is CLOSED/STALE and matching spawn_new:<agent> or Coordinator/User approved replacement spawn exists
record validation failure in runner log
```

## Polling Evidence

Runner log ต้องบันทึก:

```text
poll interval
poll timestamps
expected output path
output found at
protocol validation result
final trigger status update
reuse/resume decision
```
