# Back Office P4 Administration Security Settings Remediation QA Review Decision

Date: 2026-05-11
Owner: Coordinator
Task: `back-office-p4-administration-security-settings-workflows-remediation`

## Decision

Coordinator accepts the focused remediation QA result as a partial pass.

`central:menu_management` is promoted to `complete` because QA verified the real central menu workflow with pre-save confirmation, cancel-without-submit, safe confirm save, restore, and API round-trip evidence.

`tenant:menu_management` and `tenant:maintenance` remain held. QA did not find a confirmed BO implementation defect for those rows, but tenant browser evidence was incomplete, and tenant maintenance still has a backend residual: direct API bypass creation accepts missing `ticket_id`.

Official BO completion is now 27/56 menus, or 48.2%.

## Evidence Reviewed

- QA report: `ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md`
- QA artifacts: `ai-agents/reports/artifacts/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa/`
- BO handoff: `ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md`
- Orchestrator QA handoff: `ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-task-orchestrator-handoff.md`
- QA head under test: `fda9dfc97ca11403a6bdbd755f46b9ceeb510a42`
- Implementation commit: `c38aa7cd6811f2c555eedbf166eeced368afd059`
- BO handoff commit: `f9d79d5b4afc327516cf1a17f4d23c567a298437`

## Row Promoted To Complete

- `central:menu_management`

QA verified:

- Real authenticated central menu link was used.
- Confirmation appeared before any PUT write.
- Confirmation showed `Central`, reason, menu item count, changed item count, changed item identity, and label field context.
- Cancel kept PUT count at zero.
- Confirm save persisted the changed label.
- Restore persisted and returned the label to the original value.

## Rows Held

- `tenant:menu_management`
- `tenant:maintenance`

`tenant:menu_management` hold reason:

- API reversible save passed with `X-Tenant-Id: ten_demo_alpha`.
- Source/shared component review shows the same confirmation path.
- Real authenticated tenant browser modal/cancel/confirm/restore evidence was incomplete due browser runtime blockers.

`tenant:maintenance` hold reason:

- API ticketed create/list/revoke passed.
- Source review shows UI reason/ticket guard.
- Tenant browser missing-ticket evidence was incomplete due browser runtime blockers.
- Direct API `POST /admin/tenant/maintenance/bypasses` still accepted missing `ticket_id` and returned `201`.

## Backend Freeze Exception

Coordinator opens a narrow backend exception for tenant maintenance bypass validation.

Required backend behavior:

- `POST /admin/tenant/maintenance/bypasses` must reject missing or blank `ticket_id`.
- Existing successful ticketed create, list, revoke, tenant scope, and reason/idempotency behavior must be preserved.

No other backend scope is reopened.

## BO Coverage Update

Updated coverage totals:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 16 | 7 | 1 | 24 |
| Tenant | 11 | 20 | 1 | 32 |
| Total | 27 | 27 | 2 | 56 |

Remaining rows:

- 27 partial menus
- 2 API-gap menus: `central:master_stock`, `tenant:commission_transactions`

## Next Direction

Route follow-up to Orchestrator:

```text
back-office-p4-tenant-menu-maintenance-ticket-validation-closure
```

Expected owners:

- Backend Develop for the narrow tenant maintenance `ticket_id` validation exception.
- QA Tester for focused tenant evidence after backend validation lands.

Focused QA after remediation should cover:

- `tenant:menu_management`: real tenant browser modal, cancel-without-submit, confirm save, restore, and `X-Tenant-Id` scope.
- `tenant:maintenance`: missing-ticket rejection at API level, UI missing-ticket guard, ticketed create/list/revoke cleanup, and tenant scope.

Customer frontend remains frozen.
