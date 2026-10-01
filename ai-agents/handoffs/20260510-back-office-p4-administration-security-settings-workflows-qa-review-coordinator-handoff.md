# Coordinator Handoff - Back Office P4 Administration Security Settings QA Review

Date: 2026-05-10
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p4-administration-security-settings-workflows`
Next Task: `back-office-p4-administration-security-settings-workflows-remediation`

## Summary

QA returned FAIL with two P2 findings. Coordinator does not promote any P4 row in this review.

Official BO completion remains 26/56 menus, or 46.4%.

## Decision

See:

```text
ai-agents/decisions/20260510-back-office-p4-administration-security-settings-workflows-qa-review-decision.md
```

## Required Remediation

### Tenant Maintenance

Affected row:

```text
tenant:maintenance
```

Fix:

```text
Require ticket ID before tenant maintenance bypass create submission.
Preserve reason guard, operator context, bypass list/events/revoke behavior, and tenant scope.
```

### Menu Management

Affected rows:

```text
central:menu_management
tenant:menu_management
```

Fix:

```text
Add confirmation before saving the menu tree.
Confirmation must show scope and changed-item context.
Preserve reason guard, reset behavior, editable fields, and central/tenant scope.
```

## Next Instruction For Orchestrator

Open remediation task:

```text
back-office-p4-administration-security-settings-workflows-remediation
```

Expected owner:

```text
BO Develop
```

Expected follow-up:

```text
QA Tester focused retest for central:menu_management, tenant:menu_management, and tenant:maintenance only.
```

## Guardrails

- Backend remains frozen unless Coordinator explicitly approves API validation work.
- Customer frontend remains frozen.
- Do not promote P4 rows until focused QA passes real menu workflows.
- Keep Orchestrator in the chain; Coordinator does not create the BO/QA task directly.

## Next Agent

```text
Orchestrator
```
