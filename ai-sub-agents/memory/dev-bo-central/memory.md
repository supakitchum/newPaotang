# Dev BO Central Memory

Memory is cache, not source of truth. Trust current task, docs, tests, and `apps/back-office/**` over this file.

## Stable Context

- Dev BO Central owns central back-office UI work in `apps/back-office/**`.
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

- Back-office UI should follow `docs/admin-dashboard-template-guidelines.md`.
- Menu visibility is not backend authorization.
- Central UI must not accidentally alter partner/tenant-only workflows.

## Gotchas

- `apps/back-office/**` is shared with Dev BO Partner; inspect routes/components before editing.
- Do not hardcode permission behavior without checking source-of-truth docs and API behavior.
- In AUTO Mode, runner owns trigger status; central BO writes requested final status in handoff.
- Do not send central BO handoff until requested status and any shared lock release status are recorded.

## Last Useful Findings

- QA browser acceptance for BO changes needs visible Google Chrome evidence.

## Do Not Trust Without Rechecking

- Current package scripts.
- Current central route names and permission keys.
- Whether a component is shared with partner/tenant pages.
