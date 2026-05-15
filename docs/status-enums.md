# NewPaotang Backend Status Enums

Status values are lowercase snake_case. Do not overload one enum for multiple domains.

## Partner And Tenant

`partners.status`

```text
draft
active
suspended
closed
```

`partners.type`

```text
partner_store
agent_network
white_label
api_partner
internal
```

`partner_tenants.status`

```text
provisioning
active
maintenance
suspended
closed
```

`partner_tenant_domains.status`

```text
pending_verification
dns_verified
ssl_pending
active
failed
suspended
archived
```

`partner_tenant_domains.type`

```text
subdomain
custom_domain
```

`partner_tenant_deployment_profiles.mode`

```text
shared
dedicated_runtime
dedicated_resource_pool
```

## Admin/RBAC

`admin_scopes.scope_type`

```text
central
tenant
```

`admin_users.status`

```text
invited
active
locked
suspended
disabled
```

`roles.status`, `permissions.status`, `admin_menus.status`

```text
active
inactive
archived
```

## Games And Stock

`games.status`

```text
draft
open
closed
reward_recorded
reward_checking
reward_verified
reward_published
archived
```

`stock_items.status`

```text
available
allocated
sold
recalled
voided
```

`local_stock_items.status`

```text
available
reserved
sold
expired
returned
recalled
unavailable
```

`stock_generation_batches.status`

```text
queued
pending
processing
completed
failed
cancelled
```

`partner_stock_allocations.status`

```text
draft
pending
processing
allocated
partially_allocated
failed
recalled
cancelled
```

## Sync

`sync_outbox.status`, `sync_inbox.status`

```text
pending
processing
processed
failed
ignored_duplicate
dead_lettered
```

`stock_sync_batches.status`

```text
pending
processing
completed
failed
retrying
cancelled
```

## Reservation And Checkout

`stock_reservations.status`

```text
active
released
expired
converted
cancelled
```

`orders.status`

```text
draft
pending_payment
paid
cancelled
expired
refunded
failed
```

`order_items.status`

```text
reserved
sold
cancelled
refunded
```

`tickets.status`

```text
active
cancelled
reward_pending
winning
non_winning
paid_out
voided
```

## Wallet And Payment

`wallets.status`

```text
active
locked
suspended
closed
```

`wallet_ledger.entry_type`

```text
credit
debit
hold
release
reversal
adjustment
```

`wallet_ledger.status`

```text
pending
posted
reversed
failed
```

`payments.status`, `topup_requests.status`

```text
pending
processing
succeeded
failed
cancelled
expired
reversed
```

## Affiliate, Commission, Payout

`affiliate_accounts.status`, `affiliate_links.status`

```text
active
inactive
suspended
archived
```

`affiliate_attributions.status`

```text
pending
converted
expired
cancelled
```

`commission_rules.status`

```text
draft
active
inactive
archived
```

`commission_transactions.status`

```text
pending
approved
posted
reversed
failed
```

`affiliate_payouts.status`

```text
pending
approved
processing
paid
failed
cancelled
reversed
```

## Reward

`reward_results.status`

```text
draft
recorded
checking
summary_ready
verified
published
corrected
archived
```

`reward_check_batches.status`, `reward_check_items.status`

```text
pending
processing
completed
failed
retrying
cancelled
```

`winning_tickets.status`

```text
pending
verified
paid
reversed
voided
```

## Maintenance And Support

`maintenance.mode`

```text
full_site
customer_web_only
admin_only
checkout_payment_only
read_only
scheduled
```

`maintenance.status`

```text
inactive
scheduled
active
ended
cancelled
```

`support_access_requests.status`

```text
draft
pending_approval
approved
denied
expired
revoked
completed
```

`support_impersonation_sessions.status`

```text
pending
active
ended
expired
revoked
blocked
```

`support_access.scope`

```text
customer_read
customer_limited_write
tenant_admin_read
tenant_admin_limited_write
elevated_action
```

## Monitoring, Usage, Billing

`partner_monitoring_profiles.status`

```text
active
paused
suspended
archived
```

`partner_health_checks.health_status`

```text
healthy
warning
critical
suspended
unknown
```

`partner_alert_policies.status`

```text
active
paused
archived
```

`partner_alert_events.status`

```text
open
acknowledged
resolved
suppressed
```

`partner_usage_meters.status`

```text
active
paused
archived
```

`partner_billing_plan_bindings.status`

```text
trial
active
past_due
suspended
cancelled
```
