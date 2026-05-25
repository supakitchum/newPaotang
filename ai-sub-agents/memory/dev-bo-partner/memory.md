# Dev BO Partner Memory

Memory is cache, not source of truth. Trust current task, docs, tests, and `apps/back-office/**` over this file.

## Stable Context

- Dev BO Partner owns partner/tenant back-office UI work in `apps/back-office/**`.
- Tenant isolation must be preserved in UI flow and API calls.
- Shared BO components can be changed only when the task explicitly assigns a shared change.
- Shared BO file changes require an Orchestrator-approved lock before edits.

## Common Commands

```sh
docker compose -p newpaotang exec -T back-office npm run lint
docker compose -p newpaotang exec -T back-office npm run test
docker compose -p newpaotang exec -T back-office npm run build
```

Use only scripts that actually exist in `apps/back-office/package.json`.

## Known Patterns

- Partner/tenant BO work must avoid central-only workflow regressions.
- Back-office UI should follow `docs/admin-dashboard-template-guidelines.md`.

## Gotchas

- `apps/back-office/**` is shared with Dev BO Central; inspect component usage before editing.
- Do not hardcode tenant IDs, domains, or permission behavior.
- In AUTO Mode, runner owns trigger status; partner BO writes requested final status in handoff.
- Do not send partner BO handoff until requested status and any shared lock release status are recorded.

## Last Useful Findings

- QA browser acceptance for partner/tenant BO changes needs visible Google Chrome evidence.

## Do Not Trust Without Rechecking

- Current package scripts.
- Current partner/tenant route names and permission keys.
- Whether a component is also used by central pages.
