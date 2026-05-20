# 20260520 Coordinator New Chat Handoff

## Agent

Coordinator

## Purpose

ใช้ไฟล์นี้เป็น continuity note สำหรับเปิดแชท Coordinator ใหม่ของโปรเจค NewPaotang

## Worktree / HEAD

```text
canonical worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at handoff creation: a6acafbfc03aa836e47c1ec54895831e4e78fa73
origin/develop at handoff creation: a6acafbfc03aa836e47c1ec54895831e4e78fa73
status note: apps/platform-api/.phpunit.result.cache is modified locally from QA/PHPUnit and was intentionally not committed
```

## Current State

```text
Active Task: none
Latest completed product task: retire-physical-stock-flow
Latest Coordinator approval decision: ai-agents/decisions/20260520-retire-physical-stock-flow-qa-review-decision.md
Latest QA report: ai-agents/reports/20260520-retire-physical-stock-flow-qa-report.md
Latest pushed commit before this handoff: a6acafbfc03aa836e47c1ec54895831e4e78fa73
```

`retire-physical-stock-flow` is complete and QA PASS.

Confirmed by QA:

```text
physical generation modes and legacy fields are rejected
requested_count allocation create payload is rejected
virtual allocation writes partner_stock_allocations and stock_partner_distributions
virtual allocation does not bulk assign stock_items or partner_stock_allocation_items
customer search/reservation uses stock_partner_distributions and lazily materializes stock_items/local_stock_items
partner-sync/allocations returns virtual allocation metadata
Partner Quotas writes are retired with 410 retired_flow
BO active navigation no longer shows Partner Quotas
BO lint/test/build passed
runtime restore/login smoke passed
```

Known residual risk:

```text
Full platform test suite was not run; QA ran focused Docker filters required by the task.
```

## Coordinator Operating Rules

Default mode is Coordinator-only.

Normal work must follow:

```text
Coordinator -> Orchestrator -> Worker Agent -> QA Tester -> Coordinator
```

Coordinator must not implement code, run runtime operations, run migration/seed/reset/build/test commands, or open background/subagent work unless the user explicitly says `Hotfix` in the same turn.

For normal work, Coordinator writes the instruction into board/decision/task documentation and marks `Next Agent: Orchestrator`. The user sends that instruction to the Orchestrator chat.

Before dispatching new work:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

If there are completed docs/handoff changes, commit and push before opening the next work item.

## QA / DB Rules

Destructive DB commands are allowed only against the test DB:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Do not run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` against runtime DB `newpaotang` unless the user explicitly authorizes it in that same turn.

Runtime DB writes or cleanup require explicit user approval in the same turn, except non-destructive smoke/seed commands specified by Coordinator for login verification.

## Important Stock Decisions

Virtual stock is the active stock model.

Use:

```text
stock_supply_profiles
virtual_stock_supply_layers
stock_partner_distributions
virtual_stock_counters
stock_items/local_stock_items only for lazy materialization after customer reservation/sale/image work
```

Do not route new work to:

```text
physical generation
quota_random / quota / physical generation modes
Partner Quotas BO write workflow
requested_count allocation create payload
bulk physical partner_stock_allocation_items assignment
```

Base lottery source:

```text
apps/platform-api/storage/app/public/number.json
```

Do not revert virtual stock base numbers to generated `000000-999999` without a new Coordinator decision or explicit user instruction.

## Must-Read Files For New Coordinator Chat

Read these first:

```text
ai-agents/prompts/open-chat-coordinator.md
ai-agents/rules/global-rules.md
ai-agents/roles/coordinator.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
ai-agents/BOARD.md
docs/coordinator-agent-handoff.md
ai-agents/decisions/20260520-coordinator-role-rules-decision.md
ai-agents/decisions/20260520-retire-physical-stock-flow-qa-review-decision.md
docs/virtual-stock-realtime.md
```

## Local Dirty Note

At handoff creation, this file was dirty:

```text
apps/platform-api/.phpunit.result.cache
```

It is a PHPUnit cache artifact from QA. Do not stage it as product evidence. Do not revert it unless the user explicitly asks or Coordinator decides to clean runtime/test artifacts.

## Recommended First Response In New Chat

```text
ผมคือ Coordinator ของ NewPaotang อยู่ที่ worktree /Users/supakit/WorkSpace/www/newPaotang
สถานะล่าสุด: ไม่มี active task, retire-physical-stock-flow ปิดงานแล้วและ QA PASS
ผมจะทำงานแบบ Coordinator-only: เขียน board/decision/prompt ให้ Orchestrator เว้นแต่คุณระบุ Hotfix
พร้อมรับคำสั่งต่อไปครับ
```

## Next Agent

None
