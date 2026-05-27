# Customer Waiting Result Live Reward Decision

## Decision Type

```text
New work intake
```

## Task Key

```text
customer-waiting-result-live-reward
```

## Date

```text
2026-05-26
```

## Execution Mode

```text
AUTO
```

Fallback:

```text
MANUAL if Codex native runner / multi_agent_v1.spawn_agent is unavailable
```

## User Requirement

```text
- หน้ารอผล งวดวันที่ ให้เป็นชื่อเกมแทน
- เอา card ผลรางวัลสลากฯ แบบย่อมาแสดงไว้ที่หน้านี้ด้วย
- ต้องการให้มี youtube embed สำหรับถ่ายทอดสดไว้ที่หน้านี้ด้วย
```

## Coordinator Interpretation

Customer waiting-result page must become a richer result-waiting surface:

- Replace the visible draw-date wording on the waiting-result page with the current game name.
- Show the existing abbreviated lottery reward summary card style on the waiting-result page.
- Add a YouTube live/embed area on the waiting-result page for result livestream viewing.

No backend/API/schema change is approved at intake. YouTube configuration must use an existing frontend/runtime configuration path if one exists. If no existing source exists, the owning agent may add a frontend-only runtime config key or safe UI fallback and must document it in the handoff. Backend/site-config expansion requires evidence and a Coordinator scope-expansion decision.

## Current Evidence

```text
branch: develop
HEAD: 9ba44c5d91bfbc6c74d106e7144bfb52e0c01507
origin/develop: 9ba44c5d91bfbc6c74d106e7144bfb52e0c01507
```

Relevant findings:

- `apps/customer/pages/waiting-result.vue` exists as an untracked file and currently shows `งวดวันที่ {{ currentDrawDate }}`.
- `apps/customer/components/ResultSummaryCard.vue` already provides the abbreviated lottery result card.
- `apps/customer/composables/usePlatformApi.ts` already provides `rewardLegacy()` backed by `/public/results/latest` or `/public/results/{game_id}`.
- Focused search found no current YouTube/live embed contract in `docs/site-config-contract.md`, `docs/openapi.yaml`, or `apps/customer` runtime site config.
- Worktree has many dirty files, including customer files in and near this scope.

## Task Classification

```text
Task Size: STANDARD
Flow Mode: STANDARD
Primary Owner: Dev Customer
Conditional Agents: Dev Backend only with evidence and Coordinator approval
Fast Path Eligibility: No
Reason Orchestrator is used/skipped: Orchestrator is used because the worktree already has dirty/untracked customer files in the task area, and the YouTube configuration source is not yet an established contract. This violates the no-risk FAST_PATH condition even though implementation is expected to remain customer-owned.
```

## Priority

```text
P2 customer result-waiting experience
```

Reason: This is user-facing on a sale-closed/waiting-result page but does not currently indicate payment, wallet, ledger, tenant isolation, auth, permission, security, privacy, migration, or schema risk.

## Scope

- Customer waiting-result route/page only, expected under `apps/customer/pages/waiting-result.vue`.
- Customer-side composable usage needed to read current game name from existing app init/current game state.
- Customer-side usage of existing result summary API/card, preferably reusing `ResultSummaryCard`.
- Customer-side YouTube embed/live section with safe URL handling and no broken iframe when config is absent.
- Focused frontend validation for waiting-result rendering and any URL normalization/helper added.
- Preserve the existing alias `/wait-result` unless Orchestrator finds a reason to change it.

## Out Of Scope

- Backend API changes without evidence and Coordinator scope-expansion decision.
- OpenAPI/site-config contract changes without evidence and Coordinator scope-expansion decision.
- DB migration/schema/seed changes.
- Payment, wallet, checkout, ticket ownership, reservation, cart, or reward payout logic changes.
- Runtime DB update.
- Redesign of unrelated customer pages.
- Opening conditional agents just in case.

## Source Of Truth

```text
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/fast-path.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/sub-agent-reuse.md
ai-sub-agents/workflow/runner-polling.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/roles/orchestrator.md
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
```

## Agent Assignment

Primary expected implementation owner:

```text
Dev Customer
```

Orchestrator responsibilities:

- Confirm whether the pre-existing dirty customer files are safe to build on or require blocker handling.
- Create the Dev Customer task/trigger if safe.
- Keep scope customer-only unless evidence proves otherwise.
- Define exact expected handoff and QA criteria.

Conditional:

```text
Dev Backend
```

Condition for Dev Backend: only if Dev Customer or Orchestrator finds evidence that current backend contracts cannot provide the required result summary or live URL configuration, and Coordinator approves scope expansion.

QA:

```text
QA Tester
```

QA is required because this is browser-visible customer UI.

## Milestones

1. Orchestrator validates dirty worktree risk, source contracts, and single-owner customer scope.
2. Dev Customer implements the waiting-result UI changes inside customer ownership only.
3. Dev Customer runs focused frontend validation/scripts available in `apps/customer/package.json` and records evidence.
4. Orchestrator completion check verifies dev handoff, dirty-file handling, and no unapproved cross-owner changes.
5. QA Tester performs focused automated review plus visible Google Chrome browser QA.
6. Coordinator reviews QA report before GitOps.

## Acceptance Criteria

- Waiting-result page no longer displays the `งวดวันที่ ...` label as the primary waiting page metadata.
- Waiting-result page displays the current game name in that location, using current game/init state where available.
- If current game name is unavailable, the UI uses a safe fallback without rendering `undefined`, `null`, or a broken label.
- Waiting-result page includes an abbreviated lottery reward result card using the existing customer result-card pattern where practical.
- The reward card loads from the existing public result summary path and does not invent or hardcode prize numbers.
- If no published result summary is available, the page shows a clear non-breaking waiting/empty state.
- Waiting-result page includes a YouTube live/embed area.
- YouTube embed uses a safe iframe URL derived from an approved frontend/runtime config or documented frontend-only fallback; raw untrusted arbitrary URLs must not be injected directly.
- If no YouTube URL/config is available in local runtime, the page must not show a broken iframe and the handoff must document the config key/source needed.
- Existing navigation actions to tickets/result remain usable unless Orchestrator approves a route adjustment.
- Existing sale-closed/waiting-result redirect behavior does not regress.
- No backend, schema, migration, seed, payment, wallet, or runtime DB update is introduced without a separate Coordinator decision.

## Automated Test Expectations

Dev Customer:

```text
Add/update focused frontend validation where practical.
At minimum, validate any helper that derives/sanitizes YouTube embed URLs and any waiting-result data mapping that can be tested without full browser runtime.
Use only scripts that exist in apps/customer/package.json.
Do not run migrations, seeds, resets, backend destructive commands, or runtime DB updates.
```

QA Tester:

```text
Visible browser QA is required.
Automated/destructive checks must use test env/test DB if backend/data is touched.
Visible Chrome on localhost may use runtime DB newpaotang only for non-destructive browser coverage, and must be reported separately from automated test DB evidence.
Do not claim Chrome uses newpaotang_test unless runtime wiring proves it.
```

## QA Browser Environment Expectation

```text
browser URL: customer localhost waiting-result route, exact port to be identified by QA
frontend service: customer Nuxt
API base URL: to be recorded by QA from runtime config/network evidence
automated APP_ENV: testing when backend/data automated checks are involved
automated test DB: newpaotang_test when backend/data automated checks are involved
visible browser runtime DB: record actual runtime target; likely newpaotang if local localhost is used non-destructively
tenant/domain: record actual host used
account/role: public page, no auth expected unless runtime route behavior requires it
fixture creation: none expected for non-destructive browser coverage
fixture cleanup: none expected
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No
Reason: Expected customer frontend-only UI/config work. Any DB/schema/data-contract need must trigger scope expansion first.
```

## Risks / Watch Points

- Dirty customer files pre-exist in the worktree. Orchestrator must decide whether they are safe task context or a blocker before Dev Customer edits.
- Do not create backend or site-config contract work just because a live URL would ideally be tenant-managed; evidence and Coordinator approval are required.
- Do not hardcode a production-only YouTube URL unless it is already present in an approved config/source.
- YouTube iframe must not introduce unsafe URL injection.
- Result card on a waiting-result page may show latest published result, not necessarily the waiting game; the UI must avoid misleading hardcoded claims and document behavior.

## Coordinator Restrictions

```text
Coordinator did not write implementation code.
Coordinator did not run build/test/migration/seed/reset.
Coordinator did not update runtime DB.
Coordinator did not open conditional agents.
```

## Required Outputs

Orchestrator must create downstream task/trigger only after dirty-file/source checks:

```text
ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md
```

Expected Orchestrator handoff:

```text
ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
```

QA after dev completion:

```text
ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-qa-tester.md
ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-qa-tester-trigger.md
ai-sub-agents/reports/20260526-customer-waiting-result-live-reward-qa-report.md
```

## Next Agent

```text
Orchestrator
```

## Trigger

```text
ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-orchestrator-trigger.md
```
