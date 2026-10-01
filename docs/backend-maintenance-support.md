# Backend Maintenance And Support Access

## Scope

Milestone 9 adds tenant-scoped backend support for:

```text
maintenance settings/events/bypasses
support access requests and approvals
short-lived support impersonation sessions
blocked sensitive support actions
audit log and sync_outbox evidence
```

The implementation is backend-only in `apps/platform-api`. Shared API contract files remain unchanged.

## Maintenance

`partner_tenant_maintenance_settings` is the admin source of truth. Existing `partner_tenant_settings` maintenance columns are still synchronized as compatibility fields for existing site-config and frontend consumers.

Blocking is tenant scoped. `GET /api/v1/public/site-config` remains readable and returns `maintenance.active=true` when active. Public/customer endpoints that are blocked return `maintenance_active` with HTTP 503 and `Retry-After` when configured.

Mode enforcement:

```text
full_site/customer_web_only: block public/customer read and write routes except site-config
checkout_payment_only: block reservations, checkout, and topup/payment write starts
read_only: allow reads, block customer writes and payment/checkout writes
scheduled: does not block unless status resolves to active
admin_only: backend records the mode; broad back-office route blocking is deferred so maintenance admin endpoints remain reachable
```

Maintenance writes require `Idempotency-Key`, `reason`, tenant RBAC, audit logging, a maintenance event row, and `maintenance.changed.v1` in `sync_outbox`.

Maintenance bypasses are tenant scoped. `GET /api/v1/admin/tenant/maintenance/bypasses` requires `maintenance.bypass`, supports `cursor`, `limit`, and `status=active|revoked|expired`, and returns safe metadata only. It does not expose bearer tokens, support impersonation tokens, customer secrets, raw credentials, or broad login bypass material.

## Support Access

Support access requests are tenant scoped and validate that targets belong to the selected tenant:

```text
customer targets must exist in customers.tenant_id
tenant_admin targets must have a tenant admin scope for the tenant
```

Approve, revoke, impersonate, elevated action, and end-session writes require `Idempotency-Key`, a reason, tenant RBAC, and audit evidence.

Support impersonation session tokens are returned only on initial issuance, stored as SHA-256 hashes, and excluded from detail/list and idempotency replay responses. Sessions are short-lived and can be ended or revoked.

Sensitive tenant admin actions are blocked when valid support impersonation headers are present:

```text
wallet_adjust
topup_approve
payout_approve
permission_change
role_change
delete_user
```

Blocked actions write `support_impersonation_blocked_actions`, `support_impersonation_events`, `audit_logs`, and `support_impersonation.action_blocked.v1` in `sync_outbox`.

## Deferred Notes

The backend does not add a broad unsafe customer/admin login bypass for support sessions. Support session headers are used only to detect and block sensitive actions in approved admin routes. Broad admin-only maintenance route blocking is deferred to a coordinated back-office route decision.
