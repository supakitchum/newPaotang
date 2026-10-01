# Static Review Summary

Task: `20260509-m10-admin-security-idempotency-conflict-remediation`

## Scope

Reviewed the targeted remediation for the prior P1 idempotency conflict defect in `AdminAccountSecurityService`.

Affected routes:

```text
POST /auth/admin/password/reset
POST /auth/admin/password/change
POST /auth/admin/2fa/enable
POST /auth/admin/2fa/recovery-codes
DELETE /auth/admin/2fa
```

## Findings

- Password reset idempotency now uses deterministic HMAC fingerprints for reset token, password, and password confirmation.
- Password change idempotency now uses deterministic HMAC fingerprints for current password, new password, and confirmation.
- 2FA enable/recovery/disable idempotency now uses deterministic HMAC fingerprints for TOTP code and, where required, current password.
- Fingerprint purpose strings are field-specific, reducing cross-field/cross-route correlation.
- The idempotency table stores only payload hashes and redacted response bodies, not raw normalized payload values.
- 2FA audit payloads remap raw `code` to a secret-classified key so existing audit redaction covers it.
- Focused tests now prove same-key exact replay, same-key changed sensitive input conflict, no second mutation, and no raw sensitive values in persisted idempotency response/audit payloads.

## Route Parity

Static route parity was recomputed:

```text
OPENAPI_ROUTES=279
APP_ROUTES=279
MISSING_IN_APP=0
UNDOCUMENTED_IN_APP=0
```

## Artifact Hygiene

QA artifacts were checked for the fake sensitive test values used by the regression; none were found.

## Worktree Boundary

`git status` remains broadly noisy, including pre-existing `apps/customer/**`, `apps/back-office/**`, and an untracked `apps/platform-api/**` tree. QA only wrote this report and artifacts.
