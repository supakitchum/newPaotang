# NewPaotang Backend Event Contracts

Cross-module sync must use outbox/inbox plus queue workers. Events are persisted in PostgreSQL before dispatch. Redis/Valkey can transport or schedule work but cannot be the source of truth.

## Event Envelope

All events use this envelope:

```json
{
  "event_id": "evt_01HX0000000000000000000000",
  "event_type": "stock.allocated.v1",
  "event_version": 1,
  "occurred_at": "2026-05-04T00:00:00Z",
  "producer": "central_stock",
  "tenant_id": "ten_01HX0000000000000000000000",
  "partner_id": "par_01HX0000000000000000000000",
  "game_id": "game_01HX0000000000000000000000",
  "idempotency_key": "idem_01HX0000000000000000000000",
  "correlation_id": "req_01HX0000000000000000000000",
  "payload": {}
}
```

`tenant_id` is required for tenant-local events. Central-only events may set it to `null`.

Event type naming:

```text
<domain>.<past_tense_action>.v<version>
```

Examples:

```text
stock.allocated.v1
order.paid.v1
reward.published.v1
support_impersonation.action_blocked.v1
```

Event payloads must be backward-compatible within the same version. Breaking payload changes require a new event version.

Persisted outbox/inbox `event_type` values include the version suffix. Realtime clients may subscribe to stable aliases such as `reservation.expired` or `reward.published`, but the backend event record remains versioned, for example `reservation.expired.v1`.

## Outbox/Inbox Rules

```text
write business state and outbox row in same DB transaction
queue worker dispatches pending outbox rows
consumer stores inbox row before processing
consumer deduplicates by event_id or idempotency_key
consumer writes state changes in transaction
failed events retry with backoff
poison events move to dead letter status
```

Outbox rows must include enough metadata to route and replay safely:

```text
event_id
event_type
event_version
producer
tenant_id nullable
partner_id nullable
idempotency_key
correlation_id
payload_json
status
attempt_count
available_at
processed_at
last_error
```

## Event Types

### stock.allocated.v1

Producer: Central Stock Module

Consumer: Partner Store Module

Payload:

```json
{
  "allocation_id": "alloc_01HX...",
  "partner_id": "par_01HX...",
  "tenant_id": "ten_01HX...",
  "game_id": "game_01HX...",
  "cursor": "alloc-cursor",
  "item_count": 10000,
  "chunk_size": 5000
}
```

### stock.recalled.v1

Producer: Central Stock Module

Consumer: Partner Store Module

Payload:

```json
{
  "recall_id": "recall_01HX...",
  "allocation_id": "alloc_01HX...",
  "partner_id": "par_01HX...",
  "tenant_id": "ten_01HX...",
  "game_id": "game_01HX...",
  "reason": "quota_adjustment"
}
```

### stock.sync_completed.v1

Producer: Partner Store Module

Consumer: Central Stock Module

Payload:

```json
{
  "sync_batch_id": "sync_01HX...",
  "allocation_id": "alloc_01HX...",
  "partner_id": "par_01HX...",
  "tenant_id": "ten_01HX...",
  "game_id": "game_01HX...",
  "last_cursor": "alloc-cursor",
  "upserted_count": 5000
}
```

### reservation.created.v1

Producer: Partner Store Module

Consumer: Customer realtime, audit/report workers

Payload:

```json
{
  "reservation_id": "res_01HX...",
  "tenant_id": "ten_01HX...",
  "customer_id": "cus_01HX...",
  "game_id": "game_01HX...",
  "local_stock_item_ids": ["lsi_01HX..."],
  "expires_at": "2026-05-04T00:15:00Z"
}
```

### reservation.expired.v1

Producer: Partner Store Module

Consumer: Customer realtime, report workers

Payload:

```json
{
  "reservation_id": "res_01HX...",
  "tenant_id": "ten_01HX...",
  "customer_id": "cus_01HX...",
  "game_id": "game_01HX...",
  "released_item_count": 1
}
```

### reservation.released.v1

Producer: Partner Store Module

Consumer: Customer realtime, report workers

Payload:

```json
{
  "reservation_id": "res_01HX...",
  "tenant_id": "ten_01HX...",
  "customer_id": "cus_01HX...",
  "game_id": "game_01HX...",
  "released_item_count": 1,
  "released_by": "customer"
}
```

### order.paid.v1

Producer: Partner Store Module

Consumer: commission, notification, central sold sync workers

Payload:

```json
{
  "order_id": "ord_01HX...",
  "tenant_id": "ten_01HX...",
  "customer_id": "cus_01HX...",
  "game_id": "game_01HX...",
  "amount": 10000,
  "currency": "THB",
  "ticket_ids": ["tic_01HX..."]
}
```

### stock.sold.v1

Producer: Partner Store Module

Consumer: Central Stock Module

Payload:

```json
{
  "order_id": "ord_01HX...",
  "tenant_id": "ten_01HX...",
  "partner_id": "par_01HX...",
  "game_id": "game_01HX...",
  "items": [
    {
      "stock_item_id": "stk_01HX...",
      "local_stock_item_id": "lsi_01HX...",
      "ticket_id": "tic_01HX...",
      "sold_at": "2026-05-04T00:00:00Z"
    }
  ]
}
```

### stock.unavailable.v1

Producer: Partner Store Module

Consumer: Customer realtime

Payload:

```json
{
  "tenant_id": "ten_01HX...",
  "game_id": "game_01HX...",
  "local_stock_item_ids": ["lsi_01HX..."],
  "reason": "reserved_or_sold"
}
```

Realtime consumers must treat this event as a refresh hint only. The reserve/search API response remains authoritative.

### game.closed.v1

Producer: Central Stock Module

Consumer: Partner Store Module, Customer realtime, tenant config cache

Payload:

```json
{
  "game_id": "game_01HX...",
  "closed_at": "2026-05-04T00:00:00Z",
  "reason": "draw_cutoff"
}
```

### wallet.updated.v1

Producer: Partner Store Module

Consumer: Customer realtime, notification, report workers

Payload:

```json
{
  "tenant_id": "ten_01HX...",
  "customer_id": "cus_01HX...",
  "wallet_id": "wal_01HX...",
  "ledger_id": "wle_01HX...",
  "entry_type": "debit",
  "amount": 10000,
  "currency": "THB",
  "posted_balance": 50000
}
```

### commission.calculated.v1

Producer: Affiliate/Commission worker

Consumer: wallet/report/settlement workers

Payload:

```json
{
  "tenant_id": "ten_01HX...",
  "affiliate_account_id": "aff_01HX...",
  "order_id": "ord_01HX...",
  "commission_rule_id": "cru_01HX...",
  "commission_transaction_id": "ctx_01HX...",
  "amount": 500,
  "currency": "THB"
}
```

### reward.published.v1

Producer: Reward Result Engine

Consumer: Partner Store, Customer result cache, notification workers

Payload:

```json
{
  "reward_result_id": "rew_01HX...",
  "game_id": "game_01HX...",
  "reward_version": 3,
  "published_at": "2026-05-04T00:00:00Z"
}
```

Realtime payloads should include only the version and identifiers, not large result data.

### reward.risk.updated

Producer: Reward Risk Assessment worker

Consumer: Tenant owner BO and Central superadmin BO

Realtime payload:

```json
{
  "tenant_id": "ten_01HX...",
  "run_id": "rru_01HX...",
  "game_id": "game_01HX...",
  "phase": "provisional",
  "status": "completed",
  "finding_count": 2,
  "updated_at": "2026-08-01T12:00:00Z"
}
```

The event contains identifiers and aggregate status only. BO clients refetch detail from the authorized HTTP API.

### maintenance.changed.v1

Producer: Maintenance Module

Consumer: tenant config cache, customer, back-office admin sessions

Payload:

```json
{
  "tenant_id": "ten_01HX...",
  "mode": "full_site",
  "status": "active",
  "message": "Scheduled maintenance",
  "retry_after_seconds": 1800,
  "changed_by_admin_id": "adm_01HX..."
}
```

### partner.provisioned.v1

Producer: Partner Provisioning Module

Consumer: monitoring, billing, tenant config cache, audit workers

Payload:

```json
{
  "partner_id": "par_01HX...",
  "tenant_id": "ten_01HX...",
  "domain_id": "dom_01HX...",
  "deployment_mode": "shared",
  "owner_admin_id": "adm_01HX...",
  "monitoring_profile_id": "mon_01HX...",
  "billing_plan_binding_id": "bill_01HX..."
}
```

### partner.health_changed.v1

Producer: Monitoring Module

Consumer: alert, billing, admin notification workers

Payload:

```json
{
  "partner_id": "par_01HX...",
  "tenant_id": "ten_01HX...",
  "previous_status": "healthy",
  "current_status": "warning",
  "reason": "sync_lag_high",
  "checked_at": "2026-05-04T00:00:00Z"
}
```

### usage.meter_recorded.v1

Producer: Usage Metering Module

Consumer: billing summary workers

Payload:

```json
{
  "partner_id": "par_01HX...",
  "tenant_id": "ten_01HX...",
  "meter": "api_requests",
  "quantity": 1,
  "period_start": "2026-05-04T00:00:00Z",
  "period_end": "2026-05-04T00:01:00Z"
}
```

### support_impersonation.started.v1

Producer: Support Access Module

Consumer: audit/security workers

Payload:

```json
{
  "session_id": "imp_01HX...",
  "tenant_id": "ten_01HX...",
  "actor_admin_id": "adm_01HX...",
  "target_user_id": "cus_01HX...",
  "target_user_type": "customer",
  "scope": "customer_read",
  "ticket_id": "SUP-123",
  "expires_at": "2026-05-04T01:00:00Z"
}
```

### support_impersonation.action_blocked.v1

Producer: Support Access Module

Consumer: audit/security workers

Payload:

```json
{
  "session_id": "imp_01HX...",
  "tenant_id": "ten_01HX...",
  "actor_admin_id": "adm_01HX...",
  "target_user_id": "cus_01HX...",
  "blocked_action": "wallet_adjust",
  "route": "PATCH /api/v1/admin/tenant/wallets/{wallet_id}/adjust"
}
```

## Queue Names

```text
partner-inbox-high
partner-inbox-normal
stock-allocation
stock-sold-events
stock-recall
stock-sync
reservation-expiration
checkout-finalize
central-outbox
affiliate-commission
reward-validate
reward-check-high
reward-check-normal
reward-summary
reward-publish
reward-notification
reward-risk
report-build
webhook-dispatch
notification
usage-metering
partner-monitoring
```
