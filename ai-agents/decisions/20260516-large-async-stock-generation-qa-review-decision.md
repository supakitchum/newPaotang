# Decision: large-async-stock-generation-qa Review

Date: 2026-05-16

Decision: ACCEPT QA PASS WITH RISK

## Scope Reviewed

Coordinator reviewed QA report:

```text
ai-agents/reports/20260516-large-async-stock-generation-qa-report.md
```

QA validated the large async stock generation work at:

```text
fd04201df63b93001a19d689ad718538be933e6e
```

Implementation commits under test:

```text
Backend: 748f4d1d53e4daf03246dd43bfb4cf53c069ce09
BO: a038d5885dd1f070c46c32455e80cfb3587b8e59
```

Covered scope:

- 1,000-row synchronous generation path
- 12,000-row async generation with queued batch and chunk jobs
- duplicate `full_number` preservation
- no `insertOrIgnore` in stock generation service/jobs
- completed chunk retry skip
- failed chunk rollback
- idempotency replay and conflict
- image dispatch separation after stock batch completion
- generation batch list/detail progress APIs
- BO large total validation removal and progress polling structural wiring
- OpenAPI contract updates
- mandatory QA test database isolation
- runtime restore/login smoke

## QA Result

Accepted as PASS WITH RISK.

Evidence from QA:

- `CentralStockTest` passed: 5 tests / 210 assertions
- `LotteryImage` regression passed: 16 tests / 479 assertions
- 12,000-row async test completed through chunk processing
- duplicate `full_number` was asserted after async generation
- source scan found no `insertOrIgnore` in generation service/jobs
- normal `StockItem::query()->insert($chunk)` evidence was captured
- BO lint, test, build, and structural async progress checks passed
- OpenAPI YAML parse and async stock contract checks passed
- destructive migration ran only with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`
- runtime database `newpaotang` was not wiped or destructively migrated
- runtime restore/login smoke passed
- no confirmed defects reported

## Accepted Risk

Authenticated BO browser UAT for a live large submit/progress polling workflow was not completed because available UI automation was blocked:

```text
Codex in-app browser: Browser is not available: iab
Computer Use: macOS Accessibility/Screen Recording permission remained pending
BO container: no Playwright/Puppeteer/jsdom fallback package
```

Coordinator accepts this risk because backend behavior was validated with isolated feature tests, BO behavior was structurally validated through Docker checks, and protected route curl smoke confirmed the Stock Generation route resolves through auth guard without SSR/server crash.

## Follow-up

No Backend/BO remediation is required from this QA result.

Recommended release-confidence follow-up:

```text
Run a small authenticated BO UAT pass for large submit/progress polling once browser automation or Computer Use permission is available.
```

Next Agent: Coordinator

