# M10 Old Data Migration Strategy

## Boundary

This artifact defines a local/dev rehearsal strategy only. It is not approval to connect to a real old-data source, import production customer data, execute a production cutover, or run a production rollback.

Run the safe verifier through Docker:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

The verifier must keep `production_approved=false` and must not emit raw secrets, production URLs, signed URLs, customer PII, or old-data payloads.

## Supported Source Categories

```text
partners and partner tenants
tenant domains and branding configuration
admin users, roles, permissions, and menus
customers and customer auth identities without raw passwords
wallet balances and ledger reconciliation inputs
games, master stock, allocations, and tenant-local stock
orders, tickets, payments, topups, and sold sync state
reward results, claims, agents, affiliates, reports, and settlements
```

Each source category must carry a stable legacy key, tenant identity, partner identity where applicable, source updated timestamp, and payload hash for replay detection.

## Unsupported Or Unknown Categories

```text
raw passwords or direct password hash reuse
production payment provider credentials
base64 ticket images
unmapped legacy statuses
records without tenant or partner identity
unversioned event payloads
ad hoc tenant-specific business rules
```

Unsupported rows must go to a reject report. They must not be silently coerced into current tables.

## Mapping Strategy

```text
legacy partner -> partners
legacy site/shop -> partner_tenants and partner_tenant_domains
legacy branding -> partner_tenant_settings and partner_tenant_themes
legacy admins -> admin_users, admin_scopes, roles, pivots
legacy customers -> customers and customer_auth_sessions only after re-auth strategy
legacy stock -> games, stock_items, partner_stock_allocations, local_stock_items
legacy orders -> orders, order_items, tickets, payments, wallet_ledger
legacy rewards -> reward_results, reward_prizes, winning_tickets, reward_claims
legacy affiliates -> agents, affiliate_accounts, affiliate_links, attributions, commissions
legacy events -> sync_outbox or sync_inbox with versioned event_type
```

## Idempotency And Replay

```text
legacy_source_key + tenant_id + target_table selects the target row
payload_hash mismatch becomes a reject, not an overwrite
replay of the same payload updates deterministic derived columns only
outbox/inbox rows preserve event_id or idempotency_key
ledger-like records are append/reconcile only; never collapse into mutable balances without evidence
```

## Validation And Reject Reports

Dry-run rehearsal must produce counts and categories only. Reject reports may include legacy ids, category, reason, and target table. Reject reports must not include customer PII, secrets, production URLs, signed URLs, or raw old-data payloads.

## Production Evidence Required

```text
real old-data source inventory approved
source-to-target mapping signed off by Coordinator/Ops
sample reject report reviewed without sensitive leakage
staging rehearsal completed from a snapshot
restore rehearsal evidence captured
production secret-management owner approved
```
