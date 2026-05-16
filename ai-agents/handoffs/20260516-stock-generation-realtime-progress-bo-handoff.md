# stock-generation-realtime-progress-bo Handoff

## Agent

BO Develop

## Task

Back-office realtime stock generation progress.

Implementation commit:

```text
d38abac3c1daf8e696ce828f7d2832df24162800
```

Branch:

```text
codex/stock-generation-realtime-progress-bo
```

## Files Changed

```text
apps/back-office/components/AdminStockGenerationBatches.vue
apps/back-office/composables/useAdminRealtime.ts
apps/back-office/nuxt.config.ts
apps/back-office/scripts/check-stock-summary-widgets.mjs
apps/back-office/scripts/check.mjs
```

## Backend Channel / Event Contract Used

BO uses the backend handoff contract from `20260516-stock-generation-realtime-progress-backend-handoff.md`.

Subscribed channel:

```text
private-admin.central.stock-generation.game.{game_id}
```

Auth endpoint:

```text
POST /api/v1/admin/central/realtime/auth
X-Admin-Scope: central
```

Event:

```text
stock.generation.progress.updated
```

Payload fields consumed:

```text
batch_id
game_id
status
requested_count
generated_count
total_rounds
processed_rounds
chunk_rounds
failure_reason
image_dispatch_status
```

## Websocket Subscription / Auth Handling

- Added `useAdminRealtimeSubscription`.
- Uses native WebSocket with the Pusher/Reverb protocol:
  - waits for `pusher:connection_established`
  - authorizes the private channel through `/admin/central/realtime/auth`
  - sends `pusher:subscribe`
  - sends `pusher:unsubscribe` on cleanup
  - responds to `pusher:ping` with `pusher:pong`
- Runtime config added:

```text
NUXT_PUBLIC_ADMIN_REALTIME_URL / VITE_ADMIN_REALTIME_URL
NUXT_PUBLIC_ADMIN_REALTIME_KEY / VITE_ADMIN_REALTIME_KEY
```

Default key is `newpaotang-admin`; realtime URL defaults to empty so environments without Reverb use fallback mode instead of fake realtime.

Admin session handling:

- Subscription starts only after client runtime, admin access token, selected game id, and channel name are ready.
- Auth calls use the existing `useAdminApi()` path, so Authorization and `X-Admin-Scope: central` are applied consistently.
- 401/403 realtime auth failures stop reconnect loops instead of retrying authorization repeatedly.

## Progress Update Behavior

- REST still loads the initial list/detail snapshot.
- After the websocket event arrives, BO maps `batch_id` to the selected/list batch id and updates the in-memory batch list/detail without refetching immediately.
- Event progress updates still trigger the parent `progress` emit so stock summary widgets refresh on meaningful progress/completion changes.
- Existing duplicate submit prevention remains based on active `queued`, `pending`, or `processing` batch state.

## Polling Removal Evidence

Removed the active 5-second `generation-batches` loop from `AdminStockGenerationBatches.vue`.

Removed tokens from the component:

```text
pollIntervalMs: 5000
window.setInterval
```

Structural evidence command:

```sh
docker compose -p newpaotang run --rm back-office sh -lc '! grep -n "pollIntervalMs: 5000\|window.setInterval" components/AdminStockGenerationBatches.vue && grep -n "fallbackPollIntervalMs: 60000\|stock.generation.progress.updated\|private-admin.central.stock-generation.game\." components/AdminStockGenerationBatches.vue && grep -n "pusher:subscribe\|/admin/central/realtime/auth" composables/useAdminRealtime.ts'
```

Result: passed. The command found the realtime/fallback tokens and no 5-second polling tokens.

## Fallback Polling

Fallback polling remains only as a safety net when realtime is unavailable/error/reconnecting.

Frequency:

```text
60 seconds default, minimum clamped to 30 seconds
```

The fallback uses `window.setTimeout`, not the removed active 5-second `setInterval` loop. When realtime is connecting/authenticating/connected, fallback polling is not scheduled.

## Manual Refresh

The existing Refresh button still calls the REST list/detail snapshot manually. This is separate from fallback polling and remains available whether realtime is connected or not.

## Reconnect Snapshot

The realtime composable calls the component `onReconnect` handler after a reconnect. The component then fetches one fresh REST snapshot with `loadBatches()` to reconcile any missed progress events.

## Unsubscribe Cleanup

`useAdminRealtimeSubscription` sends `pusher:unsubscribe` for the current channel when the component/session/channel is torn down, then closes the socket. The component also clears the fallback timer on unmount.

## Summary Widget Refresh Behavior

Realtime progress events update the selected/list batch and call the existing parent `progress` emit. `AdminOperationsPage` already refreshes `AdminStockSummaryWidgets` from that event path, so summary refresh now follows pushed progress instead of chatty polling.

## UI Notes

- The progress card header now shows a compact badge:
  - `Realtime`
  - `Connecting realtime`
  - `Fallback 60s`
  - `Realtime idle`
- Existing loading/error/empty states, current-game default, no ALL option, and duplicate-submit blocking are preserved.

## Validation

Commands run and passed:

```sh
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office sh -lc '! grep -n "pollIntervalMs: 5000\|window.setInterval" components/AdminStockGenerationBatches.vue && grep -n "fallbackPollIntervalMs: 60000\|stock.generation.progress.updated\|private-admin.central.stock-generation.game\." components/AdminStockGenerationBatches.vue && grep -n "pusher:subscribe\|/admin/central/realtime/auth" composables/useAdminRealtime.ts'
```

Results:

```text
lint passed
test passed
Nuxt build passed
stock summary widget check passed
5-second polling removal/realtime wiring evidence passed
```

Nuxt still emits the existing Node/Nuxt `fs.Stats constructor is deprecated` warning. It did not fail validation.

## Manual / Browser Evidence

Dev server smoke:

```sh
docker compose -p newpaotang up -d back-office
curl -sS -D - http://127.0.0.1:3100/admin/central/stock-generation -o /tmp/bo-realtime-stock-generation.html
docker compose -p newpaotang stop back-office
```

Result after Nuxt warmed:

```text
HTTP/1.1 302 Found
location: /login?redirect=/admin/central/stock-generation
```

Codex in-app browser smoke:

```text
Opened http://127.0.0.1:3100/admin/central/stock-generation
Resolved to /login?redirect=/admin/central/stock-generation
Rendered title: NewPaotang Back Office
Rendered login form with email, password, scope, tenant id, and Sign in button
```

Authenticated websocket runtime was not exercised because this thread does not have admin credentials and the local compose stack does not run a Reverb websocket server; backend handoff states local/dev broadcasting defaults to the `log` broadcaster and production websocket delivery remains an ops blocker.

## Known Risks / Blockers

- Production websocket delivery still depends on the backend/ops Reverb readiness blocker documented by Backend Develop.
- Without `NUXT_PUBLIC_ADMIN_REALTIME_URL` or `VITE_ADMIN_REALTIME_URL`, BO intentionally shows fallback mode and uses low-frequency REST fallback only while active batches exist.
- Full authenticated realtime event smoke must be done by QA in an environment with admin credentials and a websocket runtime.

## Unrelated Dirty Files

None at the implementation commit.

## Next Recommended Agent

Orchestrator should pick up this BO handoff, dispatch the QA task, then QA should verify integrated backend + BO realtime progress and prove `generation-batches` is no longer called every 5 seconds.
