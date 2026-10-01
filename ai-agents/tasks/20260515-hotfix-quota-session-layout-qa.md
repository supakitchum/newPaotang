# hotfix-quota-session-layout-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the 2026-05-15 Coordinator hotfix/contract handoff:

```text
docs/coordinator-agent-handoff.md
```

The latest pushed work changes central stock generation to quota-based 6-digit random pairing and includes related hotfixes for admin session restore, lottery image layout defaults, `logo_num_set`, BO lottery image page layout, and QA runtime restore/login smoke expectations.

## Objective

Run a focused QA pass over the latest `origin/develop` hotfix set and report whether the new stock generation quota contract, admin session behavior, lottery image layout behavior, BO wiring, OpenAPI/docs, and runtime restore/login smoke requirements are valid.

## Start Gate

Before testing:

```text
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

QA must test the current `origin/develop` state containing at least these commits:

```text
d7ec7d5b4791190ebff660a3bc2391a7d6f0039f feat: support total stock count generation
3fd6168 feat: add quota-based stock generation
7a4725a docs: add coordinator handoff for hotfixes
bf56bfd hotfix: add lottery logo num set layout
b9880dc hotfix: harden admin session restore
```

If local `HEAD` is not aligned with `origin/develop`, use a clean QA worktree at `origin/develop` and record the path/hash in the report.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/coordinator-agent-handoff.md
docs/openapi.yaml
docs/back-office-crud-coverage.md
docs/lottery-image-generation.md
docs/permissions.md
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/LotteryImageTest.php
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
apps/platform-api/tests/Feature/AdminAuthTest.php
apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminLotteryImageOperations.vue
```

## Scope

Validate the following.

### Stock Generate Quota Contract

```text
POST /admin/central/stock/generate no longer accepts start_number, count, requested_count, number_digits, or range fields
payload can use total_count alone
payload can use manual quota fields: back2_count_per_number, back3_count_per_number, front3_count_per_number
total_count derives back3_count_per_number = total_count / 1000
total_count derives front3_count_per_number = back3_count_per_number
total_count derives back2_count_per_number = back3_count_per_number * 10
manual validation enforces back2_count_per_number = back3_count_per_number * 10
manual validation enforces front3_count_per_number = back3_count_per_number
generated stock rows = 1000 * back3_count_per_number
back3_count_per_number stays inside the synchronous 10,000-row cap
generation uses 6-digit numbers from front3 + back3
each round covers every front3 once, every back3 once, and every back2 ten times
duplicate 6-digit values remain allowed across separate batches/rounds where current stock model allows them
```

### BO Generate Stock Form

```text
BO Generate Stock form exposes total_count and optional manual quota fields
BO Generate Stock form no longer shows start/count/range/number_digits fields for central stock generation
BO sends the quota contract payload documented in OpenAPI
docs/back-office-crud-coverage.md describes quota-based generate fields
```

### Admin Session Hotfix

```text
admin access tokens last 8 hours / expires_in=28800
second admin login revokes other active sessions for the same admin user
revoked old sessions caused by another login return admin_session_replaced
BO handles admin_session_replaced by storing the notice and redirecting to /login
BO admin layout does not leave users stuck on Restoring admin session when session verification fails
```

### Lottery Image Layout Hotfix

```text
LotteryImageGenerator default layout uses the adopted project runtime DB layout
migration 2026_05_15_000004_adopt_current_lottery_image_layout_defaults.php applies the adopted layout
reset/default migration remains aligned to the same layout baseline
logo_num_set layout slot exists
logo_num_set uses the same partner asset file as logo_qr
logo_num_set has independent x/y/width/height layout values
logo_num_set renders only for partner-branded images
central base images do not render logo_qr, logo_num_set, right_sidebar, or logo_bottom
BO layout editor labels logo_num_set as Logo Num Set
no separate upload field exists for logo_num_set
docs/OpenAPI/resource README mention logo_num_set reuses logo_qr
```

### BO Lottery Image Page Layout

```text
AdminLotteryImageOperations places Image Zip Import as a full-width panel before Background Asset Sets
Background Asset Sets remains full-width below import
pagination, selection, sorting, and bulk status actions remain present
```

### Runtime Restore / Login Smoke Rule

```text
QA report includes Runtime Restore / Login Smoke before Recommendation
after DB/test/build/browser work, QA reseeds or restores local Docker runtime
platform:smoke reports seeded-logins: ok
seeded central admin login API returns 200
back-office is restarted/recreated after BO build/browser QA when applicable
/login returns 200
/admin/login redirects to /login without preserving redirect=/admin/login
```

## Out Of Scope

```text
implementing fixes
changing the quota algorithm
changing admin session policy
changing lottery image layout values
adding new BO features beyond the pushed hotfix set
production S3/R2/CDN rollout
authenticated production UAT without supplied credentials/session
```

## File Ownership

Can edit:

```text
ai-agents/reports/20260515-hotfix-quota-session-layout-qa-report.md
ai-agents/reports/artifacts/20260515-hotfix-quota-session-layout-qa/**
tests/** only if a QA-owned fixture/helper is explicitly needed
apps/*/tests/** only if adding a QA-owned regression test is necessary and Coordinator permits it
```

Must not edit:

```text
apps/platform-api/app/**
apps/back-office/**
apps/customer/**
docs/openapi.yaml
docs/coordinator-agent-handoff.md
ai-agents/decisions/**
real credential files or local environment secrets
```

## Shared Workspace Guardrail

The shared worktree may contain unrelated dirty/staged/untracked files from other agents.

Do not clean, revert, overwrite, unstage, stage, or commit unrelated dirty files. Prefer a clean QA worktree if the shared worktree is not clean.

Do not touch this local credential-bearing artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Steps

1. Confirm the latest hotfix commits under test and record `HEAD`, `origin/develop`, and worktree path.
2. Read the Coordinator handoff and all source-of-truth files.
3. Run focused backend tests for stock quota generation, lottery image generation/layout, lottery image operations, admin auth, and admin security session behavior.
4. Run BO lint/build and any available structural checks that cover the operations catalog and lottery image operations page.
5. Parse OpenAPI and verify the stock generate request schema no longer documents removed fields.
6. Inspect or smoke the BO Generate Stock form contract and lottery image page layout.
7. Validate admin duplicate-login/session-replaced behavior through tests and, if practical, local API smoke.
8. Validate runtime restore/login smoke exactly as required by the latest QA rule.
9. Run artifact/credential scan for newly created QA artifacts.
10. Write the QA report and send the result to Coordinator.

## Acceptance Criteria

```text
Docker-only backend tests pass for CentralStockTest, LotteryImageTest, LotteryImageOperationsTest, AdminAuthTest, and M10AdminSecurityLinePolicyClosureTest
quota contract rejects removed fields and invalid quota ratios
quota contract accepts total_count and valid manual quota payloads
generated stock row count and front3/back3/back2 distribution match the Coordinator contract
BO Generate Stock form and OpenAPI reflect the quota contract
admin_session_replaced behavior is covered and BO handles it without a stuck restore state
logo_num_set layout behavior is covered and no separate logo_num_set upload exists
central base images remain unbranded by partner overlays
BO lottery image page ordering/layout adjustment is verified
OpenAPI parses
credential/artifact scan passes
Runtime Restore / Login Smoke section is present and passing
QA report clearly states PASS, FAIL, or PASS WITH RISK with defects and next agent
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt/Vite on the host machine.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm platform-api php artisan test --filter=CentralStockTest
docker compose -p newpaotang run --rm platform-api php artisan test --filter=LotteryImageTest
docker compose -p newpaotang run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose -p newpaotang run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose -p newpaotang run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run build
```

Use repo-available Docker-compatible OpenAPI parsing and BO structural checks if present. Record exact commands.

Mandatory runtime restore/login smoke before final report:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
```

If a command cannot be run, record the blocker and do not report a clean PASS.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260515-hotfix-quota-session-layout-qa-report.md
```

Must include:

```text
result: PASS, FAIL, or PASS WITH RISK
worktree path
current HEAD and origin/develop
hotfix commits under test
files/artifacts created
validation commands and results
stock quota contract evidence
BO Generate Stock evidence
admin session replacement evidence
lottery image layout/logo_num_set evidence
BO lottery image page layout evidence
OpenAPI parse/result
credential/artifact scan result
Runtime Restore / Login Smoke
defects with owner recommendation
unrelated dirty files left untouched
next agent
```

## Next Agent

QA Tester
