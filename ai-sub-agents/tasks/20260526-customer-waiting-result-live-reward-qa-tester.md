# Customer Waiting Result Live Reward QA Tester Task

## Owner Agent

```text
QA Tester
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
Reason Orchestrator is used/skipped: Orchestrator is used for STANDARD flow and completion check because the task had dirty customer files in scope and no established YouTube/live URL backend contract.
```

## Objective

Perform focused QA for the customer `/waiting-result` live reward experience after Dev Customer implementation. QA must verify automated evidence and perform visible Google Chrome browser acceptance with clear separation between automated test DB evidence and the visible browser runtime API/DB target.

## Scope

- Customer `/waiting-result` page and `/wait-result` alias.
- Current game-name metadata replacing the previous draw-date label.
- Reward summary card/empty state using the customer result summary pattern.
- YouTube live/embed absent-config and safe-config behavior.
- Navigation actions to `/tickets` and `/result`.
- Non-destructive browser acceptance only.

## Out Of Scope

- Editing implementation code.
- Backend, OpenAPI, migration, seed, runtime DB, payment, wallet, checkout, ticket ownership, reservation, reward payout, or site-config contract changes.
- Destructive DB commands against local runtime DB `newpaotang`.
- Claiming visible Chrome uses `newpaotang_test` unless runtime wiring proves it.

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
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/roles/qa-tester.md
docs/frontend-routes.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/openapi.yaml
ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
apps/customer/pages/waiting-result.vue
apps/customer/nuxt.config.ts
apps/customer/package.json
apps/customer/scripts/check-waiting-result-live-reward.mjs
apps/customer/utils/youtubeEmbed.js
apps/customer/components/ResultSummaryCard.vue
apps/customer/composables/useAppInit.ts
apps/customer/composables/usePlatformApi.ts
```

## Agent Memory

```text
Read ai-sub-agents/memory/qa-tester/memory.md before starting.
Use memory as a hint only; source of truth remains this task, docs, current code, and handoffs.
Update memory only if reusable QA/browser/runtime wiring knowledge is learned.
```

## Trigger

```text
Trigger file: ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-qa-tester-trigger.md
AUTO Mode: runner marks trigger RUNNING/DONE/BLOCKED.
Agent writes requested trigger final status in QA report.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md status DONE
- ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-orchestrator-completion-trigger.md status DONE
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-ready-for-qa-handoff.md
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
- ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
unblocks:
- Coordinator QA review after ai-sub-agents/reports/20260526-customer-waiting-result-live-reward-qa-report.md exists
```

## Conditional Agent Expansion

```text
May open additional agents: No
Required evidence before expansion: QA failure evidence identifying root cause outside customer-owned implementation
Coordinator approval required before expansion: Yes
Backend expansion allowed only when: concrete API/contract/backend defect evidence exists and Coordinator approves scope expansion
```

## Worktree Start Gate

```text
Read ai-sub-agents/workflow/worktree-start-gate.md.
Run the required commands before testing.
Record dirty files before and after QA.
Stop and report BLOCKED if start gate fails, if this trigger is CANCELLED, or if implementation files needed for QA have changed unexpectedly after Orchestrator ready-for-QA handoff.
```

## Ownership

QA Tester may write:

```text
ai-sub-agents/reports/20260526-customer-waiting-result-live-reward-qa-report.md
ai-sub-agents/reports/artifacts/20260526-customer-waiting-result-live-reward/**
ai-sub-agents/memory/qa-tester/memory.md if reusable QA knowledge is added
```

QA Tester must not edit:

```text
apps/**
docs/openapi.yaml
database migrations
runtime DB state
trigger status fields in AUTO Mode
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
Release evidence: Not applicable
```

## Acceptance Criteria

- Dev Customer trigger is `DONE` and Dev Customer handoff exists.
- QA report records that Dev Customer already ran these Docker validations:
  - `docker compose -p newpaotang exec -T customer npm run test:waiting-result`
  - `docker compose -p newpaotang exec -T customer npm run test`
  - `docker compose -p newpaotang exec -T customer npm run lint`
  - `docker compose -p newpaotang exec -T customer npm run build`
- QA runs focused automated/front-end validation appropriate for this browser-visible change, or explains why rerun was not possible.
- `/waiting-result` visible metadata shows the current game name, not the old `งวดวันที่ ...` metadata.
- If game name is unavailable, UI uses a safe fallback without `undefined`, `null`, or a broken label.
- Reward summary area uses the abbreviated result card pattern when public result data is available.
- Reward summary empty/loading/error states are non-breaking when no public result summary is available.
- Reward numbers are not hardcoded by the page.
- YouTube absent-config behavior does not render a broken iframe and shows a non-breaking empty/live-coming-soon state.
- YouTube safe-config behavior renders a sanitized `https://www.youtube.com/embed/<video_id>` iframe.
- Unsafe/non-YouTube config does not inject raw URLs into iframe `src`.
- `/tickets` and `/result` navigation actions remain usable.
- `/wait-result` alias routes to the waiting-result experience or otherwise preserves expected alias behavior.
- No backend, OpenAPI, migration, seed, runtime DB, payment, wallet, checkout, reservation, or reward payout behavior was changed or required for PASS.

## Automated Test Requirement

Record Dev Customer prior validation from the handoff.

Recommended QA rerun commands, using Docker only:

```sh
docker compose -p newpaotang exec -T customer npm run test:waiting-result
docker compose -p newpaotang exec -T customer npm run test
```

Optional if QA needs broader confidence and service time allows:

```sh
docker compose -p newpaotang exec -T customer npm run lint
```

Do not run migrations, seeds, resets, backend destructive commands, or runtime DB updates.

## Test Env / DB Requirement

```text
Backend/data involved by implementation: No
Automated frontend/static validation DB: Not applicable; record N/A explicitly if no backend/API automated DB check is run
If QA adds any backend/API/data automated check: use APP_ENV=testing and DB_DATABASE=newpaotang_test
Destructive DB commands: forbidden except against APP_ENV=testing DB_DATABASE=newpaotang_test, and none are expected for this task
Runtime DB update: forbidden
```

## Visible Google Chrome QA Requirement

```text
Required: Yes
Browser: real Google Chrome app, visible to the user
Headless browser is not sufficient for acceptance.
QA must identify browser API base URL and visible browser runtime DB target before clean PASS.
Visible Chrome may use local runtime DB newpaotang only for non-destructive coverage and must report it separately from automated test DB evidence.
Do not claim Chrome uses newpaotang_test unless runtime wiring proves it.
```

Visible Chrome scenarios to cover:

```text
1. Open /waiting-result with default/absent YouTube config and verify no broken iframe is rendered.
2. Verify current game-name metadata area and safe fallback behavior when observable.
3. Verify reward summary card or empty state is present and non-breaking.
4. Verify /tickets and /result navigation links are visible and usable.
5. Verify /wait-result alias behavior.
6. Verify safe YouTube config behavior with a valid YouTube URL if QA can control the customer runtime config for the visible browser run.
7. Verify unsafe YouTube config behavior if QA can control runtime config; otherwise record static automated sanitizer evidence and visible absent-config evidence separately.
```

Suggested safe config sample for a controlled QA runtime:

```text
NUXT_PUBLIC_WAITING_RESULT_YOUTUBE_URL=https://www.youtube.com/watch?v=M7lc1UVf-VE
expected iframe src: https://www.youtube.com/embed/M7lc1UVf-VE
```

## QA Browser Environment

```text
browser URL: exact customer localhost /waiting-result and /wait-result URLs to be identified by QA
frontend service: customer Nuxt
API base URL: record actual target from runtime config/network evidence
APP_ENV: testing only for backend/API automated checks; record N/A for frontend-only static validation
automated test DB: newpaotang_test if backend/API automated checks are used; otherwise N/A with explanation
visible browser runtime DB: identify actual runtime target; likely newpaotang if existing localhost services are wired that way, but do not assume
tenant/domain: record actual host used
account/role: public page, no auth expected unless runtime behavior requires it
test data fixture: none expected; use existing non-destructive runtime data
fixture creation: none expected
fixture cleanup: none expected
browser API/DB target proof: required via runtime config, network request evidence, Docker env, or equivalent
evidence path: ai-sub-agents/reports/artifacts/20260526-customer-waiting-result-live-reward/
```

## DB Change Declaration

```text
Does this task add/modify migrations, schema, seed data, or data contract?
Answer: No
DB update required after Coordinator approval: No
Reason: Dev Customer implementation is customer frontend-only and declared no backend/schema/data-contract change.
```

## Suggested Validation Commands

Use Docker only for application commands:

```sh
docker compose -p newpaotang exec -T customer npm run test:waiting-result
docker compose -p newpaotang exec -T customer npm run test
docker compose -p newpaotang exec -T customer npm run lint
```

If QA starts or inspects local services for visible Chrome, record exact commands, URLs, API base, and runtime DB/API target proof in the QA report.

## Expected Report

```text
ai-sub-agents/reports/20260526-customer-waiting-result-live-reward-qa-report.md
```

QA report must include:

```text
worktree evidence
trigger evidence
Dev Customer validation evidence
Automated Test Env / Test DB Evidence
Visible Google Chrome Evidence
browser API/DB target proof
Runtime DB Safety
Memory Updates
recommendation: PASS, FAIL, PASS WITH RISK, or BLOCKED
requested final trigger status: DONE or BLOCKED
Next Agent: Coordinator
```

## Next Agent

```text
Coordinator
```
