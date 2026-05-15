# Decision: Stock Generate Linked Quota Inputs Hotfix

Date: 2026-05-15

Decision: OPEN HOTFIX THROUGH ORCHESTRATOR

## User Request

Hotfix the Stock Generate form so the related quota fields show their dependent values immediately.

Source request:

```text
ช่องกรอก 2 3 ท้าย 3 หน้าที่แปรผันกัน ให้ UI แสดงให้เห็นเลย
เช่น กรอก 2 ท้าย ช่อง 3 ท้ายกับ 3 หน้าก็แสดงขึ้นมาเลยว่าต้องกรอกเท่าไหร่
```

## Current Business Rule

Quota values are strictly related:

```text
back2_count_per_number = back3_count_per_number * 10
front3_count_per_number = back3_count_per_number
total_count = back3_count_per_number * 1000
```

Therefore:

```text
back3_count_per_number = back2_count_per_number / 10
front3_count_per_number = back2_count_per_number / 10
back2_count_per_number = front3_count_per_number * 10
back3_count_per_number = front3_count_per_number
```

The UI must help the operator see these linked values before submit instead of relying on backend validation errors.

## Product Direction

Back Office should make the dependency visible while typing:

- If the operator edits `2-tail per number`, show the required `3-tail per number` and `3-front per number` values immediately.
- If the operator edits `3-tail per number`, show/update required `2-tail per number` and `3-front per number`.
- If the operator edits `3-front per number`, show/update required `2-tail per number` and `3-tail per number`.
- If the existing UI has a `total_count` helper/input, keep it consistent with the same rule.
- Invalid derived values, such as `2-tail` not divisible by 10, must be shown inline before submit.
- Submit payload must still match backend strict validation.

Recommended UX:

```text
2-tail input      shows derived required 3-tail and 3-front
3-tail input      shows derived required 2-tail and 3-front
3-front input     shows derived required 2-tail and 3-tail
total_count hint  shows total tickets to be generated
```

The exact UI component can follow existing Back Office form patterns. This is an operational form, so keep it compact and direct.

## Scope

Expected Orchestrator split:

```text
BO Develop -> QA Tester -> Coordinator
```

Backend Develop is not expected unless Orchestrator or BO discovers that the current API contract cannot accept the corrected payload cleanly.

## BO Acceptance Criteria

```text
Stock Generate quota fields visually update their dependent values as the user types
editing any of the three quota inputs makes the required values for the other two obvious
invalid dependencies are visible inline before submit
submit remains blocked or clearly invalid when dependencies conflict
valid submit payload still uses back2_count_per_number, back3_count_per_number, and front3_count_per_number
existing total_count helper/input remains consistent if present
legacy start_number/count/range/number_digits fields do not return
Stock summary widgets from the previous task remain visible and unaffected
BO validation commands pass through Docker
```

## QA Acceptance Criteria

QA must verify real BO behavior, not only build/lint:

```text
open central Stock page in authenticated BO
type 2-tail value and confirm 3-tail/3-front required values display immediately
type 3-tail value and confirm 2-tail/3-front required values display immediately
type 3-front value and confirm 2-tail/3-tail required values display immediately
verify invalid 2-tail value that is not divisible by 10 shows inline validation before submit
verify valid submit payload remains accepted
verify previous stock summary widgets still render
verify no legacy range/count fields return
```

QA database isolation policy remains mandatory:

```text
destructive database commands must use APP_ENV=testing, DB_DATABASE=newpaotang_test, and --env=testing
runtime database newpaotang must not be wiped
runtime restore/login smoke is required before a clean PASS
```

## Out Of Scope

```text
changing quota algorithm
changing backend validation unless BO cannot meet the contract
changing stock summary endpoint behavior
changing import stock flow
destructive runtime database commands against newpaotang
```

## Next Agent

Orchestrator

