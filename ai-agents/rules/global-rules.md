# Global Rules For All Agents

## Chain Of Command

```text
User -> Coordinator -> Orchestrator -> Worker Agent -> QA Tester -> Coordinator
```

- Coordinator เป็นผู้ตัดสินใจแผนรวม, scope, policy, และ approval gate
- Orchestrator แปลงคำสั่งของ Coordinator เป็น task prompt ให้ agent อื่น
- Backend Develop, BO Develop, Customer Develop และ QA Tester รับงานผ่าน Orchestrator prompt เท่านั้น
- Agent ทุกตัวห้ามข้ามขั้นตอนหรือทำงานนอกบทบาทจนกว่า Coordinator จะสั่งชัดเจน

## Coordinator Hotfix Direct Execution Rule

Coordinator ห้ามทำ implementation, operation, migration, DB reset, deploy/runtime command, หรือแก้ code เองในงานปกติ ต้องทำหน้าที่สรุป requirement, แยก scope, ส่ง Orchestrator, รอ QA และตัดสินใจ gate เท่านั้น

Coordinator ทำเกินหน้าที่และลงมือแก้/รันเองได้เฉพาะเมื่อคำสั่งผู้ใช้ใน turn นั้นระบุชัดว่า `Hotfix` เท่านั้น ถ้าไม่มีคำว่า `Hotfix` ให้ถือว่าเป็นงาน coordinator flow ปกติและห้าม direct execution

## Coordinator Board Dispatch Rule

Coordinator ต้องส่งงานผ่านบอร์ด/เอกสารเท่านั้นในงานปกติ โดยเขียนคำสั่งให้ผู้ใช้นำไปเปิดใน Orchestrator chat ห้ามเปิด background task, subagent, หรือ agent session แทนผู้ใช้เอง

สิ่งที่ Coordinator ทำได้ใน flow ปกติ:

```text
อ่าน source of truth
สรุป requirement และ decision
เขียน/อัปเดต ai-agents/BOARD.md
เขียน/อัปเดต ai-agents/decisions/*.md
เขียน task/handoff instruction ที่ Orchestrator ต้องรับช่วงต่อ
ตรวจ handoff และ QA report
```

สิ่งที่ Coordinator ห้ามทำถ้า user ไม่ได้ระบุ `Hotfix` ใน turn นั้น:

```text
แก้ implementation code
รัน migration/seed/reset/build/test/runtime operation
เปิด subagent/background task เอง
dispatch worker โดยข้าม Orchestrator
ส่งงานกลับ Coordinator โดยข้าม QA Tester
```

## Clarification Rule

Coordinator ต้องถามผู้ใช้หรือขอความเห็นเมื่อเจอข้อมูลไม่ชัดเจนในส่วนที่มีผลต่อ architecture, scope, security, tenant isolation, payment, wallet, reward, permission, หรือ customer flow

Coordinator ห้ามเดาเองในเรื่องที่:

```text
เปลี่ยน business flow
เปลี่ยน API contract ที่กระทบ frontend/backend หลายส่วน
เปลี่ยน permission/security model
เปลี่ยน tenant/domain behavior
เปลี่ยน payment/wallet/reward logic
เปลี่ยน customer UI flow เดิม
```

## Completion Report Rule

เมื่อ agent ทำงานเสร็จ ต้องรายงานทุกครั้ง:

```text
1. ทำอะไรไป
2. แก้ไฟล์อะไรบ้าง
3. ตรวจสอบอะไรแล้ว
4. ยังเหลือความเสี่ยงหรือคำถามอะไร
5. งานถัดไปควรเป็นของ Agent ตัวไหน
```

รายงานต้องเขียนลง `ai-agents/handoffs` หรือ `ai-agents/reports` ตามชนิดงาน

## Code Agent Commit Rule

Agent ที่แก้ implementation code ต้อง commit งานของตัวเองเมื่อทำงานเสร็จและ validation ตาม task ผ่านแล้ว เพื่อไม่ให้ worktree สะสมงานค้าง

ใช้กับ agent เหล่านี้:

```text
Backend Develop
BO Develop
Customer Develop
agent อื่นที่ Coordinator สั่งให้แก้ implementation code โดยตรง
```

กติกา:

```text
1. ก่อน commit ต้องตรวจ git status --short
2. stage เฉพาะไฟล์ใน ownership/scope ของ task รวมถึง tests, docs, task handoff ที่เกี่ยวข้อง
3. ห้าม stage ไฟล์ unrelated หรือไฟล์ของ agent อื่นโดยไม่แจ้ง Coordinator
4. commit message ต้องขึ้นต้นด้วย task key และสรุปชัดว่าทำอะไรไป
5. handoff ต้องระบุ commit hash หรือถ้า commit ไม่สำเร็จต้องระบุ blocker
6. ถ้า QA พบ defect ทีหลัง ให้แก้เป็น remediation task และ commit เพิ่มอีกหนึ่งครั้ง
7. ถ้า worktree มี unrelated dirty changes ให้ commit เฉพาะ scope ของตัวเองและบันทึก unrelated changes ไว้ใน handoff
```

Coordinator ยังต้องคุม Gate 5 ก่อนขึ้น milestone ใหม่ แต่ worker code commit เป็นกฎประจำ task เพื่อรักษา worktree ให้สะอาดระหว่างทาง

## No Cross Role Rule

```text
Backend Develop ห้ามแก้ UI ยกเว้น Coordinator สั่งชัดเจน
BO Develop ห้ามแก้ backend logic ยกเว้น Coordinator สั่งชัดเจน
Customer Develop ห้าม rewrite customer flow เดิม ยกเว้น Coordinator อนุมัติ
QA Tester ห้ามแก้ implementation ยกเว้น Coordinator สั่งให้ช่วยแก้ test fixture หรือ test code
Orchestrator ห้าม implement code ยกเว้น Coordinator สั่งชัดเจน
```

## Contract Rule

- API ต้องอ้างอิง `docs/openapi.yaml`
- Runtime/command ต้องอ้างอิง `docs/docker-runtime-policy.md`
- Permission ต้องอ้างอิง `docs/permissions.md`
- Customer flow ต้องอ้างอิง `docs/customer-api-integration-map.md`
- Back-office UI ต้องอ้างอิง `docs/admin-dashboard-template-guidelines.md`
- ถ้าเอกสารไม่ตรงกัน ให้หยุดและส่งคำถามให้ Coordinator

## Tenant And Security Rule

ทุกงานต้องรักษากฎเหล่านี้:

```text
tenant isolation is mandatory
backend authorization is source of truth
menu visibility is not authorization
customer must never write Central Stock directly
support impersonation must never expose real passwords
wallet/payment/reward writes require idempotency and audit where applicable
```

## Docker Runtime Rule

```text
ทุก application command ต้อง run ผ่าน Docker container เท่านั้น
ห้าม run PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration บน host machine
Orchestrator ต้องเขียน validation command เป็น docker compose exec หรือ docker compose run --rm เท่านั้น
Backend Develop ใช้ service platform-api
BO Develop ใช้ service back-office
Customer Develop ใช้ service customer
QA Tester ทดสอบผ่าน Docker service ที่เกี่ยวข้องเท่านั้น
```

## Canonical Worktree Rule

ทุก agent ต้องใช้ worktree หลักเดียวกันเป็น source of truth เว้นแต่ Coordinator สั่งแยก worktree เป็นลายลักษณ์อักษรใน task นั้นโดยตรง

Canonical worktree:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

ก่อนเริ่มอ่าน/แก้/ทดสอบงานทุกครั้ง agent ต้องตรวจ:

```sh
pwd
git rev-parse --show-toplevel
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

เงื่อนไขผ่าน:

```text
1. git top-level ต้องเป็น /Users/supakit/WorkSpace/www/newPaotang
2. branch ต้องตาม origin/develop ล่าสุด หรือเป็น branch ที่ Coordinator ระบุให้ใช้ใน task นั้น
3. ถ้าอยู่ .codex/worktrees/*, newPaotang-bo-*, newPaotang-qa-*, newPaotang-orch-* หรือ detached HEAD ให้ถือว่าเป็น worktree ผิดทันที เว้นแต่ task ระบุ path นั้นชัดเจน
4. ถ้า HEAD ไม่ตรงกับ origin/develop และไม่ได้รับอนุญาตเป็น branch เฉพาะงาน ให้หยุด ไม่แก้ไฟล์ และส่ง blocker กลับ Coordinator
5. ห้ามรัน Docker build/test/browser QA จาก worktree เก่าหรือ detached เพราะ container อาจ mount source ผิด
```

ถ้า agent พบว่าตัวเองอยู่ worktree ผิด ให้ทำตามนี้:

```text
1. หยุดแก้ไฟล์ทันที
2. ถ้ามีงานที่ยังไม่ได้ commit ให้รายงาน path, branch, git status, และรายการไฟล์ให้ Coordinator ก่อน ห้ามย้าย/ลบเอง
3. ถ้าไม่มีงานค้าง ให้ย้ายการทำงานไปที่ /Users/supakit/WorkSpace/www/newPaotang
4. ที่ canonical worktree ให้ run git fetch origin และ fast-forward ให้ตรง origin/develop ก่อนเริ่มงาน
5. handoff/report ต้องบันทึก worktree path และ HEAD ที่ใช้ทดสอบเสมอ
```

Coordinator/Orchestrator ต้องเขียน task prompt ทุกฉบับให้มี worktree start gate:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
```

ถ้า command ใด fail ต้องหยุดและส่งกลับ Coordinator ห้ามเดินงานต่อบนฐานที่ไม่ตรงกัน

ก่อนเริ่มงานใหม่หรือรับ handoff ทุกครั้ง agent ต้องบันทึก `worktree path`, `branch`, `HEAD`, และ `origin/develop` ใน handoff/report เพื่อยืนยันว่าอ่านงานจาก commit เดียวกันกับทีม

## QA Runtime Restore Rule

QA Tester ต้องใช้ฐานข้อมูลทดสอบแยกจากฐานข้อมูล runtime หลักเสมอ และต้องคืนสภาพ local Docker runtime ให้ login ได้ก่อนส่งรายงานทุกครั้ง โดยเฉพาะงานที่แตะ database, migration, seeder, PHPUnit/feature test, Docker volume, Nuxt `.nuxt`, `npm run build`, หรือ browser QA

ฐานข้อมูล runtime หลัก `newpaotang` ไม่ใช่ disposable test database ห้ามล้างด้วยคำสั่ง destructive ระหว่าง QA เว้นแต่ผู้ใช้สั่งเป็นลายลักษณ์อักษรใน turn นั้นโดยตรง

คำสั่ง destructive ต่อไปนี้ต้องใช้ได้เฉพาะ test database เท่านั้น:

```text
migrate:fresh
migrate:refresh
migrate:reset
db:wipe
คำสั่งอื่นที่ drop/truncate ตารางจำนวนมาก
```

QA Tester ห้ามส่ง `PASS` จนกว่าจะทำสิ่งนี้ครบและบันทึกผลไว้ใน QA report:

```text
1. PHPUnit/feature test และ destructive migration ต้องรันกับ `DB_DATABASE=newpaotang_test` และ `APP_ENV=testing`
2. ถ้า QA ต้องเตรียม DB ใหม่ ให้ใช้ `migrate:fresh --seed --env=testing` กับ test DB เท่านั้น
3. ห้ามใช้ `migrate:fresh --seed` กับ runtime DB หลัก `newpaotang`
4. ถ้า QA ใช้ browser/BO workflow ที่จะ mutate data ต้องใช้ QA/test DB runtime หรือขอ Coordinator decision ก่อน ห้ามล้าง DB หลักเพื่อ restore
5. หลัง test/build ต้องรัน platform smoke บน runtime หลัก และต้องเห็น seeded-logins: ok
6. ถ้า QA แตะ back-office dev/build/browser flow ต้อง restart หรือ recreate back-office service หลัง test/build
7. ต้องตรวจว่า /login เปิดได้ และ /admin/login ไม่พาไป redirect path เสีย
8. ถ้าข้อใดทำไม่ได้ ต้อง mark เป็น FAIL หรือ PASS WITH RISK พร้อมระบุ blocker ห้ามเขียนว่าไม่มี defect
```

คำสั่ง baseline สำหรับ QA ที่ต้องเตรียม test DB หรือรัน backend feature/PHPUnit:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

คำสั่ง baseline สำหรับ QA หลังจบทดสอบ local Docker เพื่อตรวจ runtime หลักว่ายัง login ได้:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
```

ข้อกำหนดผ่านขั้นต่ำ:

```text
platform:smoke ต้องแสดง app/database/cache/monitoring-defaults/seeded-logins เป็น ok
POST /api/v1/auth/admin/login ด้วย seeded central admin ต้องได้ 200
/login ต้องได้ 200
/admin/login ต้อง redirect ไป /login โดยไม่เก็บ redirect=/admin/login
```

ถ้า QA ใช้ clean worktree แยก แต่ใช้ Docker project/database เดียวกันกับ local runtime หลัก กฎนี้ยังบังคับใช้ เพราะผลข้างเคียงอยู่ที่ container/volume ไม่ใช่เฉพาะไฟล์ใน worktree

QA report ต้องบันทึกชื่อ database ที่ใช้สำหรับ destructive command ทุกครั้ง ถ้าไม่มีหลักฐานว่า destructive command ใช้ `newpaotang_test` ให้ Coordinator ถือว่า QA ยังไม่ผ่าน

## Git Boundary Rule

```text
เมื่อ task/milestone ล่าสุดผ่าน Coordinator approval แล้ว และสถานะพร้อมขึ้น M ใหม่:
1. หยุด dispatch งานใหม่ทันที
2. Coordinator ต้องตรวจ git status และสรุป scope ที่จะ commit
3. ต้อง stage/commit/push งานที่ผ่าน approval แล้วก่อนเริ่ม M ใหม่
4. ห้าม Orchestrator เปิด task ใหม่ของ M ถัดไปจนกว่า push สำเร็จ หรือผู้ใช้สั่งข้ามเป็นลายลักษณ์อักษร
```

## Coordinator Pre-Dispatch Sync Rule

Coordinator ต้องเคลียร์ git ก่อนเริ่มหรือส่งงานใหม่ทุกครั้ง เพื่อป้องกัน agent ตัวอื่นอ่านไฟล์เก่า หรืองานที่ทำแล้วหายจาก worktree

ก่อน dispatch งานให้ Orchestrator หรือ agent ใด ๆ Coordinator ต้องทำและบันทึกผล:

```text
1. git fetch origin
2. git status --short --branch
3. ถ้า local branch ตามหลัง origin ต้อง merge/fast-forward origin เข้ามาก่อน
4. ถ้ามีงานที่ผ่าน QA/Coordinator approval หรือ hotfix ที่ทำเสร็จแล้ว ต้อง stage/commit/push ก่อนเปิดงานใหม่
5. ถ้ายังมี dirty/untracked files ที่ยังไม่ควร commit ต้องระบุใน handoff ว่าเป็น unrelated/local artifact และห้ามให้ agent อื่นอิงไฟล์นั้น
6. หลัง push ต้องระบุ branch และ commit hash ล่าสุดใน handoff/BOARD
```

ห้าม Coordinator เปิด task ใหม่บน worktree ที่ยังมี implementation/docs changes ค้างโดยไม่ commit/push เว้นแต่ผู้ใช้สั่งข้ามเป็นลายลักษณ์อักษรใน turn นั้นโดยตรง

## Base Lottery Number Source Rule

เลขฐานของ virtual stock ต้องมาจากไฟล์ในโปรเจคนี้:

```text
apps/platform-api/storage/app/public/number.json
```

กฎสำหรับทุก agent:

```text
1. ห้ามกลับไปใช้ generator 000000-999999 เป็น source หลักโดยไม่มี Coordinator decision ใหม่
2. ห้ามลบหรือแทนที่ไฟล์ number.json นี้ เว้นแต่ user สั่งชัดเจนใน turn นั้น
3. ถ้าต้อง seed base_lottery_numbers ให้ใช้คำสั่ง stock:base-lottery:seed ผ่าน Docker เท่านั้น
4. ถ้าจะ seed runtime DB newpaotang ต้องมี user approval ชัดเจนใน turn นั้น
5. QA/destructive setup ต้อง seed เฉพาะ newpaotang_test ตาม QA Runtime Restore Rule
```
