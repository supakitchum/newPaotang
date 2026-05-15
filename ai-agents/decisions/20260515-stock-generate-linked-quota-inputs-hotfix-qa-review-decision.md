# Decision: stock-generate-linked-quota-inputs-hotfix-qa Review

Date: 2026-05-15

Decision: ACCEPT QA PASS

## Scope Reviewed

Coordinator reviewed QA report:

```text
ai-agents/reports/20260515-stock-generate-linked-quota-inputs-hotfix-qa-report.md
```

QA validated the Stock Generate linked quota inputs and current-game selector hotfix at:

```text
1d360be58629d798ba4de3f4ada131b7e6c8cc18
```

BO implementation commit under test:

```text
15ddf0a7bdd073a2b94e633a8b99bad50f1e6e62
```

Covered scope:

- Stock Generate game defaults to the current game
- `ALL` is removed from the Stock Generate game selector
- empty/all-game generate payloads are prevented
- 2-tail, 3-tail, and 3-front quota inputs update dependent values while typing
- invalid 2-tail conflicts show inline validation before submit
- valid submit guard enables after valid quota and reason are present
- Stock summary widgets remain aligned with the selected game
- legacy range/count fields remain absent
- mandatory QA test database isolation
- runtime restore/login smoke after QA

## QA Result

Accepted as PASS.

Evidence from QA:

- BO build, lint, test, Nuxt build, and stock structural script passed in Docker
- destructive migration ran only with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`
- runtime database `newpaotang` was not wiped or destructively migrated
- `CentralStockTest` passed: 3 tests / 148 assertions
- authenticated browser QA opened `/admin/central/stock-generation`
- Game selector defaulted to current game: `งวดวันที่ 16 พ.ค. 2569 (16052569) (Current)`
- Generate modal current-game selector had exactly one option and no `ALL`
- `2-tail=20` updated `3-tail=2`, `3-front=2`, `total=2000`
- `3-tail=3` updated `2-tail=30`, `3-front=3`, `total=3000`
- `3-front=4` updated `2-tail=40`, `3-tail=4`, `total=4000`
- `2-tail=25` showed inline validation before submit and kept Confirm disabled
- valid UI state enabled Confirm after `3-tail=2` plus reason
- summary widgets rendered for the current game
- runtime restore/login smoke passed
- no QA defects reported

## Accepted Risks

- Browser QA intentionally did not click Confirm to avoid mutating runtime stock data. The accepted backend path was covered by isolated test DB feature tests.
- `/admin/central/stock` remains a general stock view with an `All` list filter; this hotfix acceptance applies to `/admin/central/stock-generation`.
- Existing git gc housekeeping warning remains outside this hotfix scope.

## Follow-up

No remediation task required from this QA result.

Next Agent: Coordinator

