# Sub-Agent Reuse Policy

Reuse policy ลดเวลาและ token จากการเปิด sub-agent ใหม่ซ้ำ ๆ โดยให้ runner ส่งงานต่อให้ agent เดิมเมื่อยังเหมาะสม

## Registry

Runner ต้องเก็บสถานะ agent ที่เปิดแล้วไว้ที่:

```text
ai-sub-agents/runner/agents/YYYYMMDD-<task-key>-<role>.md
```

ใช้ template:

```text
ai-sub-agents/templates/agent-registry-template.md
```

## Agent Status

```text
WARMING
IDLE_READY
ASSIGNED
BLOCKED
STALE
CLOSED
```

## Reuse Priority

ก่อน `spawn_agent` ใหม่ runner ต้องตรวจตามลำดับ:

```text
1. มี registry role+task เดียวกันที่ status เป็น IDLE_READY หรือ ASSIGNED และ agent ยัง active หรือไม่
2. ถ้ามี ให้ส่งคำสั่งต่อด้วย send_input/resume mechanism ของ Codex แทน spawn ใหม่
3. ถ้า agent ปิดแล้วแต่ resumable ให้ resume agent เดิม
4. ถ้ายังไม่มี registry/agent_id สำหรับ role+task ให้ runner ทำ first spawn ได้ทันทีและบันทึก agent_id
5. ถ้ามี agent_id เดิมแล้วแต่ต้องการตัวใหม่ ต้องมีคำสั่ง `spawn_new:<agent>` หรือ Coordinator/User replacement decision
```

## Spawn Control Command

ค่า default คือ reuse:

```text
spawn_control: auto
```

`auto` หมายถึง:

```text
no agent_id yet -> runner first-spawns automatically
agent_id exists and reusable -> runner reuses/resumes it
agent_id exists but cannot reuse/resume -> runner blocks and asks Coordinator/User
```

ถ้าต้องการบังคับเปิด agent ใหม่เฉพาะรายตัว ให้ใส่คำสั่งนี้ใน user request, Coordinator decision, หรือ trigger:

```text
spawn_new:<agent>
```

Allowed agent slugs:

```text
orchestrator
dev-backend
dev-bo-central
dev-bo-partner
dev-customer
qa-tester
gitops
```

ตัวอย่าง:

```text
spawn_new:orchestrator
spawn_new:dev-customer
spawn_new:qa-tester
```

คำสั่ง `spawn_new:<agent>` มีผลเฉพาะ target agent ที่ตรงชื่อเท่านั้น ห้ามใช้เป็นเหตุผลเปิด agent อื่นเพิ่ม

เมื่อมี `spawn_new:<agent>` ที่ตรง target agent:

```text
runner may spawn a new generation for that role+task
old agent_id must remain in registry history
new agent_id becomes current agent_id
runner log must record command, old agent_id, new agent_id, and decision path
```

## User-Controlled Replacement Spawn

การ spawn agent ใหม่หลังเคยมี agent_id สำหรับ role+task เดิมแล้ว ต้องเป็นการตัดสินใจของ User/Coordinator ไม่ใช่ runner ตัดสินใจเงียบ ๆ

Runner ทำได้ทันทีเฉพาะ:

```text
first spawn ของ role+task ที่ยังไม่มี registry
reuse/resume/send_input ไปยัง agent_id เดิม
spawn replacement เมื่อมี spawn_new:<agent> ที่ตรง target agent
mark BLOCKED เมื่อ agent เดิม stale/closed/resume ไม่ได้
```

Runner ต้องหยุดและขอ Coordinator/User decision ก่อน spawn replacement เมื่อ:

```text
registry มี agent_id เดิมแล้วแต่ agent เป็น STALE
agent CLOSED แล้วและ resume ไม่ได้
agent BLOCKED แต่ยังไม่มี Coordinator remediation/replacement decision
output validation failure ต้องการเปิด agent ใหม่แทนการส่ง correction ให้ agent เดิม
ต้องการ parallel duplicate agent role เดียวกันใน task เดียวกัน
```

Decision ต้องระบุ:

```text
old agent_id
reason replacement is needed
whether to resume, retry same agent, spawn replacement, cancel, or use spawn_new:<agent>
new trigger or existing trigger to use
scope/risk of lost context
```

ถ้าไม่มี decision ให้คง trigger เป็น `BLOCKED` หรือ `PENDING` ตามสถานะ dependency และบันทึกใน runner log

## Long-Lived By Role

```text
Orchestrator: long-lived per task/milestone; อย่าปิดหลังแตก task รอบแรก เพราะอาจต้องตรวจ completion/remediation
Dev agents: reuse สำหรับ implementation/remediation ของ task เดิม
QA Tester: reuse สำหรับ QA rerun ของ task เดิม
GitOps: short-lived ได้ แต่ถ้า GitOps failure ต้อง reuse/resume agent เดิมสำหรับ report/blocker context
```

## Prewarm Rule

Prewarm ใช้ได้เฉพาะ role ที่ Coordinator/Orchestrator ระบุว่าจะใช้แน่นอนใน milestone นั้น

```text
prewarm Orchestrator for STANDARD/FULL work
prewarm primary dev-agent for FAST_PATH only when runner latency matters
do not prewarm conditional agents just in case
do not prewarm backend for customer-only suspicion without evidence
```

## Close Rule

ปิดหรือ mark `CLOSED` เมื่อ:

```text
GitOps complete และ Coordinator สรุปงานแล้ว
Coordinator cancel task
agent stale เกิน timeout และ runner log ระบุเหตุผล
agent reported unrecoverable BLOCKED และ Coordinator ตัดสินเปิด replacement
```

## Registry Hygiene

Registry เป็น operational state ไม่ใช่ source of truth

Runner ต้อง update:

```text
agent_id
previous_agent_ids
role
task_key
status
spawn_generation
spawn_control
replacement_requires_user_decision
last_used_at
current trigger
expected output
summary of retained context
close reason when closed
replacement decision path
```
