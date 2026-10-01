# M10 Admin Security Idempotency Conflict Remediation Approval And Git Cleanup Decision

Date: 2026-05-09
Agent: Coordinator

## Context

Coordinator reviewed QA for:

```text
20260509-m10-admin-security-idempotency-conflict-remediation
```

QA report:

```text
ai-agents/reports/20260509-m10-admin-security-idempotency-conflict-remediation-qa-report.md
```

QA verdict:

```text
PASS - Coordinator review required
```

The user then explicitly instructed Coordinator:

```text
QA Test is done
clear the worktree
jump the queue and do git first
write a new rule that code-writing agents must commit their completed work to keep the worktree clean
```

## Decision

Approve the targeted idempotency conflict remediation as locally validated and interrupt the normal next-agent flow to perform git cleanup first.

This decision also adds the new Code Agent Commit Rule to the agent rules and stage gates.

## Approved Remediation

The approval covers:

```text
same Idempotency-Key plus same request meaning replays safely
same Idempotency-Key plus changed reset token/password/current-password/TOTP input returns idempotency_conflict
conflict occurs before a second password, 2FA, recovery-code, or session mutation
deterministic non-raw HMAC fingerprints are used for sensitive inputs
raw sensitive test values were not found in persisted idempotency response bodies or redacted audit payload checks
OpenAPI route parity remains 279 OpenAPI routes / 279 app routes / 0 missing / 0 undocumented
full backend Docker suite passed
platform smoke passed after Docker reseed
```

## New Rule

Code-writing agents must commit their own task scope after implementation and task validation pass.

Updated files:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
```

Rule intent:

```text
keep the worktree clean between tasks
make each code task auditable by commit
avoid giant mixed commits from multiple agents
prevent unrelated dirty files from leaking into another agent's commit
```

## Git Cleanup Scope

Because the workspace already contains accumulated multi-agent work, Coordinator is allowed for this interruption to create one consolidation commit that stages the current repository state.

This is an explicit user override to clean the worktree before continuing M10.

## Still Not Approved

This does not approve:

```text
staging
production
client delivery
external secret management
production mail delivery
LINE production readiness
Cloudflare/R2 production readiness
old-data migration
cutover
rollback
final M10 release
moving to a new milestone
```

M10 external blockers remain carried forward.

## Next Agent

Coordinator
