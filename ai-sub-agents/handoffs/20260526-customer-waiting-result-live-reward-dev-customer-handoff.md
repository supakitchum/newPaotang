# Customer Waiting Result Live Reward Dev Customer Handoff

## Agent

```text
Dev Customer
```

## Task

Implement the customer `/waiting-result` page changes:

- Replace the visible `งวดวันที่ ...` metadata with the current game name from app init state.
- Add an abbreviated reward summary card using existing public reward results.
- Add a safe YouTube live/embed area using customer runtime config only.
- Add focused frontend validation.

## Task Classification

```text
Execution Mode: AUTO
Task Size: STANDARD
Flow Mode: STANDARD
Primary Owner: Dev Customer
Conditional Agents: Dev Backend only with concrete API/contract evidence and Coordinator approval
Requested final trigger status: DONE
Next Agent: Orchestrator
```

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: 9ba44c5d91bfbc6c74d106e7144bfb52e0c01507
origin/develop: 9ba44c5d91bfbc6c74d106e7144bfb52e0c01507
```

Worktree start gate commands run:

```text
git fetch origin: PASS
git status --short --branch: PASS, dirty worktree present
git merge --ff-only origin/develop: PASS, Already up to date.
git status --short: PASS, dirty worktree present
git rev-parse HEAD: 9ba44c5d91bfbc6c74d106e7144bfb52e0c01507
git rev-parse origin/develop: 9ba44c5d91bfbc6c74d106e7144bfb52e0c01507
```

Dirty files before Dev Customer edits:

```text
 M ai-sub-agents/flow-ai-agent.md
 M ai-sub-agents/memory/coordinator/memory.md
 M ai-sub-agents/memory/gitops/memory.md
 M ai-sub-agents/memory/orchestrator/memory.md
 M ai-sub-agents/memory/qa-tester/memory.md
 M ai-sub-agents/roles/coordinator.md
 M ai-sub-agents/roles/orchestrator.md
 M ai-sub-agents/roles/qa-tester.md
 M ai-sub-agents/rules/global-rules.md
 M ai-sub-agents/runner/README.md
 M ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-gitops-trigger.heartbeat.md
 M ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-gitops-runner-log.md
 M ai-sub-agents/templates/handoff-template.md
 M ai-sub-agents/templates/qa-report-template.md
 M ai-sub-agents/templates/task-template.md
 M ai-sub-agents/templates/trigger-template.md
 M ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-gitops-trigger.md
 M ai-sub-agents/triggers/README.md
 M ai-sub-agents/workflow/background-runner.md
 M ai-sub-agents/workflow/execution-mode.md
 M ai-sub-agents/workflow/file-ownership.md
 M ai-sub-agents/workflow/handoff-protocol.md
 M ai-sub-agents/workflow/qa-browser-env.md
 M ai-sub-agents/workflow/stage-gates.md
 M ai-sub-agents/workflow/trigger-protocol.md
 M apps/customer/app.vue
 M apps/customer/composables/useAppInit.ts
 M apps/customer/composables/usePlatformApi.ts
 M apps/customer/pages/buy/search.vue
 M apps/customer/scripts/check-exact-six-search-identity.mjs
 M apps/customer/scripts/check-tenant-domain-integration.mjs
 M apps/customer/utils/customerAuthRoutes.ts
 M apps/platform-api/.phpunit.result.cache
 M apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php
 M apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
 M apps/platform-api/tests/Feature/CustomerReservationTest.php
 M apps/platform-api/tests/Feature/PublicStockSearchTest.php
?? ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
?? ai-sub-agents/gitops/20260525-customer-exact-six-duplicate-results-gitops-report.md
?? ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
?? ai-sub-agents/runner/agents/
?? ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-dev-customer-trigger.claim.md
?? ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-orchestrator-trigger.claim.md
?? ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-dev-customer-trigger.heartbeat.md
?? ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-orchestrator-trigger.heartbeat.md
?? ai-sub-agents/runner/logs/20260526-customer-waiting-result-live-reward-dev-customer-runner-log.md
?? ai-sub-agents/runner/logs/20260526-customer-waiting-result-live-reward-orchestrator-runner-log.md
?? ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
?? ai-sub-agents/templates/agent-registry-template.md
?? ai-sub-agents/templates/codex-spawn-prompt-template.md
?? ai-sub-agents/templates/coordinator-runner-prompt.md
?? ai-sub-agents/templates/runner-log-template.md
?? ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md
?? ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-orchestrator-trigger.md
?? ai-sub-agents/workflow/codex-native-runner.md
?? ai-sub-agents/workflow/fast-path.md
?? ai-sub-agents/workflow/runner-polling.md
?? ai-sub-agents/workflow/sub-agent-reuse.md
?? apps/customer/composables/useSaleClosureGuard.ts
?? apps/customer/pages/waiting-result.vue
```

Dirty files after Dev Customer edits:

```text
 M ai-sub-agents/flow-ai-agent.md
 M ai-sub-agents/memory/coordinator/memory.md
 M ai-sub-agents/memory/gitops/memory.md
 M ai-sub-agents/memory/orchestrator/memory.md
 M ai-sub-agents/memory/qa-tester/memory.md
 M ai-sub-agents/roles/coordinator.md
 M ai-sub-agents/roles/orchestrator.md
 M ai-sub-agents/roles/qa-tester.md
 M ai-sub-agents/rules/global-rules.md
 M ai-sub-agents/runner/README.md
 M ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-gitops-trigger.heartbeat.md
 M ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-gitops-runner-log.md
 M ai-sub-agents/templates/handoff-template.md
 M ai-sub-agents/templates/qa-report-template.md
 M ai-sub-agents/templates/task-template.md
 M ai-sub-agents/templates/trigger-template.md
 M ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-gitops-trigger.md
 M ai-sub-agents/triggers/README.md
 M ai-sub-agents/workflow/background-runner.md
 M ai-sub-agents/workflow/execution-mode.md
 M ai-sub-agents/workflow/file-ownership.md
 M ai-sub-agents/workflow/handoff-protocol.md
 M ai-sub-agents/workflow/qa-browser-env.md
 M ai-sub-agents/workflow/stage-gates.md
 M ai-sub-agents/workflow/trigger-protocol.md
 M apps/customer/app.vue
 M apps/customer/composables/useAppInit.ts
 M apps/customer/composables/usePlatformApi.ts
 M apps/customer/nuxt.config.ts
 M apps/customer/package.json
 M apps/customer/pages/buy/search.vue
 M apps/customer/scripts/check-exact-six-search-identity.mjs
 M apps/customer/scripts/check-tenant-domain-integration.mjs
 M apps/customer/utils/customerAuthRoutes.ts
 M apps/platform-api/.phpunit.result.cache
 M apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php
 M apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
 M apps/platform-api/tests/Feature/CustomerReservationTest.php
 M apps/platform-api/tests/Feature/PublicStockSearchTest.php
?? ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
?? ai-sub-agents/gitops/20260525-customer-exact-six-duplicate-results-gitops-report.md
?? ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
?? ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
?? ai-sub-agents/runner/agents/
?? ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-dev-customer-trigger.claim.md
?? ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-orchestrator-trigger.claim.md
?? ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-dev-customer-trigger.heartbeat.md
?? ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-orchestrator-trigger.heartbeat.md
?? ai-sub-agents/runner/logs/20260526-customer-waiting-result-live-reward-dev-customer-runner-log.md
?? ai-sub-agents/runner/logs/20260526-customer-waiting-result-live-reward-orchestrator-runner-log.md
?? ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
?? ai-sub-agents/templates/agent-registry-template.md
?? ai-sub-agents/templates/codex-spawn-prompt-template.md
?? ai-sub-agents/templates/coordinator-runner-prompt.md
?? ai-sub-agents/templates/runner-log-template.md
?? ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md
?? ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-orchestrator-trigger.md
?? ai-sub-agents/workflow/codex-native-runner.md
?? ai-sub-agents/workflow/fast-path.md
?? ai-sub-agents/workflow/runner-polling.md
?? ai-sub-agents/workflow/sub-agent-reuse.md
?? apps/customer/composables/useSaleClosureGuard.ts
?? apps/customer/pages/waiting-result.vue
?? apps/customer/scripts/check-waiting-result-live-reward.mjs
?? apps/customer/utils/youtubeEmbed.js

The pre-existing untracked file apps/customer/pages/waiting-result.vue was edited for this task and remains untracked.
No apps/platform-api/**, apps/back-office/**, docs/openapi.yaml, migrations, seeds, runtime DB state, or trigger status files were edited by Dev Customer.
Unrelated dirty files apps/customer/pages/buy/search.vue and apps/customer/scripts/check-exact-six-search-identity.mjs were not edited.
```

## Trigger Status

```text
trigger file: ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md
trigger status before work: RUNNING
trigger status after work: RUNNING, unchanged by Dev Customer
trigger status owner: AUTO Mode runner
requested final status: DONE
runner claim file: ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-dev-customer-trigger.claim.md
heartbeat file: ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-dev-customer-trigger.heartbeat.md
runner log: ai-sub-agents/runner/logs/20260526-customer-waiting-result-live-reward-dev-customer-runner-log.md
```

Runner evidence inspected:

```text
claim: dependency check PASS; status at claim time PENDING
heartbeat: status RUNNING; expected output is this handoff
runner log: PENDING -> RUNNING recorded; poll saw handoff missing before implementation completion
```

## What Was Done

- Updated `/waiting-result` and alias `/wait-result` page UI to display `currentGame.value?.name` from `useAppInit()` as the visible waiting metadata.
- Added safe fallback text `รอข้อมูลเกมปัจจุบัน` so the page does not render `undefined`, `null`, or an empty broken label.
- Added the abbreviated reward summary section using `ResultSummaryCard`.
- Loaded reward summary through `platformApi.rewardLegacy()` with the existing latest public result path; reward numbers are not hardcoded.
- Added loading, retry/error, and empty states for missing reward summary.
- Added a YouTube live area.
- Added `NUXT_PUBLIC_WAITING_RESULT_YOUTUBE_URL` to customer `runtimeConfig.public.waitingResultYoutubeUrl`.
- Added `sanitizeYoutubeEmbedUrl()` to convert allowed YouTube URLs to `https://www.youtube.com/embed/<video_id>` and reject empty, arbitrary, `javascript:`, malformed, or non-YouTube URLs.
- Rendered the iframe only when a sanitized YouTube embed URL exists; absent config shows a non-breaking empty state instead of a broken iframe.
- Added focused validation script and wired it into `npm run test`.

## Files Changed

```text
apps/customer/pages/waiting-result.vue
apps/customer/nuxt.config.ts
apps/customer/package.json
apps/customer/scripts/check-waiting-result-live-reward.mjs
apps/customer/utils/youtubeEmbed.js
ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
```

Notes:

```text
apps/customer/pages/waiting-result.vue was already untracked before work began; this task built on that Orchestrator-approved in-scope context.
apps/customer/scripts/check-waiting-result-live-reward.mjs and apps/customer/utils/youtubeEmbed.js are new customer-owned files.
```

## Automated Tests Added Or Updated

Added:

```text
apps/customer/scripts/check-waiting-result-live-reward.mjs
```

Updated:

```text
apps/customer/package.json
- npm run test now includes node scripts/check-waiting-result-live-reward.mjs
- added npm run test:waiting-result for focused validation
```

Focused validation covers:

```text
YouTube URL sanitizer accepts common youtube.com, youtu.be, youtube-nocookie embed/live/watch formats.
YouTube URL sanitizer rejects empty, javascript:, arbitrary host, deceptive youtube.com.evil host, and invalid video ID inputs.
Waiting-result page uses runtimeConfig.public.waitingResultYoutubeUrl.
Waiting-result iframe is guarded by sanitized youtubeEmbedUrl.
Waiting-result page no longer uses currentDrawDate / old "งวดวันที่ {currentDrawDate}" metadata.
Waiting-result page uses currentGameName safe fallback.
Waiting-result page uses ResultSummaryCard and platformApi.rewardLegacy().
Waiting-result reward summary uses latest public result data.
Waiting-result page keeps /tickets and /result navigation.
The new validation is wired into npm run test.
```

## Validation

All application commands were run through Docker as requested.

```text
docker compose -p newpaotang exec -T customer npm run test:waiting-result
result: PASS
summary: 20 waiting-result live/reward checks passed, including YouTube accept/reject cases and page wiring checks.
```

```text
docker compose -p newpaotang exec -T customer npm run test
result: PASS
summary: tenant-domain integration checks passed, exact-six search identity checks passed, and waiting-result live/reward checks passed.
```

```text
docker compose -p newpaotang exec -T customer npm run lint
result: PASS
summary: tenant-domain integration checks passed.
```

```text
docker compose -p newpaotang exec -T customer npm run build
result: PASS
summary: Nuxt client, server, and Nitro server build completed successfully.
```

## Test Env / DB Safety

```text
Backend/data involved: No
APP_ENV used: not applicable; customer frontend/static validation only
DB_DATABASE used: not applicable
Destructive DB commands run: None
Migrations/seeds/resets run: None
Local runtime DB updated: No
No backend/site-config/OpenAPI/DB/runtime expansion was made.
```

## YouTube Config / Fallback

```text
frontend env key: NUXT_PUBLIC_WAITING_RESULT_YOUTUBE_URL
runtime source: runtimeConfig.public.waitingResultYoutubeUrl
sanitizer: apps/customer/utils/youtubeEmbed.js sanitizeYoutubeEmbedUrl()
allowed output shape: https://www.youtube.com/embed/<11-character-video-id>
absent config behavior: iframe is not rendered; page shows "ระบบจะแสดงถ่ายทอดสดเมื่อพร้อมใช้งาน"
unsafe config behavior: iframe is not rendered for empty, javascript:, malformed, non-YouTube, deceptive host, or invalid video ID URLs
```

No backend/site-config/OpenAPI field was invented for YouTube/live URL management.

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
Reason: implementation stayed within Dev Customer-owned files and no parallel implementation agents were assigned.
```

## Memory Updates

```text
memory file read: ai-sub-agents/memory/dev-customer/memory.md
memory file updated: No
summary: No memory update was needed; this task did not add a broad reusable workflow beyond the task-specific helper/test files.
```

## Known Risks

- Browser-visible QA is still required by the next gate.
- The page fetches the latest public reward summary via `platformApi.rewardLegacy()` so the card can be shown while the current game is still waiting for results. The card itself displays the result draw label from the public result payload; if no latest summary exists, the page shows the empty state.
- No tenant-managed live URL contract exists in the approved scope. Current implementation is frontend-only runtime config plus safe absent-config behavior.
- The worktree contains many unrelated pre-existing dirty files; they were recorded and not touched.

## Questions For Coordinator

```text
None.
```

## Next Agent

```text
Orchestrator
```
