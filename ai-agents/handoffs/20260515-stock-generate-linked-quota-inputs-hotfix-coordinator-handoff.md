# Stock Generate Linked Quota Inputs Hotfix Coordinator Handoff

## Agent

Coordinator

## Task

Open hotfix work for linked quota inputs and current-game selection on the Back Office Stock Generate form.

## Source Request

User requested:

```text
ช่องกรอก 2 3 ท้าย 3 หน้าที่แปรผันกัน ให้ UI แสดงให้เห็นเลย
เช่น กรอก 2 ท้าย ช่อง 3 ท้ายกับ 3 หน้าก็แสดงขึ้นมาเลยว่าต้องกรอกเท่าไหร่
Stock Gen Game ให้เลือก default เป็นงวดปัจจุบัน
เอาตัวเลือก ALL ออก
```

## Coordinator Decision

Decision file:

```text
ai-agents/decisions/20260515-stock-generate-linked-quota-inputs-hotfix-decision.md
```

Coordinator interprets this as a BO hotfix to:

```text
make quota field dependencies visible while typing
default Stock Gen Game to the current draw/current game
remove ALL from the Stock Generate game selector
prevent all-game/empty-game generate payloads
```

## Required Business Rule

```text
back2_count_per_number = back3_count_per_number * 10
front3_count_per_number = back3_count_per_number
total_count = back3_count_per_number * 1000
```

Examples:

```text
back2 = 10  => back3 = 1,  front3 = 1,  total = 1000
back2 = 30  => back3 = 3,  front3 = 3,  total = 3000
back3 = 2   => back2 = 20, front3 = 2,  total = 2000
front3 = 4  => back2 = 40, back3 = 4,  total = 4000
```

If `back2` is not divisible by 10, the UI must show an inline validation/conflict before submit.

## Game Selection Requirement

Stock Generate must not default to or offer `ALL`.

BO must:

```text
default Game to the current draw/current game
remove ALL from the Stock Generate game selector
keep summary widgets aligned with the selected current game
block or clearly invalidate generate if no concrete current game is selected
show a clear empty/error state if there is no current draw/current game
```

If the existing API/list data does not expose a reliable current draw/current game marker, Orchestrator should add Backend Develop before QA instead of forcing a BO-only guess.

## Scope For Orchestrator

Create task prompts for:

```text
BO Develop
QA Tester
```

Recommended order:

```text
BO Develop -> QA Tester -> Coordinator
```

Backend Develop is not expected unless BO finds that the current backend contract prevents a valid payload after UI correction.

## Important Rules

- Orchestrator must not implement code.
- Coordinator has not changed app implementation.
- BO must use Docker-only validation commands.
- QA must run real BO workflow checks, not only lint/build.
- QA must follow database isolation:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

- QA must not wipe runtime DB `newpaotang`.
- QA must perform runtime restore/login smoke before reporting a clean PASS.

## Acceptance Summary

```text
quota fields show dependent values while typing
editing 2-tail updates required 3-tail and 3-front display
editing 3-tail updates required 2-tail and 3-front display
editing 3-front updates required 2-tail and 3-tail display
invalid conflicts show inline before submit
Stock Gen Game defaults to current draw/current game
ALL option is removed from Stock Generate game selector
generate cannot submit all-game/empty-game selection
valid submit payload remains accepted
previous stock summary widgets remain unaffected
legacy range/count fields do not return
```

## Next Agent

Orchestrator
