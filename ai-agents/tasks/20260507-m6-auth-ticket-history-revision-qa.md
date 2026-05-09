# m6-auth-ticket-history-revision - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Customer Develop completed the focused M6 revision for the two QA defects blocking M6 approval:

```text
D1/P2 - Auth lifecycle integration omits server me/refresh/logout.
D2/P2 - Ticket history page never reaches GET /customer/tickets/history from its mounted flow.
```

Validate the revision against the Coordinator QA review decision, the focused Customer Develop revision task, the Customer Develop handoff, the original M6 QA report, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md
ai-agents/handoffs/20260507-m6-customer-api-integration-qa-review-coordinator-handoff.md
ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md
ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md
ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
```

## Objective

Validate that Customer Develop closed D1/P2 and D2/P2 without expanding scope:

```text
1. GET /customer/auth/me, POST /customer/auth/refresh, and POST /customer/auth/logout are reachable through adapter/composable boundaries, with logout idempotency and safe local cleanup behavior.
2. /tickets/history directly reaches GET /customer/tickets/history from its mounted history flow and maps tickets plus cursor metadata safely.
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
- ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md
- ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md
- apps/customer/AI_PROJECT_CONTEXT.md
- apps/customer/package.json

## Scope

Validate only the focused D1/P2 and D2/P2 revision.

Inspect the approved revision files and related evidence:

```text
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useAuth.ts
apps/customer/composables/useUserTickets.ts
apps/customer/pages/tickets/history.vue
apps/customer/pages/login.vue
apps/customer/pages/profile.vue
apps/customer/middleware/init.global.ts
apps/customer/plugins/axios.ts
ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md
```

Validate D1/P2 closure:

- `usePlatformApi` exposes adapter methods for `GET /customer/auth/me`, `POST /customer/auth/refresh`, and `POST /customer/auth/logout`.
- `useAuth` exposes or uses safe auth lifecycle methods such as restore, refresh, session persistence, and logout without raw page-level lifecycle calls.
- Logout calls backend `POST /customer/auth/logout` with `Idempotency-Key` before local auth clear when a token exists.
- Local auth state is cleared after logout even when server logout returns `401` or the session is already invalid.
- Refresh behavior only runs when refresh-token material exists and does not introduce an automatic insecure refresh loop.
- Existing login/profile/private-route auth state restoration and redirects are preserved.

Validate D2/P2 closure:

- `/tickets/history` calls the history flow directly on mount.
- The history flow reaches `GET /customer/tickets/history` through `useUserTickets`/`usePlatformApi`.
- The history page no longer depends on `currentResponse.games[1]` or active ticket game array shape before requesting history.
- Returned tickets and cursor/pagination metadata are mapped safely.
- Missing game metadata is treated as optional fallback and empty history state remains usable.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates another follow-up implementation task.
- Do not edit `apps/customer/**`.
- Do not edit `apps/platform-api/**`.
- Do not create or edit `apps/back-office/**`.
- Do not alter docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not retest or redesign the full M6 customer UI beyond evidence needed for D1/P2 and D2/P2 closure.
- Do not change checkout multi-reservation behavior, M7 reward behavior, SEO page override behavior, LINE continuation behavior, backend code, package versions, or UI design.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/customer/**
apps/platform-api/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code or contract changes, record it in the QA report with severity, evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Customer Develop revision handoff against the focused revision task and Coordinator QA review decision.
4. Inspect `git status --short` and confirm whether the revision changed only approved files plus the Customer handoff.
5. Inspect `apps/customer/package.json` and confirm Nuxt/package framework versions were not upgraded.
6. Inspect `usePlatformApi` for `auth/me`, `auth/refresh`, and `auth/logout` adapter coverage.
7. Inspect `useAuth` for session persistence, restore, refresh, and logout behavior.
8. Verify logout uses backend logout with `Idempotency-Key` and clears local token, refresh token, and user state even if backend logout fails or returns `401`.
9. Verify refresh behavior requires stored refresh-token material and no automatic insecure refresh loop was added.
10. Inspect `login.vue`, `profile.vue`, `init.global.ts`, and `plugins/axios.ts` only as needed to confirm auth restoration/redirect/error behavior remains safe.
11. Inspect `useUserTickets` and `/tickets/history` to verify the mounted history flow calls `GET /customer/tickets/history` directly through adapter/composable methods.
12. Verify history tickets and cursor/pagination metadata are mapped safely and missing game metadata remains optional.
13. Verify no raw page-level auth lifecycle or ticket history Platform API calls were added.
14. Run all required validation commands through Docker only.
15. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m6-auth-ticket-history-revision-qa-report.md`.
- QA report states whether the focused revision passes, conditionally passes, or fails.
- QA report verifies D1/P2 is closed or identifies why it remains open.
- QA report verifies D2/P2 is closed or identifies why it remains open.
- QA report confirms Docker customer build result.
- QA report confirms no out-of-scope app, backend, back-office, source-of-truth doc, decision, task, handoff, or Board changes were made by QA.
- QA report confirms Customer Develop changes stayed within approved focused revision scope or lists scope drift defects.
- QA report confirms no Nuxt/package framework upgrade was made.
- QA report confirms auth lifecycle endpoints are reachable through adapter/composable boundaries.
- QA report confirms logout `Idempotency-Key` behavior and safe local cleanup behavior.
- QA report confirms refresh behavior is safe and does not invent an insecure refresh loop.
- QA report confirms `/tickets/history` reaches `GET /customer/tickets/history` without depending on active ticket game array shape.
- QA report confirms history cursor/pagination and optional game metadata fallback behavior.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm customer npm run build
```

If the Docker customer dependency volume is empty and the build fails only because `nuxt` or installed packages are missing, QA may run dependency install through Docker only, then rerun the build and record both results:

```sh
docker compose run --rm customer npm ci
docker compose run --rm customer npm run build
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
git diff --stat -- apps/customer/composables/usePlatformApi.ts apps/customer/composables/useAuth.ts apps/customer/composables/useUserTickets.ts apps/customer/pages/tickets/history.vue apps/customer/pages/login.vue apps/customer/pages/profile.vue apps/customer/middleware/init.global.ts apps/customer/plugins/axios.ts
rg -n "(auth/me|auth/refresh|auth/logout|Idempotency-Key|restoreAuthState|refreshAuthToken|setAuthSession|logout\\(|tickets/history|history: true|currentResponse\\.games)" apps/customer/composables apps/customer/pages/tickets/history.vue apps/customer/pages/login.vue apps/customer/pages/profile.vue apps/customer/middleware/init.global.ts apps/customer/plugins/axios.ts
sed -n '1,380p' apps/customer/composables/useAuth.ts
sed -n '1,760p' apps/customer/composables/usePlatformApi.ts
sed -n '1,360p' apps/customer/composables/useUserTickets.ts
sed -n '1,320p' apps/customer/pages/tickets/history.vue
sed -n '1,260p' apps/customer/pages/login.vue
sed -n '1,260p' apps/customer/pages/profile.vue
sed -n '1,220p' apps/customer/middleware/init.global.ts
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m6-auth-ticket-history-revision-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
D1/P2 closure assessment
auth adapter/composable findings
logout idempotency and local cleanup findings
refresh safety findings
auth restoration/regression findings
D2/P2 closure assessment
ticket history endpoint reachability findings
history cursor/pagination and metadata fallback findings
scope drift findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```

