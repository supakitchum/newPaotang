# Global Rules For AI Sub-Agents

## Chain Of Command

```text
User -> Coordinator -> Orchestrator -> Dev Agents -> Orchestrator -> QA Tester -> Coordinator -> GitOps
```

- Coordinator เป็นผู้ตัดสินใจ scope, milestone, priority, policy, และ approval
- Orchestrator แปลงคำสั่งของ Coordinator เป็น task prompt ให้ sub-agent
- Dev Backend, Dev BO Central, Dev BO Partner, และ Dev Customer รับงานผ่าน Orchestrator task เท่านั้น
- QA Tester รับงานจาก Orchestrator หลัง handoff ของ dev-agent ครบแล้ว
- GitOps รับงานจาก Coordinator หลัง QA ผ่านและ Coordinator approve แล้วเท่านั้น
- ทุก agent ต้องมี trigger file ก่อนเริ่มงาน
- Default execution mode is AUTO: background runner opens sub-agent work from trigger files

## Markdown Communication Rule

ทุก agent ต้องสื่อสารงานผ่านไฟล์ Markdown ใน `ai-sub-agents/**`

```text
chat-only completion is not accepted
handoff/report/decision must exist before moving to the next agent
Next Agent must be explicit in every handoff/report
```

## Trigger Rule

งานทุกชิ้นต้องมี trigger file ก่อน agent เริ่มงาน

```text
ai-sub-agents/triggers/YYYYMMDD-<task-key>-<agent>-trigger.md
```

Trigger status:

```text
PENDING
RUNNING
DONE
BLOCKED
CANCELLED
```

Trigger permissions:

```text
Coordinator -> Orchestrator only
Orchestrator -> Dev Backend / Dev BO Central / Dev BO Partner / Dev Customer / QA Tester
Coordinator -> GitOps only after QA PASS is accepted
```

Agent ต้อง:

```text
AUTO Mode: runner marks trigger RUNNING/DONE/BLOCKED
AUTO Mode: agent writes handoff/report and requested final status
MANUAL Mode: target agent/operator may mark trigger RUNNING/DONE/BLOCKED
ignore CANCELLED triggers
```

เขียน task โดยไม่มี trigger ยังไม่ถือว่าเปิด sub-agent แล้ว

## Execution Mode Rule

Default:

```text
Execution Mode: AUTO
Fallback Mode: MANUAL if background runner is unavailable
```

AUTO Mode:

```text
ผู้ใช้คุยกับ Coordinator chat เดียว
Coordinator/Orchestrator/GitOps gates create trigger files
background runner opens sub-agent work from PENDING triggers
runner owns trigger status
runner must atomically claim trigger before start
runner must write heartbeat while trigger is RUNNING
runner must enforce depends_on and blocking_outputs before start
runner must not start work without trigger
runner must not start CANCELLED triggers
runner is not allowed to decide scope, QA result, approval, git policy, or DB policy
```

Manual Mode:

```text
ใช้เฉพาะเมื่อ background runner ไม่พร้อมหรือ Coordinator/User ระบุชัด
ยังต้องสร้าง trigger/task/handoff/report ตาม protocol เดิม
ห้ามข้าม Orchestrator, QA, หรือ GitOps gate
```

## Agent Memory Rule

ทุก agent ต้องมี memory ของตัวเอง:

```text
ai-sub-agents/memory/<agent>/memory.md
```

Memory มีไว้เป็น short reusable cache เพื่อประหยัด context และลดการอ่านซ้ำ ไม่ใช่ source of truth

Agent ต้องทำตามนี้:

```text
อ่าน memory ของตัวเองตอนเริ่ม chat ใหม่
ใช้ memory เป็น hint เพื่อหา context เร็วขึ้น
ตรวจไฟล์จริง/source of truth ก่อนตัดสินใจหรือแก้ implementation
อัปเดต memory หลังจบ task เมื่อเจอ reusable pattern, command, gotcha, fixture, หรือ checklist
บันทึกใน handoff/report ว่า memory ถูกอัปเดตหรือไม่
```

Memory ห้ามทำสิ่งนี้:

```text
ห้าม override Coordinator decision, Orchestrator task, docs, tests, หรือ source code ปัจจุบัน
ห้ามเก็บ secret, token, password, private key, customer PII, หรือ production credential
ห้ามยาวจนกลายเป็น context ก้อนใหม่; ให้ prune ให้อยู่ประมาณ 100-200 บรรทัดต่อ agent
```

ถ้า memory ขัดกับไฟล์จริง ให้เชื่อไฟล์จริงและอัปเดต memory ให้ถูกต้อง

Memory maintenance must happen when:

```text
memory.md exceeds about 200 lines
memory is stale or conflicts with current source of truth
QA/Coordinator flags memory as misleading
agent reaches about 10 completed tasks since last memory cleanup
```

## Coordinator No-Code Rule

Coordinator เป็น planning และ approval role เท่านั้น

Coordinator ทำได้:

```text
อ่าน requirement
อ่าน source of truth
วาง scope/milestone/priority
เขียน decision/approval/remediation instruction
ตัดสินใจจาก QA report
ถาม user เมื่อข้อมูลไม่ชัด
```

Coordinator ห้ามทำ:

```text
เขียนหรือแก้ implementation code
เขียน migration
รัน migration/seed/reset บน DB
ทำ commit/push
แก้ automated test แทน dev-agent
ข้าม Orchestrator หรือ QA gate
```

## Test Env First Rule

ทุกการทดสอบต้องทำบน test env/test DB ก่อนเสมอ

```text
required test DB example: newpaotang_test
runtime DB example: newpaotang
```

คำสั่ง destructive ต่อไปนี้ใช้ได้เฉพาะ test env/test DB เท่านั้น:

```text
migrate:fresh
migrate:refresh
migrate:reset
db:wipe
คำสั่งอื่นที่ drop/truncate ตารางจำนวนมาก
```

ตัวอย่างรูปแบบคำสั่งที่ยอมรับสำหรับ destructive test command:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan migrate:fresh --seed --env=testing --no-interaction
```

ห้ามรัน destructive DB command กับ local runtime DB จริง เช่น `newpaotang`

## QA Browser Env Rule

Visible Chrome QA must declare and prove the browser is connected to the intended test environment.

Required fields:

```text
browser URL
frontend service
API base URL
APP_ENV
DB_DATABASE
tenant/domain
account/role
test data fixture
evidence path
```

If QA cannot prove the browser flow uses test env/test DB, QA must report `BLOCKED` or `PASS WITH RISK`; never clean PASS.

## Local Runtime DB Update Rule

ถ้างานมี migration หรือเปลี่ยน schema/data contract:

```text
1. Dev/QA ต้อง validate บน test env/test DB ก่อน
2. QA ต้องสรุป PASS ก่อน
3. Coordinator ต้อง approve ก่อน
4. GitOps เท่านั้นที่อัปเดต local runtime DB จริง
```

GitOps อัปเดต local runtime DB ด้วยคำสั่ง non-destructive เท่านั้น เช่น:

```sh
docker compose -p newpaotang exec -T platform-api php artisan migrate --force
```

หลัง migrate local runtime DB แล้ว GitOps ต้องรัน smoke check และบันทึกผลลง GitOps report

ถ้า migrate หรือ smoke บน local runtime DB ไม่ผ่าน ห้ามสรุปงานว่า complete และต้องส่ง blocker กลับ Coordinator

## Visible Google Chrome QA Rule

QA browser acceptance ต้องเปิด Google Chrome จริงบนเครื่องผู้ใช้แบบ visible

QA report ต้องระบุ:

```text
Chrome app was visible to the user
URL/page tested
account/role used
test data or tenant used
screenshot/evidence path when available
PASS/FAIL result per scenario
```

ถ้า Google Chrome เปิดไม่ได้หรือผู้ใช้มองไม่เห็น browser QA ให้ QA Tester สรุปเป็น blocker ห้าม mark clean PASS

## Automated Test Rule

Dev agents ต้องเพิ่มหรืออัปเดต automated test ให้เหมาะกับ feature ที่แก้

```text
dev-backend: feature/unit tests under apps/platform-api/tests when applicable
dev-bo-central: BO check/lint/build/component/script tests when applicable
dev-bo-partner: BO check/lint/build/component/script tests when applicable
dev-customer: customer check/lint/build/component/script tests when applicable
```

ถ้าไม่สามารถเพิ่ม automated test ได้ ต้องอธิบายเหตุผลใน handoff และให้ QA Tester ตรวจความเสี่ยงนั้น

## Docker Runtime Rule

Application commands ต้องรันผ่าน Docker เท่านั้น

```text
ห้ามรัน PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration บน host machine
Backend service: platform-api
Back-office service: back-office
Customer service: customer
```

## Worktree Start Gate Rule

ทุก agent ต้องผ่าน start gate ก่อนเริ่มงาน:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git status --short
git rev-parse HEAD
git rev-parse origin/develop
```

ถ้า command fail ให้หยุดทันทีและส่ง blocker กลับ Coordinator

Dirty worktree policy:

```text
files outside task scope: record and do not touch
files inside task scope but not from current task/agent: stop and send blocker
unknown ownership: stop and ask Orchestrator/Coordinator
```

## Dependency Graph Rule

Every task/trigger must include:

```text
depends_on
can_run_parallel
blocking_outputs
unblocks
```

Runner must not start a trigger until every dependency is DONE and every blocking output exists.

Frontend work that depends on new backend API/data contract must depend on backend handoff and contract evidence.

## No Cross-Role Rule

```text
Dev Backend ห้ามแก้ apps/back-office หรือ apps/customer เว้นแต่ Coordinator approve ชัดเจน
Dev BO Central ห้ามแก้ backend/customer และห้ามแก้ partner-only flow
Dev BO Partner ห้ามแก้ backend/customer และห้ามแก้ central-only flow
Dev Customer ห้ามแก้ backend/back-office
QA Tester ห้ามแก้ implementation code เว้นแต่ Coordinator มอบหมายเป็น remediation task
GitOps ห้ามแก้ implementation code
```

## Shared File Lock Rule

Shared files ต้องมี lock ก่อนแก้

```text
ai-sub-agents/locks/YYYYMMDD-<task-key>-<agent>-lock.md
```

Lock required for:

```text
shared apps/back-office components/composables/utils/layouts/plugins
files used by both central and partner/tenant flows
any file Orchestrator marks as shared risk
```

Orchestrator ต้อง approve lock และห้ามส่ง QA จนกว่า lock จะ RELEASED

Dev BO Central และ Dev BO Partner ห้ามแก้ shared file เดียวกันพร้อมกัน

## GitOps Failure Rule

ถ้า GitOps fail หลังสร้าง local commit แล้ว:

```text
ห้าม reset/revert/amend เอง
ห้าม push
เขียน blocker report พร้อม commit hash
ระบุ command ที่ fail และผลกระทบ
ส่งกลับ Coordinator
```

Local commit after failure is evidence, not completion.

## Security And Tenant Rule

ทุกงานต้องรักษากฎเหล่านี้:

```text
tenant isolation is mandatory
backend authorization is source of truth
menu visibility is not authorization
customer must never write Central Stock directly
wallet/payment/reward writes require idempotency and audit where applicable
```

## Canonical Worktree Rule

Canonical worktree:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

ก่อนเริ่มงาน agent ต้องบันทึก:

```sh
pwd
git rev-parse --show-toplevel
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

ถ้าไม่อยู่ canonical worktree หรือพบ base ผิดจาก task instruction ให้หยุดและส่ง blocker กลับ Coordinator
