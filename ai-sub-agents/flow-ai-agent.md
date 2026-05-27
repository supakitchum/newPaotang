# AI Sub-Agents Flow

ไฟล์นี้เป็น entrypoint หลักของกล่อง `ai-sub-agents` สำหรับโปรเจกต์ NewPaotang

## Purpose

ระบบนี้กำหนด flow การทำงานของ AI sub-agent โดยให้ทุก agent สื่อสารกันผ่านไฟล์ Markdown เท่านั้น และแยกหน้าที่ชัดเจนระหว่าง planning, orchestration, implementation, QA, และ GitOps

## Agent Roster

| Agent | Role File | Main Responsibility |
| --- | --- | --- |
| Coordinator | `roles/coordinator.md` | รับ requirement, ตัดสินใจ scope, milestone, priority, approval; ห้ามเขียนโค้ด |
| Orchestrator | `roles/orchestrator.md` | แตกงานจาก Coordinator เป็น task prompt ให้ sub-agent |
| Dev Backend | `roles/dev-backend.md` | ทำงานทั้งหมดของ `apps/platform-api/**` |
| Dev BO Central | `roles/dev-bo-central.md` | ทำ frontend back office ฝั่ง central ใน `apps/back-office/**` |
| Dev BO Partner | `roles/dev-bo-partner.md` | ทำ frontend back office ฝั่ง partner/tenant ใน `apps/back-office/**` |
| Dev Customer | `roles/dev-customer.md` | ทำ frontend customer ใน `apps/customer/**` |
| QA Tester | `roles/qa-tester.md` | ทดสอบบน test env/test DB ก่อน และทำ visible Google Chrome QA |
| GitOps | `roles/gitops.md` | stage, commit, migrate local runtime DB เมื่อจำเป็น, smoke, push, และรายงาน worktree |

## Must Read Order

Agent ทุกตัวต้องอ่านตามลำดับนี้ก่อนเริ่มงาน:

```text
1. ai-sub-agents/flow-ai-agent.md
2. ai-sub-agents/rules/global-rules.md
3. ai-sub-agents/workflow/stage-gates.md
4. ai-sub-agents/workflow/handoff-protocol.md
5. ai-sub-agents/workflow/file-ownership.md
6. ai-sub-agents/workflow/trigger-protocol.md
7. ai-sub-agents/workflow/fast-path.md
8. ai-sub-agents/workflow/execution-mode.md
9. ai-sub-agents/workflow/background-runner.md เมื่ออยู่ AUTO Mode
10. ai-sub-agents/workflow/codex-native-runner.md เมื่อใช้ Codex AUTO runner
11. ai-sub-agents/workflow/sub-agent-reuse.md เมื่ออยู่ AUTO Mode
12. ai-sub-agents/workflow/runner-polling.md เมื่ออยู่ AUTO Mode
13. ai-sub-agents/workflow/dependency-graph.md
14. ai-sub-agents/workflow/worktree-start-gate.md
15. ai-sub-agents/workflow/shared-file-locks.md เมื่อ task มี shared file risk
16. ai-sub-agents/workflow/qa-browser-env.md เมื่อ task มี browser QA
17. ai-sub-agents/workflow/memory-maintenance.md
18. role file ของตัวเองใน ai-sub-agents/roles
19. memory ของตัวเองใน ai-sub-agents/memory/<agent>/memory.md
20. trigger file ที่เปิดงานให้ตัวเอง
21. task/prompt ที่ได้รับ
22. docs/source-of-truth ที่ task อ้างถึง
```

## Required Flow

Default execution mode:

```text
Execution Mode: AUTO
Fallback Mode: MANUAL if background runner is unavailable
```

ใน AUTO Mode ผู้ใช้คุยกับ Coordinator chat เดียว และ background runner เปิด sub-agent จาก trigger files

```text
User
  -> Coordinator
  -> Classify Task Size and Flow Mode
  -> FAST_PATH: Trigger owning Dev Agent directly when SMALL and safe
  -> STANDARD/FULL: Trigger Orchestrator
  -> Orchestrator when required
  -> Trigger Dev Agent(s)
  -> Dev Backend / Dev BO Central / Dev BO Partner / Dev Customer
  -> Orchestrator
  -> Trigger QA Tester
  -> QA Tester
  -> Coordinator
  -> Trigger GitOps
  -> GitOps
```

## Gate Summary

1. Coordinator รับงานจาก chat แล้วเขียน scope, milestone, acceptance criteria, Task Size, Flow Mode, และ agent assignment ลง Markdown
2. Coordinator ใช้ `FAST_PATH` สำหรับงาน `SMALL` ที่ปลอดภัย และ trigger owning dev-agent โดยตรงได้ตาม `workflow/fast-path.md`
3. Coordinator ใช้ `STANDARD/FULL` และสร้าง trigger ให้ Orchestrator เมื่อ scope ข้าม owner, เสี่ยง, หรือไม่ชัด
4. Orchestrator แตกงานเป็น task prompt และ trigger ให้ sub-agent ที่เกี่ยวข้อง
5. ทุก agent ต้องผ่าน worktree start gate ก่อนเริ่มงาน
6. Dev agents ทำงานเฉพาะ ownership ของตัวเอง และต้องทำ automated test ประกอบ feature
7. ถ้าแก้ shared file ต้องมี lock file และ release evidence
8. dev-agent ส่ง handoff กลับ Orchestrator ใน STANDARD/FULL หรือ Coordinator/QA gate ตาม FAST_PATH decision
9. Orchestrator ตรวจว่า handoff ครบ, trigger DONE, lock RELEASED, และงานพร้อม QA เมื่อใช้ STANDARD/FULL
10. QA Tester ทดสอบทุกอย่างบน test env/test DB ก่อนเท่านั้น
11. QA Tester เปิด Google Chrome จริงแบบ visible สำหรับ browser acceptance test และบันทึก evidence
12. Coordinator อ่าน QA report แล้วตัดสิน:
   - `PASS`: ส่ง GitOps
   - `FAIL` หรือ `PASS WITH RISK`: ส่งกลับ Orchestrator เพื่อแตก remediation task
13. Coordinator สร้าง trigger ให้ GitOps หลัง approve เท่านั้น
14. GitOps ทำงานหลัง Coordinator approve และ trigger ถูกต้องเท่านั้น

## Working Areas

```text
ai-sub-agents/tasks       task prompt จาก Orchestrator หรือ FAST_PATH Coordinator decision
ai-sub-agents/triggers    trigger record สำหรับเปิดงาน sub-agent
ai-sub-agents/handoffs    handoff ระหว่าง agent
ai-sub-agents/reports     QA report และ evidence summary
ai-sub-agents/decisions   decision/approval จาก Coordinator
ai-sub-agents/gitops      GitOps report หลัง commit/push/runtime DB update
ai-sub-agents/templates   template สำหรับ task, handoff, QA, GitOps
ai-sub-agents/memory      reusable per-agent memory cache
ai-sub-agents/locks       shared file locks
ai-sub-agents/runner      AUTO Mode claim, heartbeat, runner logs, and agent registry
```

Coordinator runner prompt:

```text
ai-sub-agents/templates/coordinator-runner-prompt.md
```

## Source Of Truth

```text
API contract: docs/openapi.yaml
Backend/API conventions: docs/api-conventions.md
Runtime policy: docs/docker-runtime-policy.md
Permissions: docs/permissions.md
Events: docs/events.md
ERD: docs/erd.md
Status enums: docs/status-enums.md
Customer integration: docs/customer-api-integration-map.md, docs/buy-flow-adapter-contract.md
Back-office UI: docs/admin-dashboard-template-guidelines.md
Routes: docs/frontend-routes.md
```

ถ้า source of truth ขัดแย้งกัน ให้หยุดและส่งคำถามกลับ Coordinator ผ่าน Markdown handoff หรือ decision request

## Non-Negotiable Rules

```text
Coordinator ห้ามเขียนโค้ด
ทุก agent คุยกันผ่านไฟล์ Markdown
Dev agents ต้องทำ automated test ประกอบ feature
QA ต้องทดสอบบน test env/test DB ก่อนเสมอ
QA browser acceptance ต้องเปิด Google Chrome จริงแบบ visible และระบุ runtime DB/API ที่ browser ใช้จริง
ห้าม destructive DB command กับ local runtime DB จริง
GitOps เท่านั้นที่อัปเดต local runtime DB หลัง Coordinator approve
Production/staging migration ต้องมี approval flow แยกต่างหาก
Agent memory เป็น cache เท่านั้น ไม่ใช่ source of truth
ทุก agent ต้องผ่าน worktree start gate ก่อนทำงาน
ทุกงานต้องมี trigger file ก่อน agent เริ่มงาน
default execution mode คือ AUTO
งาน SMALL ที่ owner ชัดเจนใช้ FAST_PATH ได้เป็นค่าเริ่มต้นเพื่อลด spawn/token overhead
AUTO Mode ใช้ background runner เปิด sub-agent จาก trigger files
Codex AUTO runner ใช้ multi-agent spawn tool จาก Coordinator chat
ใน AUTO Mode runner เป็นเจ้าของ trigger status ส่วน agent เป็นเจ้าของ handoff/report
runner ต้องใช้ atomic claim และ heartbeat ก่อนเปิด sub-agent
runner spawn agent ครั้งแรกได้เองเมื่อ role+task ยังไม่มี registry/agent_id
runner ต้อง reuse/resume sub-agent เดิมก่อน spawn ใหม่เมื่อ role+task เดียวกันยังใช้ได้
runner ห้าม spawn replacement agent สำหรับ role+task ที่มี agent_id เดิมแล้ว ถ้าไม่มีคำสั่ง spawn_new:<agent> ที่ตรง role หรือ Coordinator/User decision
runner ต้อง poll expected handoff/report และปิด trigger ที่เสร็จแล้วโดยไม่รอ final chat signal อย่างเดียว
trigger ต้องระบุ dependency fields: depends_on, can_run_parallel, blocking_outputs, unblocks
shared file ต้องมี lock ก่อนแก้และ release ก่อน QA
visible Chrome QA ต้องประกาศ browser URL, API base, automated test DB, visible browser runtime DB, account/role, fixture, cleanup, และ evidence path
GitOps failure หลัง commit ต้องหยุดและส่ง blocker ห้าม reset/revert/amend เอง
```

## Agent Memory

ทุก agent มี memory ของตัวเองที่:

```text
ai-sub-agents/memory/<agent>/memory.md
```

ใช้ memory เพื่อลดการอ่านเอกสารซ้ำ เช่น common commands, known patterns, gotchas, test fixtures, และ checklist ที่ใช้ซ้ำได้

Memory rules:

```text
อ่าน memory ของตัวเองตอนเริ่ม chat ใหม่
อัปเดต memory หลังจบ task หรือเจอ pattern สำคัญ
เก็บเฉพาะ reusable facts ที่สั้นและตรวจสอบย้อนกลับได้
ห้ามเก็บ secret, token, password, private key, หรือข้อมูล sensitive
ห้ามใช้ memory override task, Coordinator decision, docs, หรือ source code ปัจจุบัน
ถ้า memory ขัดกับไฟล์จริง ให้เชื่อไฟล์จริงและแก้ memory
จำกัด memory.md ประมาณ 100-200 บรรทัด และ prune ของเก่า
```
