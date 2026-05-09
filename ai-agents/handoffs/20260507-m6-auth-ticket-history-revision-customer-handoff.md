# 20260507 M6 Auth Ticket History Revision - Customer Handoff

## What Was Done

- Closed the customer auth lifecycle QA gap by adding adapter/composable coverage for:
  - `GET /customer/auth/me`
  - `POST /customer/auth/refresh`
  - `POST /customer/auth/logout`
- Added refresh-token state support in `useAuth` without adding an automatic retry loop.
- Added `restoreAuthState()` so token-backed customer pages can restore user profile state through `auth/me`.
- Added `logout()` so server logout is attempted before local auth state is cleared, with local state cleared in `finally`.
- Updated login to persist the full auth session through `setAuthSession()`.
- Updated profile and private-route init flow to use safe `auth/me` restoration.
- Closed the ticket-history reachability gap by making `/tickets/history` fetch history directly through `fetchTickets({ history: true })`.
- Updated ticket composables so explicit history requests call `/customer/tickets/history`, preserve cursor pagination, and treat missing game metadata as optional.

## Files Changed

- `apps/customer/composables/usePlatformApi.ts`
- `apps/customer/composables/useAuth.ts`
- `apps/customer/composables/useUserTickets.ts`
- `apps/customer/pages/tickets/history.vue`
- `apps/customer/pages/login.vue`
- `apps/customer/pages/profile.vue`
- `apps/customer/middleware/init.global.ts`
- `ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md`

## Validation

Passed:

```sh
docker compose run --rm customer npm run build
```

Notes:

- No host Node/npm/Nuxt commands were run.
- `npm ci` was not required because the Docker build succeeded with existing container dependencies.

## D1/P2 Closure Evidence

- `usePlatformApi.ts` now exposes:
  - `me()` -> `GET /customer/auth/me`
  - `refresh(refreshToken)` -> `POST /customer/auth/refresh` with `{ refresh_token }`
  - `logout()` -> `POST /customer/auth/logout`
- `logout()` sends `Idempotency-Key` using the existing `idempotencyHeaders('customer-auth-logout')` helper.
- `useAuth.ts` now exposes:
  - `restoreAuthState()`, which calls `platformApi.me()` and updates local user state.
  - `refreshAuthToken()`, which only calls refresh when a stored refresh token exists.
  - `logout()`, which calls backend logout when a token exists and always clears local token, refresh token, and user state in `finally`.
- `login.vue` now stores token/user/refresh material through `setAuthSession()`.
- `profile.vue` and `middleware/init.global.ts` now use `restoreAuthState()` for token-backed user restoration.
- No automatic refresh loop was added; refresh remains explicit and no-ops safely when refresh-token material is missing.

## D2/P2 Closure Evidence

- `useUserTickets.ts` now supports an explicit `history?: boolean` option.
- `fetchTickets({ history: true })` calls `platformApi.ticketsLegacy({ history: true, ... })`.
- `usePlatformApi.ts` routes `history: true` to `GET /customer/tickets/history`.
- `pages/tickets/history.vue` now calls `fetchHistoryPage()` on mount, and `fetchHistoryPage()` calls `fetchTickets({ history: true, page, perPage })`.
- The mounted history flow no longer depends on `currentResponse.games[1]` or any active ticket game array shape before reaching the history endpoint.
- History pagination continues to use the adapter cursor metadata.
- Missing game metadata is allowed; the history page keeps its empty state usable.

## Known Risks

- No live browser/API smoke test was run; validation was limited to the required Docker Nuxt build.
- Backend history responses currently expose ticket data and cursor metadata, not a historical game object. The UI therefore treats game metadata as optional and relies on ticket-level fields where available.

## Questions For Coordinator

- None.

## Next Agent

Orchestrator
