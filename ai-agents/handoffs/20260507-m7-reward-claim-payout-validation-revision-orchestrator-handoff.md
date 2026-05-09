# m7-reward-claim-payout-validation-revision Orchestrator Handoff

## Agent

Orchestrator

## Task

Receive the Coordinator M7 QA review decision and create one focused Backend Develop revision task for D1/P1, D2/P1, and D3/P2.

## What Was Done

- Read current Board status.
- Listed latest decisions, handoffs, tasks, and reports.
- Read the Coordinator M7 QA review decision:
  - `ai-agents/decisions/20260507-m7-reward-result-engine-qa-review-decision.md`
- Read the Coordinator M7 QA review handoff:
  - `ai-agents/handoffs/20260507-m7-reward-result-engine-qa-review-coordinator-handoff.md`
- Read the M7 QA report:
  - `ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md`
- Confirmed no existing focused revision Backend task/handoff file existed.
- Read the Orchestrator task template and Docker runtime policy.
- Confirmed the approved revision boundary files currently exist.
- Reviewed focused boundary diff stat and found no existing tracked diff in those files from this Orchestrator step.
- Created the focused Backend Develop revision task:
  - `ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md`
- Kept Orchestrator work limited to `ai-agents/tasks/**` and `ai-agents/handoffs/**`.
- Did not edit app code, source-of-truth docs, reports, decisions, or Board.

## Files Changed

```text
ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md
ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-orchestrator-handoff.md
```

## Validation

Read/inspection commands run:

```sh
sed -n '1,500p' ai-agents/BOARD.md
rg --files ai-agents/decisions ai-agents/handoffs ai-agents/tasks ai-agents/reports | sort | tail -880
git status --short ai-agents/BOARD.md ai-agents/decisions ai-agents/handoffs ai-agents/tasks ai-agents/reports apps/platform-api apps/customer apps/back-office docs document
sed -n '1,760p' ai-agents/decisions/20260507-m7-reward-result-engine-qa-review-decision.md
sed -n '1,620p' ai-agents/handoffs/20260507-m7-reward-result-engine-qa-review-coordinator-handoff.md
sed -n '1,900p' ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md
test -e ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md; echo $?
test -e ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-orchestrator-handoff.md; echo $?
sed -n '1,260p' ai-agents/prompts/orchestrator-task-template.md
sed -n '1,280p' docs/docker-runtime-policy.md
for f in apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php apps/platform-api/app/Shared/Reward/RewardService.php apps/platform-api/tests/Feature/RewardClaimTest.php apps/platform-api/tests/Feature/RewardEngineTest.php apps/platform-api/tests/Support/M7RewardFixtures.php; do test -e "$f" && printf 'exists %s\n' "$f" || printf 'missing %s\n' "$f"; done
git diff --stat -- apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php apps/platform-api/app/Shared/Reward/RewardService.php apps/platform-api/tests/Feature/RewardClaimTest.php apps/platform-api/tests/Feature/RewardEngineTest.php apps/platform-api/tests/Support/M7RewardFixtures.php ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md ai-agents/handoffs/20260507-m7-reward-result-engine-qa-review-coordinator-handoff.md
```

Application runtime validation was not run by Orchestrator.

QA reported:

```text
M7 result: FAIL
Docker validation passed.
D1/P1: tenant reward pay accepts unsupported payout methods and still marks claims paid.
D2/P1: reward claim payout can post a negative wallet credit.
D3/P2: required tenant claim action reasons are not enforced.
```

Required Docker-only validation assigned to Backend Develop:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=RewardClaim
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
```

Post-create verification commands run:

```sh
sed -n '1,760p' ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md
sed -n '1,420p' ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-orchestrator-handoff.md
git status --short ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-orchestrator-handoff.md
```

## Known Risks

```text
This revision is intentionally narrow; Backend Develop should not change reward engine schema, public result APIs, reward checking algorithms, customer app, back-office, source-of-truth docs, bank integration, or notifications.
Failed validation must be proven mutation-safe for claim, ticket, winning ticket, wallet ledger, and outbox state.
Real async queue worker infrastructure remains out of scope.
Real bank transfer and notification providers remain out of scope.
Advanced reward matching rules remain a later Coordinator-approved contract clarification if needed.
Docker-only runtime remains mandatory; no host PHP/Composer/Artisan commands may run.
The workspace already contains unrelated dirty/untracked files from multi-agent workflow; Backend Develop should avoid reverting or touching unrelated changes.
```

## Proposed Board Update

```text
Active Task: 20260507-m7-reward-claim-payout-validation-revision-backend
Coordinator: handoff_sent
Orchestrator: handoff_sent
Backend Develop: ready
QA Tester: waiting_backend_handoff
```

## Next Agent

Backend Develop
