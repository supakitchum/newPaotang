# m6-auth-ticket-history-revision - Customer Develop

## Target Agent

Customer Develop

## Coordinator Instruction

M6 Customer API Integration is not approved yet. QA reported a conditional pass with two acceptance-relevant P2 defects:

```text
D1/P2 - Auth lifecycle integration omits server me/refresh/logout.
D2/P2 - Ticket history page never reaches GET /customer/tickets/history from its mounted flow.
```

Create one focused Customer Develop revision to close only these two defects.

This task is authorized by:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md
ai-agents/handoffs/20260507-m6-customer-api-integration-qa-review-coordinator-handoff.md
ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
ai-agents/tasks/20260507-m6-customer-api-integration-customer.md
ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
```

Keep this revision focused. Do not expand into backend, back-office, framework upgrade, checkout multi-reservation behavior, reward engine behavior, or UI redesign work.

## Objective

Close the two QA defects blocking M6 approval:

```text
1. Add customer auth lifecycle coverage for GET /customer/auth/me, POST /customer/auth/refresh, and POST /customer/auth/logout through the existing adapter/composable boundary.
2. Make /tickets/history call GET /customer/tickets/history directly in its history flow and map returned tickets/cursor metadata safely.
```

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- docs/customer-api-integration-map.md
- docs/buy-flow-adapter-contract.md
- docs/frontend-routes.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
- ai-agents/tasks/20260507-m6-customer-api-integration-customer.md
- ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
- ai-agents/tasks/20260507-m6-customer-api-integration-qa.md
- ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
- ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md
- ai-agents/handoffs/20260507-m6-customer-api-integration-qa-review-coordinator-handoff.md
- apps/customer/AI_PROJECT_CONTEXT.md
- apps/customer/package.json

## Scope

Approved revision scope:

```text
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useAuth.ts
apps/customer/composables/useUserTickets.ts
apps/customer/pages/tickets/history.vue
apps/customer/pages/login.vue only if required for auth state restoration
apps/customer/pages/profile.vue only if required for auth me/profile behavior
apps/customer/middleware/init.global.ts only if required for session bootstrap
apps/customer/plugins/axios.ts only if required for safe refresh/logout behavior
```

Required auth lifecycle fixes:

- Add adapter/composable methods for `GET /customer/auth/me`, `POST /customer/auth/refresh`, and `POST /customer/auth/logout`.
- Wire logout to call `POST /customer/auth/logout` with `Idempotency-Key` before local auth clear.
- Clear local auth state after logout even if the backend session is already invalid or returns `401`.
- Expose or use `auth/me` for token-backed auth state restoration where appropriate.
- Expose refresh behavior only if current customer auth state has enough refresh-token material.
- Do not invent an insecure refresh loop.
- Keep token, refresh, me, and logout behavior behind `usePlatformApi`/`useAuth` boundaries.
- Do not add raw page-level auth lifecycle API calls.
- Preserve existing auth redirects and current alert/error behavior.

Required ticket history fixes:

- Update `/tickets/history` so the mounted history page reaches `GET /customer/tickets/history` directly.
- Map returned tickets and cursor/pagination metadata through existing adapter/composable methods.
- Treat game metadata as optional display fallback until backend provides richer historical draw grouping.
- Keep the page usable with an empty state when there are no historical tickets.

## Out Of Scope

- Do not edit `apps/platform-api`.
- Do not edit `apps/back-office`.
- Do not change `docs/openapi.yaml` or backend source-of-truth docs.
- Do not change `document/**`.
- Do not upgrade Nuxt or package framework versions.
- Do not redesign customer UI.
- Do not change checkout multi-reservation behavior in this revision.
- Do not implement M7 reward engine behavior.
- Do not implement new backend endpoints or change backend contracts.
- Do not broaden this revision into unrelated M6 cleanup.

## File Ownership

Can edit:

```text
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useAuth.ts
apps/customer/composables/useUserTickets.ts
apps/customer/pages/tickets/history.vue
apps/customer/pages/login.vue
apps/customer/pages/profile.vue
apps/customer/middleware/init.global.ts
apps/customer/plugins/axios.ts
```

Only edit `login.vue`, `profile.vue`, `init.global.ts`, or `plugins/axios.ts` if required for the approved auth lifecycle fixes. Keep changes narrowly scoped.

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Customer Develop may write only its required handoff under `ai-agents/handoffs/**`.

If closing D1/P2 or D2/P2 requires backend/API contract, package upgrade, checkout behavior, reward engine behavior, or UI redesign changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read the QA report defects D1/P2 and D2/P2 and the Coordinator QA review decision before editing.
3. Inspect current `usePlatformApi`, `useAuth`, `useUserTickets`, `/tickets/history`, auth-related pages, init middleware, and axios plugin as needed.
4. Confirm `apps/customer/package.json` still has Nuxt `3.11.2` and build script only among validation-relevant scripts.
5. Add `auth/me`, `auth/refresh`, and `auth/logout` coverage through adapter/composable boundaries.
6. Ensure logout sends `Idempotency-Key` before local auth clear and still clears local auth state when server logout returns `401` or already-invalid-session behavior.
7. Use `auth/me` for safe token-backed auth state restoration where current state makes that appropriate.
8. Add refresh behavior only if existing customer auth state has refresh-token material; otherwise expose a safe no-op/unsupported path and document why no refresh loop was added.
9. Preserve existing redirects, local token state behavior, and alert/error behavior.
10. Update `/tickets/history` so its mounted flow calls `GET /customer/tickets/history` directly through the adapter/composable boundary.
11. Map history tickets and cursor/pagination metadata safely, with optional game metadata fallback.
12. Keep empty history state usable.
13. Avoid raw page-level Platform API calls.
14. Avoid any out-of-scope file changes.
15. Run validation commands through Docker only.
16. Write the required Customer Develop handoff.

## Acceptance Criteria

- D1/P2 is closed: `auth/me`, `auth/refresh`, and `auth/logout` are reachable through adapter/composable methods.
- Logout calls `POST /customer/auth/logout` with `Idempotency-Key`.
- Local auth state is cleared after logout even when backend logout is already invalid or returns `401`.
- Refresh behavior is safe and does not invent an insecure refresh loop.
- Existing login/register/profile/auth redirect/error behavior is preserved.
- D2/P2 is closed: `/tickets/history` directly reaches `GET /customer/tickets/history` from its mounted history flow.
- Ticket history maps returned tickets and cursor/pagination metadata through adapter/composable methods.
- Ticket history treats missing game metadata as optional fallback and remains usable with an empty state.
- No raw page-level auth lifecycle or ticket history Platform API calls are added.
- No `apps/platform-api`, `apps/back-office`, docs, decisions, tasks, reports, or Board changes are made.
- Docker customer build passes.
- Customer Develop writes a handoff to `ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm customer npm run build
```

If the Docker customer dependency volume is empty and the build fails only because `nuxt` or installed packages are missing, dependency install may be run through Docker only, then rerun the build and document both results:

```sh
docker compose run --rm customer npm ci
docker compose run --rm customer npm run build
```

Customer Develop must also document evidence that:

```text
auth/me, auth/refresh, and auth/logout are reachable through adapter/composable methods.
logout sends Idempotency-Key.
/tickets/history reaches GET /customer/tickets/history without depending on active ticket game array shape.
No host Node/npm/Nuxt commands were run.
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md
```

Must include:

```text
what was done
files changed
validation
D1/P2 closure evidence
D2/P2 closure evidence
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: QA should receive a focused follow-up task only after Customer Develop produces a handoff.

