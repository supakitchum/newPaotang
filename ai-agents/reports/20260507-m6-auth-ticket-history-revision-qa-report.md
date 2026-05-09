# QA Report: M6 Auth And Ticket History Revision

## Task

`20260507-m6-auth-ticket-history-revision-qa`

## Summary

Result: PASS

Customer Develop closed both focused M6 QA findings. The customer adapter now exposes `GET /customer/auth/me`, `POST /customer/auth/refresh`, and `POST /customer/auth/logout`; `useAuth` wraps restore, refresh, session persistence, and logout cleanup safely; and `/tickets/history` now reaches `GET /customer/tickets/history` directly from its mounted history flow. The customer Nuxt production build passes through Docker.

## Scope Reviewed

Focused only on the two previously reported M6 findings:

- D1/P2: Auth lifecycle integration omitted server `me`, `refresh`, and `logout`.
- D2/P2: Ticket history page did not reach `GET /customer/tickets/history`.

## Files Inspected

- `ai-agents/tasks/20260507-m6-auth-ticket-history-revision-qa.md`
- `ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md`
- `ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md`
- `ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md`
- `apps/customer/package.json`
- `apps/customer/composables/usePlatformApi.ts`
- `apps/customer/composables/useAuth.ts`
- `apps/customer/composables/useUserTickets.ts`
- `apps/customer/pages/tickets/history.vue`
- `apps/customer/pages/login.vue`
- `apps/customer/pages/profile.vue`
- `apps/customer/middleware/init.global.ts`
- `apps/customer/plugins/axios.ts`
- Related auth contract evidence in `docs/openapi.yaml` and `apps/platform-api/app/Shared/Auth/CustomerAuthService.php`

## Commands Run

All runtime/build validation was run through Docker only.

```sh
docker compose run --rm customer npm run build
```

Read-only evidence commands included `git status --short`, `rg`, `sed`, `nl -ba`, and `cat`.

## Validation Results

- `docker compose run --rm customer npm run build`: PASS
- Build output: Nuxt 3.11.2 with Nitro 2.9.6. Node printed the existing `DEP0180` deprecation warning, but the build completed successfully.
- `apps/customer/package.json` still pins `nuxt` to `3.11.2`; no framework upgrade was detected.
- QA did not edit app, backend, docs, decisions, tasks, handoffs, or Board files. QA only wrote this report.

## D1/P2 Closure

PASS.

Evidence:

- `apps/customer/composables/usePlatformApi.ts` now exposes:
  - `me()` -> `GET /customer/auth/me`
  - `refresh(refreshToken)` -> `POST /customer/auth/refresh` with `{ refresh_token }`
  - `logout()` -> `POST /customer/auth/logout`
- `logout()` sends `Idempotency-Key` via `idempotencyHeaders('customer-auth-logout')`.
- `apps/customer/composables/useAuth.ts` now persists access token, refresh token, and user through `setAuthSession()`.
- `restoreAuthState()` calls `platformApi.me()` when token exists and user state needs restoration.
- `refreshAuthToken()` returns early when no refresh token exists and does not introduce an automatic refresh loop.
- `logout()` calls backend logout when a token exists and clears token, refresh token, user state, and restore state in `finally`, so local auth is cleared even if backend logout fails or returns `401`.
- `apps/customer/pages/login.vue` now stores login responses through `setAuthSession()`.
- `apps/customer/pages/profile.vue` and `apps/customer/middleware/init.global.ts` use `restoreAuthState()` for profile/private-route restoration.
- `apps/customer/plugins/axios.ts` still owns `401` local clear and redirect behavior and does not call backend logout from the interceptor.

## D2/P2 Closure

PASS.

Evidence:

- `apps/customer/pages/tickets/history.vue` calls `fetchHistoryPage()` directly in `onMounted()`.
- `fetchHistoryPage()` calls `fetchTickets({ history: true, page, perPage })`.
- `apps/customer/composables/useUserTickets.ts` passes `history` through to `platformApi.ticketsLegacy()`.
- `apps/customer/composables/usePlatformApi.ts` maps `history: true` to `GET /customer/tickets/history`; active tickets still use `GET /customer/tickets`.
- The history page no longer depends on `currentResponse.games[1]` or active ticket game array shape before loading history.
- Pagination uses normalized cursor metadata (`next_cursor`/`seed`) and stores page cursors safely.
- Missing game metadata remains optional: `historyGame` can stay null, ticket draw fallback uses ticket fields, and the empty-history state remains usable.

## Residual Notes

- `apps/customer/pages/register.vue` still stores register responses with `setAuthToken()` plus `setAuthUser()` instead of `setAuthSession()`, so any backend `refresh_token` returned by register is not persisted from that page. This was not part of the focused D1/D2 closure criteria for login/profile/private-route restoration, and it does not reopen the two blocking findings, but Coordinator may want a later cleanup for full auth-session consistency.
- Previously accepted M6 non-blocking risks remain unchanged: multi-reservation checkout behavior, richer ticket-history game metadata, `/public/seo/page` page overrides, LINE order-continuation behavior, and existing npm audit findings.

## Recommendation

Recommend Coordinator approval for the focused M6 revision. Both prior QA findings are closed and the required Docker customer build passes.
