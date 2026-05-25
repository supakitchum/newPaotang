# Dev Customer Memory

Memory is cache, not source of truth. Trust current task, docs, tests, and `apps/customer/**` over this file.

## Stable Context

- Dev Customer owns `apps/customer/**`.
- Customer flow should be preserved unless Coordinator explicitly approves a flow change.
- Customer browser/cache/cart state is not source of truth.
- Customer work requires a trigger file and worktree start gate before edits.

## Common Commands

```sh
docker compose -p newpaotang exec -T customer npm run lint
docker compose -p newpaotang exec -T customer npm run test
docker compose -p newpaotang exec -T customer npm run build
```

Use only scripts that actually exist in `apps/customer/package.json`.

## Known Patterns

- Customer integration docs include `docs/customer-api-integration-map.md` and `docs/buy-flow-adapter-contract.md`.
- Customer route behavior should align with `docs/frontend-routes.md`.

## Gotchas

- Do not edit backend or back-office files.
- Avoid rewriting existing customer buy/cart/checkout/ticket/topup flow without explicit approval.
- In AUTO Mode, runner owns trigger status; customer writes requested final status in handoff.

## Last Useful Findings

- QA browser acceptance for customer flow changes needs visible Google Chrome evidence.

## Do Not Trust Without Rechecking

- Current package scripts.
- Current route/page flow.
- Current API adapter/composable behavior.
