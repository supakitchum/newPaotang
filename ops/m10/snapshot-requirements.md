# M10 Snapshot Requirements

## Boundary

This artifact defines required database and object-storage metadata snapshots before migration/cutover/rollback approval. It does not create, export, restore, or validate real production snapshots.

Local/dev verifier:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

## Database Snapshot Scope

```text
schema and migration version
partners, tenants, domains, settings, themes, feature flags
RBAC users, roles, menus, permissions, scopes, permission cache versions
stock, allocations, local stock, reservations, orders, tickets
wallet ledger, payments, topups, webhook callback state
reward results, prizes, winning tickets, claims
agents, affiliates, commissions, payouts, reports, settlements
maintenance, support access, audit, outbox, inbox, monitoring, usage, alerts
```

Restore rehearsal must prove the snapshot can boot the app, pass health checks, and run smoke/readiness checks without leaking tenant data across scopes.

## Object-Storage Metadata Snapshot Scope

```text
ticket image object key inventory
thumbnail/preview/original variant map
tenant and partner storage prefix ownership
CDN cache policy metadata
immutable object policy and retention notes
missing object and orphan object counts
```

Raw binary objects must not be committed to the repository. Metadata artifacts for QA must not include signed URLs or production credentials.

## Retention And Access

```text
snapshot owner identified
retention window approved
restore access restricted to approved operators
snapshot ids captured in release evidence
secret material stored outside committed files
```

## Required Production Evidence

```text
real database snapshot completed
real restore rehearsal completed
object-storage metadata snapshot completed
ticket-image inventory reviewed
rollback compatibility evidence captured
```
