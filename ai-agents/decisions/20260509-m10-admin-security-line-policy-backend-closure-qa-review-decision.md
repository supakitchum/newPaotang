# M10 Admin Security LINE Policy Backend Closure QA Review Decision

Date: 2026-05-09
Agent: Coordinator

## Context

Coordinator reviewed QA for:

```text
20260509-m10-admin-security-line-policy-backend-closure
```

Reviewed files:

```text
ai-agents/tasks/20260509-m10-admin-security-line-policy-backend-closure-backend.md
ai-agents/tasks/20260509-m10-admin-security-line-policy-backend-closure-qa.md
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-qa-task-orchestrator-handoff.md
ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php
apps/platform-api/app/Shared/Idempotency/IdempotencyService.php
```

QA verdict:

```text
FAIL - Coordinator review required
```

## Decision

Do not approve the admin security and LINE backend closure slice yet.

Route a focused remediation for the P1 idempotency conflict defect found by QA.

## Blocking Finding

QA found that security-sensitive write routes use reduced normalized idempotency payloads that omit deterministic fingerprints of changed sensitive request fields.

Affected routes:

```text
POST /auth/admin/password/reset
POST /auth/admin/password/change
POST /auth/admin/2fa/enable
POST /auth/admin/2fa/recovery-codes
DELETE /auth/admin/2fa
```

Affected implementation area:

```text
apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php
```

Current risk:

```text
Reusing the same Idempotency-Key with different password/current_password/new_password/code inputs can replay the previous success response instead of returning idempotency_conflict.
```

This violates the security route acceptance criteria for idempotency and replay protection.

## Required Remediation

Open a targeted backend-only remediation:

```text
20260509-m10-admin-security-idempotency-conflict-remediation
```

Backend Develop must:

```text
1. Update the normalized idempotency payloads for all affected routes to include deterministic fingerprints of every security-sensitive request input that changes request meaning.
2. Never store raw passwords, TOTP codes, recovery codes, reset tokens, challenge tokens, or provider credentials in idempotency payloads, logs, audit payloads, or responses.
3. Use deterministic non-reversible fingerprints, such as HMAC/hash values using an application secret/salt, so conflict detection can distinguish changed inputs without leaking raw secrets.
4. Keep existing replay behavior for exact same idempotency key plus exact same request meaning.
5. Return idempotency_conflict for same idempotency key with changed sensitive input.
6. Ensure no additional mutation occurs on idempotency_conflict.
7. Add or update focused tests covering same-key/different-sensitive-input conflicts for every affected route group.
8. Keep OpenAPI route parity at 279 OpenAPI routes / 279 app routes / 0 missing / 0 undocumented.
9. Do not edit apps/back-office/** or apps/customer/**.
10. Do not claim staging, production, final M10, or Gate 5.
```

Recommended sensitive fingerprints:

```text
password reset: token fingerprint, new password fingerprint, password confirmation fingerprint, policy version
password change: admin user id, current password fingerprint, new password fingerprint, confirmation fingerprint, policy version
2FA enable: admin user id, TOTP code fingerprint, action
2FA recovery-code rotation: admin user id, current password fingerprint, TOTP code fingerprint, action
2FA disable: admin user id, current password fingerprint, TOTP code fingerprint, action
```

The exact implementation can differ if it preserves the same security properties.

## Required Validation

All runtime/test commands must use Docker only.

Required focused validation:

```text
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan platform:smoke
```

QA must verify:

```text
same Idempotency-Key + same sensitive payload replays safely
same Idempotency-Key + changed password/current-password/TOTP code returns idempotency_conflict
idempotency_conflict causes no second mutation
stored idempotency payload/hash and audit logs do not contain raw sensitive values
all 279 app routes remain registered with 0 undocumented routes
BO/customer frontend files remain untouched
```

## Git Boundary

Gate 5 is not triggered.

The project remains inside M10 and this failing QA blocks backend completion approval. Before moving to a new milestone or post-M10 phase after final backend/M10 approval, Coordinator must stop and perform git status, stage, commit, and push.

## Next Agent

Orchestrator
