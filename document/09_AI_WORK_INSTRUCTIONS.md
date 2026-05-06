# 09 AI Work Instructions

## Rules For AI Agents

- Read these documents before coding.
- Treat NewPaotang as one modular platform, not 3 subprojects.
- Do not create per-business-module or per-tenant forks such as central-stock/partner-store/customer-web unless explicitly instructed.
- Do not cross module boundaries without a service/event contract.
- Central and tenant admin permissions are separate scopes in one RBAC engine.
- Central and tenant admin menus are separate scopes in one menu engine.
- Never trust Web UI permission only.
- Use backend permission middleware/policy.
- Use DB transaction for booking and wallet.
- Use idempotency for checkout, payment, and sync.
- Use outbox/inbox for cross-module sync.
- Do not hardcode old affiliate hierarchy.
- Do not serve high volume lottery images through Laravel app server.
- Do not process massive partner tenant sync synchronously in a request.
- Do not clone codebase per agent website.
- Use tenant/domain/theme configuration for white label websites.
- All public tenant websites must use HTTPS through Cloudflare.
- `customer` project in `apps/customer` already exists and its flow must be preserved.
- Customer API integration must be done through adapter/composables that call `platform-api`.
- Do not upgrade or rewrite the existing `customer` flow unless explicitly requested and covered by a migration/regression plan.
- New frontend projects should use Nuxt.js latest stable (`nuxt@latest`) by default.
- `back-office` is the admin dashboard frontend and must use the admin dashboard template guideline.
- Partner SEO must be tenant-aware and must not hardcode platform-wide metadata.
- Reward checking must be queued, chunked, idempotent, and auditable.
- Tenant maintenance mode must be tenant-scoped and must not affect other partners.
- Support/developer access must be impersonation-based and must never expose real passwords.
- Partner creation must include monitoring profile, usage meters, alert policy, and billing counters.
- Prefer PostgreSQL + Redis/Valkey as the default operational stack.
- If adding NoSQL, ClickHouse, search engine, analytics database, or a second operational database, create an architecture decision record with reason, owner, migration path, operational impact, and rollback plan.
- Before implementing execution work, read `15_EXECUTION_PLAN.md`.

## Every Module Must Include

```text
migration
model
service
controller
request validation
tests
documentation update
```

## Required Tests

```text
admin permission blocks unauthorized action
menu returns only allowed items
stock allocation respects quota
stock sync is idempotent
booking concurrent same stock
reservation expiration
checkout wallet debit
commission calculation
sync retry
peak traffic and burst sync
image URL uses CDN/cache strategy
tenant provisioning creates domain/theme/admin defaults
partner creation creates monitoring and usage metering defaults
single platform module boundaries are preserved
tenant SEO canonical and sitemap use HTTPS tenant domain
reward checking does not duplicate winning tickets
permission scope blocks cross-tenant access
tenant maintenance mode blocks only selected tenant
support impersonation is audited and time-limited
support impersonation cannot perform blocked sensitive actions
existing customer flow remains compatible after integration
extra data store decision is documented when added
```

## Red Flags

Ask before doing:

```text
customer writes Central Stock Module directly
cache used as source of truth
wallet balance changed without ledger
affiliate hierarchy old style added
booking without lock
admin endpoint without permission
menu hardcoded without permission
tenant query without tenant_id or partner_id
permission check without scope
image stored as base64 in DB
full stock sync used during peak traffic
reward checking done synchronously in HTTP request
reward winner write without unique idempotency key
SEO metadata hardcoded for all tenants
public tenant site without HTTPS/Cloudflare path
existing customer project upgraded or rewritten without migration/regression plan
existing customer flow rewritten without explicit instruction
maintenance mode implemented globally without tenant scope
support access reveals or resets user password without explicit flow
impersonation session without reason/ticket/audit
impersonation allowed to change wallet/payment/permission by default
new repository or code fork created per agent website
central-stock/partner-store/customer-web split into separate business codebases or tenant forks
domain hardcoded in web build
partner created without monitoring/usage metering profile
destructive migration
NoSQL, ClickHouse, analytics database, search engine, or second operational database added without architecture decision record
```
