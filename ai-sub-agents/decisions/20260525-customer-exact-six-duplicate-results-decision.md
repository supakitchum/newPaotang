# Customer Exact Six Duplicate Results Decision

## Decision Type

```text
New work intake
```

## Task Key

```text
customer-exact-six-duplicate-results
```

## Date

```text
2026-05-25
```

## Execution Mode

```text
AUTO
```

Fallback:

```text
MANUAL if background runner is unavailable
```

## User Requirement

```text
เมื่อลูกค้าค้นหาเลข 6 หลักตรงๆ ให้แสดงเลข 6 หลักที่ซ้ำกันทุกใบ
```

## Coordinator Interpretation

เมื่อลูกค้าอยู่ใน customer buy/search flow และค้นหาด้วยเลขเต็ม 6 หลักแบบตรงตัว เช่น `123456` ระบบต้องแสดงผลลัพธ์ทุกใบหรือทุก copy ที่มีเลข `full_number = 123456` ไม่ใช่รวม, ซ่อน, หรือ dedupe เหลือใบเดียวตามเลขเดียวกัน

แต่ละใบที่ซ้ำเลขเดียวกันต้องยังมี identity ของตัวเองสำหรับการเลือกและจอง เช่น `id`, `token`, หรือ field ที่ adapter ใช้อยู่ในปัจจุบัน เพื่อให้ลูกค้าจองใบใดใบหนึ่งหรือหลายใบได้ถูกต้องตาม source of truth ฝั่ง server

## Priority

```text
P1 customer search correctness
```

เหตุผล: เป็นพฤติกรรมหลักของหน้าซื้อเลข ถ้าระบบซ่อนใบที่เลขซ้ำกัน ลูกค้าจะเห็นจำนวนซื้อได้ไม่ครบและอาจกระทบ reservation flow

## Scope

- Customer route/search flow ที่รับการค้นหาเลขเต็ม 6 หลักโดยตรง
- Adapter/composable mapping จาก input เลข 6 หลักไปยัง `GET /api/v1/public/stock/search?number=<six_digits>`
- Result normalization/rendering ใน `apps/customer` เพื่อไม่ dedupe/collapse ผลลัพธ์ที่มี `full_number` เดียวกัน
- Selection/reservation handoff ต้องยังอ้างอิง unique item id ของแต่ละใบ ไม่ใช่ใช้ `full_number` เป็น key หลักเพียงอย่างเดียว
- Pagination/cursor behavior ต้องยังทำงานเมื่อเลข 6 หลักมีหลายใบเกิน limit
- Empty/loading/error/maintenance state เดิมต้องคงไว้

## Out Of Scope

- เปลี่ยน route customer buy/search เดิม
- redesign หน้าซื้อหรือ checkout
- เปลี่ยน reservation, cart, checkout business logic
- เพิ่ม migration/schema/seed โดยไม่มี blocker และ Coordinator decision ใหม่
- อัปเดต local runtime DB จริง
- แก้ back-office stock manager เว้นแต่ Orchestrator พบว่าเป็น dependency ที่จำเป็นและต้องขอ scope เพิ่ม

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
docs/virtual-stock-realtime.md
```

Relevant contract notes:

- `GET /api/v1/public/stock/search` accepts `number` as full or partial 6-digit search value.
- Customer search must read tenant-local stock through Platform API and preserve existing UI flow.
- `LocalStockItem` includes `id`, `game_id`, `full_number`, `status`, and optional image/price fields.
- Virtual stock can have multiple available copies for the same full number; customer search uses combined virtual capacity.
- Availability and reservation source of truth remains server responses.

## Agent Assignment

Primary:

```text
Dev Customer
```

Conditional:

```text
Dev Backend
```

Condition for Dev Backend: Orchestrator should open backend work only if investigation shows the public stock search API does not return every visible duplicate/copy for an exact six-digit `number` query, or if the API response lacks stable unique item identifiers needed by the customer UI.

QA:

```text
QA Tester
```

QA is required because this affects browser-visible customer behavior.

## Milestones

1. Orchestrator investigates current customer search flow and decides exact dev-agent split.
2. Dev agent(s) implement only the smallest necessary change to preserve exact six-digit duplicate rows.
3. Dev agent(s) add or update focused automated tests for exact six-digit duplicate display/normalization.
4. Orchestrator verifies dev handoffs, dependency outputs, and lock release before QA.
5. QA validates on test env/test DB and visible Google Chrome.
6. Coordinator reviews QA report before any GitOps trigger.

## Acceptance Criteria

- When a customer searches exactly six numeric digits, the outgoing stock search uses the full number as an exact 6-digit value and does not replace it with only front3/back3/back2 matching behavior.
- If the API returns multiple search result items with the same `full_number`, the customer UI displays every returned item/copy.
- Duplicate-result rendering must not use `full_number` as the sole list key or dedupe key.
- Each displayed duplicate item must preserve its own unique reservation identifier for select/reserve actions.
- Existing partial searches such as 2-digit, 3-digit, browse/random, and store-filtered search continue to work.
- Empty result, loading, API error, and `maintenance_active` behavior do not regress.
- Automated tests cover exact six-digit duplicate search behavior at the adapter/composable/component level appropriate to the implementation.
- QA must prove browser testing is connected to test env/test DB before a clean PASS.
- QA must include visible Google Chrome evidence for the customer search flow.

## Test Expectations

Dev agents:

```text
Add/update focused automated tests for exact six-digit duplicate result preservation.
Run tests only in allowed test env/test DB context when backend/data is involved.
Do not run migration/seed/reset against local runtime DB newpaotang.
```

QA Tester:

```text
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for backend/data validation.
Open real visible Google Chrome for customer `/buy/search` or equivalent current search route.
Use test fixture data where the same 6-digit full_number has multiple visible copies.
Record browser URL, frontend service, API base URL, APP_ENV, DB_DATABASE, tenant/domain, account/role, test data fixture, and evidence path.
```

## DB Change Declaration

```text
DB update expected after Coordinator approval: No
Reason: Requirement should be satisfiable through customer search mapping/rendering or existing public stock search response behavior. If backend investigation finds API/data-contract work is required, Orchestrator must call it out in task breakdown and handoff.
```

## Risks / Watch Points

- Exact 6-digit search must not accidentally become partial contains search if existing frontend splits the value into digit fields.
- Duplicate result cards must not collapse because of list keys, grouping, computed maps, or store normalization keyed only by `full_number`.
- If virtual stock returns capacity rather than materialized rows, Dev Backend may be needed to expose every selectable copy or a stable virtual stock ref per copy.
- Reservation must continue to rely on server-confirmed item ids and not browser-only duplicate indexes.

## Coordinator Restrictions

```text
Coordinator did not write code.
Coordinator did not run build/test/migration/seed/reset.
Coordinator did not trigger dev-agent directly.
```

## Required Outputs

Orchestrator must create:

```text
ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-customer.md
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
```

If backend scope is necessary, Orchestrator may also create:

```text
ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-backend.md
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
```

QA output after dev completion:

```text
ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-qa-tester.md
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.md
ai-sub-agents/reports/20260525-customer-exact-six-duplicate-results-qa-report.md
```

## Next Agent

```text
Orchestrator
```

## Trigger

```text
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.md
```
