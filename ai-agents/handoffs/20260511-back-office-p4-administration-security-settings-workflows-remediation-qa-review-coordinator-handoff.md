# Coordinator Handoff - Back Office P4 Administration Security Settings Remediation QA Review

Date: 2026-05-11
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p4-administration-security-settings-workflows-remediation`
Next Task: `back-office-p4-tenant-menu-maintenance-ticket-validation-closure`

## Summary

QA returned a partial pass. Coordinator promotes `central:menu_management` to complete and holds `tenant:menu_management` plus `tenant:maintenance`.

Official BO completion is now 27/56 menus, or 48.2%.

## Decision

See:

```text
ai-agents/decisions/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-decision.md
```

## Accepted Complete Row

```text
central:menu_management
```

## Held Rows

```text
tenant:menu_management
tenant:maintenance
```

## Next Instruction For Orchestrator

Open follow-up task:

```text
back-office-p4-tenant-menu-maintenance-ticket-validation-closure
```

Expected split:

```text
Backend Develop: narrow tenant maintenance bypass ticket_id validation exception.
QA Tester: focused tenant evidence after backend validation lands.
```

## Backend Exception Scope

Coordinator approves only this backend exception:

```text
POST /admin/tenant/maintenance/bypasses must reject missing or blank ticket_id.
```

Preserve:

```text
successful ticketed bypass create
bypass list/revoke
tenant scope and X-Tenant-Id behavior
reason and idempotency behavior
existing BO UI guard
```

No other backend scope is reopened.

## Focused QA Requirements

After backend remediation, QA must verify:

```text
tenant:menu_management real tenant browser modal/cancel/confirm/restore
tenant:menu_management tenant scope and X-Tenant-Id
tenant:maintenance API rejects missing ticket_id
tenant:maintenance UI missing-ticket guard remains present
tenant:maintenance ticketed create/list/revoke cleanup still passes
```

## Guardrails

- Customer frontend remains frozen.
- Do not promote `tenant:menu_management` or `tenant:maintenance` until focused QA passes.
- Keep Orchestrator in the chain; Coordinator does not create Backend/BO/QA tasks directly.

## Next Agent

```text
Orchestrator
```
