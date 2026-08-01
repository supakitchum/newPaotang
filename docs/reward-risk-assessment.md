# Reward Risk Assessment

## Purpose

Reward Risk Assessment is a read-only operational view for tenant owners and Central superadmins. It evaluates paid lottery purchases against selected reward types without changing any ticket, image, order, purchase history, winning ticket, claim, or payout record.

There is deliberately no Customer Flutter route, API, menu, or notification for this module.

## Calculation

The assessment key is `tenant_id + game_id + customer_id + full_number`.

- Customer purchase amount is the sum of `order_items.price_amount` for paid, non-cancelled, non-refunded orders in the game.
- Prize amount is the sum of all matching monitored prize types for every ticket in the customer/full-number group.
- Threshold is customer purchase amount multiplied by the tenant settings snapshot multiplier.
- A `threshold_exceeded` finding is stored only when prize amount is greater than the threshold.
- A run stores aggregate counts and amounts even when no finding is created.

All currency calculations use integer minor units. The multiplier is stored with two decimal places and supports `0.01` through `1,000.00`.

## Lifecycle

- A changed primary live-result payload queues a `provisional` assessment after the result transaction commits.
- Publishing a checked result queues a `final` assessment sourced from `winning_tickets.amount` after commit.
- Redraw or correction marks current runs for that reward result as `superseded` before a new reward version is assessed.
- Jobs run on `reward-risk`, use unique source/settings hashes, retry with backoff, lock each tenant/result/phase, and fan out enabled tenants in chunks.
- Provisional workers reject stale source hashes, so an older live payload cannot replace a newer assessment when workers finish out of order.
- Paid purchases are aggregated per customer in SQL; matching tickets and final winners are streamed in bounded chunks instead of loading an entire draw into memory.
- Queue or realtime failure cannot block result ingestion, result publication, Order, or Checkout.

## Data Model

- `tenant_reward_risk_settings`: tenant toggle, monitored prize types, multiplier, and settings version.
- `reward_risk_runs`: immutable source/settings snapshot and aggregate assessment status.
- `reward_risk_findings`: only customer/full-number groups above threshold.
- `reward_risk_finding_tickets`: ticket and winning-ticket evidence behind each finding.

The module reads commerce and reward data but has no update path to those source tables.

## Access

- Tenant APIs require both `reward_risk.view` or `reward_risk.manage` and an active `owner` or `owner_partner` role.
- Central APIs require `reward_risk.view` and an active `super_admin` role.
- Directly assigning the permission to any other role does not bypass the hard role guard.
- Central responses omit customer IDs/names and mask customer number and phone. Tenant owners receive full in-tenant details.

## APIs And BO

Tenant endpoints live under `/api/v1/admin/tenant/reward-risk`; Central endpoints live under `/api/v1/admin/central/reward-risk`. List endpoints use cursor pagination and support game, phase, status, tenant, and prize-type filters where applicable.

The BO page is `/admin/{scope}/reward-risk`. Tenant owners can edit settings and inspect overview, findings, and history. Central superadmins receive aggregate partner/tenant reporting and masked drill-down only. Realtime sends identifiers, status, phase, and count; clients refetch the HTTP resource and poll every 15 seconds when realtime is unavailable.

## Verification

Database tests must use `newpaotang_test`. Runtime migration is never automatic from agent work and requires an explicit user instruction in that turn.
