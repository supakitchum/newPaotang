# Partner BO Domain Auth Branding Decision

## Date

2026-05-21

## Status

Approved for Orchestrator dispatch.

## Decision

Add partner-specific Back Office domains using a derived `bo.*` host.

Domain contract:

```text
Storefront/customer: partner-a.test
Partner Back Office + same-origin API entrypoint: bo.partner-a.test
```

Do not use `api.*` for this workflow.

## Required Behavior

- `partner_tenant_domains.host` remains the primary storefront host, for example `partner-a.test`.
- Partner BO/API host is derived by prefixing the storefront host with `bo.`, for example `bo.partner-a.test`.
- Backend partner BO resolver strips `bo.` and resolves the remaining host through `partner_tenant_domains.host`.
- Partner BO login is tenant-only and must infer `tenant_id` from host.
- Partner BO login must reject central scope and reject admins that do not have tenant scope for the resolved partner tenant.
- Partner BO `/auth/admin/me`, refresh, menu, and tenant admin APIs must not expose or allow central scope or a different partner tenant when accessed through `bo.*`.
- Central Back Office login remains unchanged and may still choose scope.
- Partner BO login page must hide scope and Partner/Tenant ID fields.
- Partner BO login page must show partner/tenant name and tenant theme logo.
- Enforce `1 Partner = 1 Tenant` for active provisioning and schema.

## API Addition

Add unauthenticated admin site config:

```text
GET /api/v1/public/admin-site-config
```

When called on `bo.partner-a.test`, return:

```json
{
  "mode": "partner",
  "partner": { "id": "par_x", "code": "partner-a", "name": "Partner A" },
  "tenant": { "id": "ten_x", "code": "partner-a", "name": "Partner A" },
  "domain": { "storefront_host": "partner-a.test", "bo_host": "bo.partner-a.test" },
  "brand": { "logo_url": "...", "favicon_url": "..." },
  "site": { "display_name": "Partner A" }
}
```

## Migration Guardrail

Adding `partner_tenants.partner_id` uniqueness must not silently delete or merge runtime data. If duplicate partner tenants exist, migration/backfill must fail with an explicit blocker listing duplicate partner IDs. Any cleanup requires a separate Coordinator decision.

## Out Of Scope

- Custom BO host labels other than `bo.*`.
- `api.*` host support.
- Central BO redesign.
- Full partner-specific BO branding after login beyond login page in this v1 pass.
- Runtime DB cleanup.

## Validation Expectations

- Backend feature tests cover host inference, central-scope rejection on partner host, cross-partner rejection, filtered scope output, admin site config, and `1 Partner = 1 Tenant`.
- BO tests/static checks cover partner host mode, hidden scope/ID fields, tenant branding, tenant-only redirect, and unchanged Central BO login.
- QA uses local proxy/Host header evidence with `bo.partner-a.test` and preserves Host header to platform-api.

## Dispatch

Next Agent: Orchestrator

User must send the Coordinator board instruction to Orchestrator chat.
