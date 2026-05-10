# Back Office P4 Administration Security Settings Workflows QA Review Decision

Date: 2026-05-10
Owner: Coordinator
Task: `back-office-p4-administration-security-settings-workflows`

## Decision

Coordinator accepts the QA result as FAIL.

No P4 rows are promoted to `complete` in this review. Official BO completion remains 26/56 menus, or 46.4%.

## Evidence Reviewed

- QA report: `ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md`
- QA artifacts: `ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/`
- BO handoff: `ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md`
- Orchestrator QA handoff: `ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-qa-task-orchestrator-handoff.md`
- QA head under test: `1842cdb00a77dcf7419bdcea44738df4383d76e0`
- Implementation commit: `52e0f728594bdeda4ae0c6262c22c3cae8698a40`
- BO handoff commit: `da664c6d59241165adc148765a5e1a218b5a6624`

## Blocking Findings

### P2: Tenant maintenance bypass can be created without ticket ID

Affected row:

- `tenant:maintenance`

QA found that the bypass create UI exposes `Ticket ID`, but submit is only guarded by tenant ID and reason. QA also confirmed the backend accepted `POST /admin/tenant/maintenance/bypasses` with `ticket_id: null` and cleaned up the created bypass.

Expected remediation:

- BO must require ticket ID before bypass create submission.
- Bypass create should keep the existing reason requirement and operator context.
- If BO Develop believes API-level validation is required, route that back to Coordinator instead of editing backend under the frozen-backend rule.

### P2: Menu tree save lacks confirmation/context step

Affected rows:

- `central:menu_management`
- `tenant:menu_management`

QA found that `AdminMenuTreeEditor` submits the full menu tree directly after a reason is typed. It lacks the required confirmation modal showing scope and changed-item context before writing the menu tree.

Expected remediation:

- Add a confirmation step before menu tree save for both central and tenant scopes.
- Confirmation must show scope and changed-item context.
- Preserve the required reason guard, reset workflow, current editable fields, and central/tenant scope behavior.

## BO Coverage Update

Coverage remains unchanged:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 15 | 8 | 1 | 24 |
| Tenant | 11 | 20 | 1 | 32 |
| Total | 26 | 28 | 2 | 56 |

## Next Direction

Route remediation to Orchestrator:

```text
back-office-p4-administration-security-settings-workflows-remediation
```

Expected owner: BO Develop.

After BO remediation, Orchestrator should route focused QA for the three affected rows only:

- `central:menu_management`
- `tenant:menu_management`
- `tenant:maintenance`

Backend and customer frontend remain frozen unless Coordinator explicitly changes that decision.
