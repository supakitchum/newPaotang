# BO Develop Handoff: Stock Generate Linked Quota Inputs Hotfix

- Task: `stock-generate-linked-quota-inputs-hotfix-bo`
- Latest task context: `back-office-p1-money-stock-crud-workflows`
- Agent: BO Develop Agent
- Worktree: `/Users/supakit/WorkSpace/www/newPaotang-bo-stock-linked-quota`
- Branch: `codex/stock-generate-linked-quota-inputs-hotfix-bo`
- Baseline: `origin/develop` at `1a379c7a02ff9cb58de31bf456044c2b8c9d972d`
- Implementation commit: `15ddf0a7bdd073a2b94e633a8b99bad50f1e6e62`
- Completed at: `2026-05-15 20:25:32 +07`

## Scope

Implemented the Stock Generation BO hotfix in `apps/back-office/**`.

## Changes

- Defaulted Stock Generation game selection/filtering to the single current open game (`status: open`).
- Removed empty/ALL selection from Stock Generation current-game selectors when a current game exists.
- Added clear no-current-game empty state messaging when no single current open game is available.
- Restricted Generate Stock modal game options to the current game and blocks submit when missing.
- Added linked quota synchronization in the Generate Stock modal:
  - `back2_count_per_number = back3_count_per_number * 10`
  - `front3_count_per_number = back3_count_per_number`
  - `total_count = back3_count_per_number * 1000`
- Added inline validation for non-divisible `back2_count_per_number`, invalid totals, quota conflicts, and sync-limit overflow.
- Kept Stock Summary widgets aligned to the selected current game via the page filter default.
- Extended the existing stock summary structural check to cover current-game and linked-quota guardrails.

## Files Changed

- `apps/back-office/components/AdminConfirmAction.vue`
- `apps/back-office/components/AdminFilterBar.vue`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/scripts/check-stock-summary-widgets.mjs`

## Validation

- `git diff --check` passed
- `docker compose -p newpaotang build back-office` passed
- `docker compose -p newpaotang run --rm back-office npm run lint` passed
- `docker compose -p newpaotang run --rm back-office npm run test` passed
- `docker compose -p newpaotang run --rm back-office npm run build` passed
  - Nuxt emitted the existing Node `DEP0180` deprecation warning but exited successfully.
- `docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs` passed

## Notes For Orchestrator

- Backend escalation was not needed. Current game is derived from the documented game status field; BO uses the current/open marker and does not guess by ordering.
- Next agent: Orchestrator should accept this BO handoff and dispatch QA.

## Blockers

- None.
