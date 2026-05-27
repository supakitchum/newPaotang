# Customer Waiting Result Live Reward Dev Customer Task

## Owner Agent

```text
Dev Customer
```

## Source Decision

```text
ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
```

## Execution Mode

```text
AUTO
Fallback: MANUAL if background runner is unavailable
```

## Task Classification

```text
Task Size: STANDARD
Flow Mode: STANDARD
Primary Owner: Dev Customer
Conditional Agents: Dev Backend only with evidence and Coordinator approval
Fast Path Eligibility: No
Reason Orchestrator is used/skipped: Orchestrator is used because pre-existing dirty customer files are already present in and near the waiting-result scope, and no YouTube/live URL backend or site-config contract is established.
```

## Objective

Update the customer waiting-result page so it shows the current game name, includes an abbreviated reward result card using existing public result APIs/components, and includes a safe YouTube live/embed area without backend or site-config expansion.

## Scope

- `apps/customer/pages/waiting-result.vue` is the primary implementation file.
- Use existing customer app init state for the current game name. `useAppInit()` already exposes `currentGame` and `currentDrawDate`; prefer `currentGame.value?.name` for the visible metadata and keep a safe fallback that never renders `undefined`, `null`, or an empty broken label.
- Reuse `ResultSummaryCard` and the existing `platformApi.rewardLegacy()` public results adapter. Do not hardcode reward numbers.
- Add a YouTube live/embed section with a sanitized YouTube embed URL.
- If no YouTube URL is configured locally, show a non-breaking empty/waiting state instead of a broken iframe.
- Keep `/waiting-result` and alias `/wait-result`.
- Preserve existing sale-closed/waiting-result redirect behavior.

## Out Of Scope

- Backend, OpenAPI, database, migration, seed, payment, wallet, checkout, ticket ownership, reservation, reward payout, and runtime DB changes.
- Site-config contract expansion or tenant-managed live URL contract changes without concrete evidence and Coordinator approval.
- Editing `apps/platform-api/**` or `apps/back-office/**`.
- Redesigning unrelated customer pages.
- Touching unrelated dirty customer search files unless a direct compile/test dependency proves it is necessary.

## Source Of Truth

```text
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/sub-agent-reuse.md
ai-sub-agents/workflow/runner-polling.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/file-ownership.md
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/roles/dev-customer.md
docs/frontend-routes.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/openapi.yaml
apps/customer/pages/waiting-result.vue
apps/customer/components/ResultSummaryCard.vue
apps/customer/composables/useAppInit.ts
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useSiteConfig.ts
apps/customer/package.json
```

## Agent Memory

```text
Read ai-sub-agents/memory/dev-customer/memory.md before starting.
Use memory as a hint only; source of truth remains this task, the Coordinator decision, docs, tests, and current code.
Update memory after completion only if reusable customer route, result-card, or YouTube embed validation knowledge was learned.
```

## Trigger

```text
Trigger file: ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md
AUTO Mode: runner marks trigger RUNNING/DONE/BLOCKED.
Agent writes requested trigger final status in handoff/report.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
- Orchestrator dirty-file classification in ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
unblocks:
- Orchestrator completion check after ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md exists and the Dev Customer trigger is DONE
```

## Conditional Agent Expansion

```text
May open additional agents: No from Dev Customer directly
Required evidence before expansion: backend failing evidence, API contract mismatch, public results response defect, or proof that a tenant-managed live URL contract is required
Coordinator approval required before expansion: Yes
Backend expansion allowed only when: concrete API/contract evidence exists and Coordinator approves a new scope-expansion decision
```

If result summary data is absent, render an empty/waiting state. Do not open Dev Backend just because `/public/results/latest` returns no published result.

## Worktree Start Gate

```text
Read ai-sub-agents/workflow/worktree-start-gate.md.
Run the required commands before editing/testing.
Record dirty files before and after work.
Stop and send a BLOCKED handoff if start gate fails, if the trigger is CANCELLED, or if new unknown dirty files appear in the exact files you need to edit.
```

Known dirty-file context from Orchestrator:

```text
Allowed in-scope dirty customer context to preserve/build on:
- apps/customer/pages/waiting-result.vue (untracked, primary page)
- apps/customer/app.vue (sale closure guard install)
- apps/customer/composables/useAppInit.ts (waiting-result redirect/current game state)
- apps/customer/composables/usePlatformApi.ts (app init force refresh; rewardLegacy already exists)
- apps/customer/composables/useSaleClosureGuard.ts (untracked sale closure guard)
- apps/customer/utils/customerAuthRoutes.ts (waiting-result public route)
- apps/customer/scripts/check-tenant-domain-integration.mjs (already reads waiting-result page)

Dirty customer files to treat as unrelated unless directly required by validation:
- apps/customer/pages/buy/search.vue
- apps/customer/scripts/check-exact-six-search-identity.mjs

Dirty non-customer files are outside this task and must not be touched.
```

## Ownership

Dev Customer may edit only `apps/customer/**` and its own handoff/memory files. Do not edit `apps/platform-api/**`, `apps/back-office/**`, OpenAPI, migrations, or runtime DB state.

Suggested narrow implementation boundary:

```text
Primary:
- apps/customer/pages/waiting-result.vue

Allowed if needed for frontend-only live URL config/testability:
- apps/customer/nuxt.config.ts
- apps/customer/utils/youtubeEmbed.js
- apps/customer/scripts/check-tenant-domain-integration.mjs
- apps/customer/scripts/check-waiting-result-live-reward.mjs
- apps/customer/package.json
```

If you can meet acceptance by editing fewer files, keep it smaller.

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
Reason: assigned implementation files are Dev Customer-owned and no parallel agent is opened for this task.
```

## Acceptance Criteria

- Waiting-result page no longer displays `งวดวันที่ ...` as the visible waiting page metadata.
- The visible metadata in that location is the current game name.
- If the game name is unavailable, the UI uses a safe fallback without rendering `undefined`, `null`, or a broken label.
- The page includes an abbreviated lottery reward result card using `ResultSummaryCard` where practical.
- Reward result data loads through `platformApi.rewardLegacy()` and the existing public results contract: `/public/results/latest` or `/public/results/{game_id}`.
- Reward numbers are not hardcoded.
- If no published result summary is available, the page shows a clear non-breaking waiting/empty state.
- The page includes a YouTube live/embed area.
- The iframe `src`, when present, is derived from a sanitized YouTube URL only.
- Raw arbitrary URLs, `javascript:` URLs, and non-YouTube hosts must not be rendered into an iframe.
- If no YouTube config is present, the page must not render a broken iframe and the handoff must document the frontend config key/source needed.
- Any frontend-only config key must remain customer-side runtime config only. Do not change backend/site-config/OpenAPI contracts.
- Existing navigation actions to `/tickets` and `/result` remain usable.
- Existing sale-closed/waiting-result redirect behavior does not regress.

## YouTube Config Guidance

No existing YouTube/live contract was found in `docs/site-config-contract.md`, `docs/openapi.yaml`, or current customer site-config composables. Use a frontend-only runtime config key or safe absent-config fallback.

Preferred frontend-only runtime key if adding one:

```text
NUXT_PUBLIC_WAITING_RESULT_YOUTUBE_URL
runtimeConfig.public.waitingResultYoutubeUrl
```

Do not read or invent unapproved backend/site-config fields for live URL management. If tenant-managed live URL configuration is required, stop and write a BLOCKED handoff requesting Coordinator scope expansion.

## Automated Test Requirement

Add/update focused frontend validation where practical. At minimum:

- Validate the YouTube URL-to-embed helper or static page wiring so unsafe URLs are rejected and common YouTube URL formats are accepted.
- Validate that waiting-result uses current game metadata instead of the old `งวดวันที่ {{ currentDrawDate }}` label.
- Validate reward card wiring uses `ResultSummaryCard` and `rewardLegacy`.

Use only scripts available from `apps/customer/package.json`. If adding a new script file, wire it into an existing package script such as `test` so it is runnable by `npm run test`.

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first when backend/data is involved.
This task is expected to be customer frontend-only and should not require DB commands.
Do not run migrations, seeds, resets, backend destructive commands, or runtime DB updates.
Do not wipe/reset local runtime DB newpaotang.
```

## Visible Google Chrome QA Requirement

```text
Browser QA is required after Dev Customer completion.
QA must open real Google Chrome visibly to the user and record evidence.
QA must identify browser API/DB target before clean PASS.
Visible Chrome may use local runtime DB only as non-destructive browser coverage and must be reported separately from automated test DB evidence.
Do not claim Chrome uses newpaotang_test unless runtime wiring proves it.
```

## QA Browser Environment

```text
browser URL: customer localhost waiting-result route, exact port to be identified by QA
frontend service: customer Nuxt
API base URL: to be recorded by QA from runtime config/network evidence
automated APP_ENV: testing when backend/data automated checks are involved
automated test DB: newpaotang_test when backend/data automated checks are involved
visible browser runtime DB: QA must record actual runtime target; likely newpaotang for non-destructive localhost coverage if services are wired that way
tenant/domain: actual host used by QA
account/role: public page, no auth expected unless runtime behavior requires it
test data fixture: none expected for non-destructive browser coverage
fixture creation: none expected
fixture cleanup: none expected
evidence path: ai-sub-agents/reports/artifacts/20260526-customer-waiting-result-live-reward/
```

## DB Change Declaration

```text
Does this task add/modify migrations, schema, seed data, or data contract?
Answer: No
If Yes, stop and request Coordinator scope-expansion approval before making the change.
```

## Suggested Validation Commands

Use Docker only for application commands:

```sh
docker compose -p newpaotang exec -T customer npm run test
docker compose -p newpaotang exec -T customer npm run lint
```

Run the focused command(s) that exist after your change. Do not run migrations, seeds, resets, backend destructive commands, or runtime DB updates.

## Expected Handoff

```text
ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
```

The handoff must include:

- Worktree start gate evidence.
- Dirty files before and after work.
- Files changed.
- Automated tests added/updated and validation command output summary.
- Confirmation that no backend/site-config/OpenAPI/DB expansion was made.
- YouTube config key/source used, or absent-config fallback behavior.
- Requested final trigger status: DONE or BLOCKED.

## Next Agent

```text
Orchestrator
```
