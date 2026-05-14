# 20260514 QA Runtime Restore Login Smoke Rule Decision

## Decision

APPROVED

Coordinator adds a mandatory QA runtime restore and login smoke rule for every QA task that touches local Docker runtime, database state, migrations, seeders, feature tests, browser sessions, or back-office build/dev server state.

## Reason

Recent QA runs left the shared local Docker runtime with empty auth/RBAC seed data or stale Nuxt dev-server state. The visible symptom was repeated inability to sign in after QA completed, even when implementation code had already passed.

This is a QA process defect, not a product acceptance state. QA must leave the local runtime usable after validation.

## Rule Summary

QA Tester must not submit a clean PASS until the local runtime restore checklist is complete:

- Run database seed after destructive or database-touching tests.
- Run `platform:smoke` and confirm `seeded-logins: ok`.
- Verify seeded central admin login API returns 200.
- Restart or recreate `back-office` after BO build/browser/dev-server QA.
- Verify `/login` returns 200.
- Verify `/admin/login` redirects to `/login` and does not preserve `redirect=/admin/login`.

If any required check fails, QA must report FAIL or PASS WITH RISK and send the blocker to Coordinator.

## Files Updated

- `ai-agents/rules/global-rules.md`
- `ai-agents/roles/qa-tester.md`
- `ai-agents/workflow/handoff-protocol.md`

## Next Agent

Orchestrator

Orchestrator must include this runtime restore/login smoke requirement in future QA task briefs.
