# NewPaotang Backend ERD

This Milestone 0 ERD defines logical tables and ownership. Exact Laravel migration columns may evolve, but module boundaries and source-of-truth rules should remain stable.

## Core Platform

```text
partners
  id pk
  code unique
  name
  status

partner_tenants
  id pk
  partner_id fk -> partners.id
  code unique
  name
  status

partner_tenant_domains
  id pk
  partner_id fk -> partners.id
  tenant_id fk -> partner_tenants.id
  host unique
  type
  status
  is_primary
  verified_at
  ssl_ready_at

partner_tenant_settings
  id pk
  tenant_id fk -> partner_tenants.id
  key
  value_json

partner_tenant_themes
  id pk
  tenant_id fk -> partner_tenants.id
  site_name
  logo_url
  primary_color
  secondary_color

partner_tenant_feature_flags
  id pk
  tenant_id fk -> partner_tenants.id
  flag
  enabled
```

## RBAC, Menu, Audit

```text
admin_users
  id pk
  email unique
  password_hash
  status

admin_scopes
  id pk
  scope_type
  tenant_id nullable fk -> partner_tenants.id
  partner_id nullable fk -> partners.id

roles
  id pk
  scope_type
  tenant_id nullable fk -> partner_tenants.id
  code
  name
  status
  version

permissions
  id pk
  scope_type
  code
  name
  status

role_permissions
  role_id fk -> roles.id
  permission_id fk -> permissions.id

admin_user_roles
  admin_user_id fk -> admin_users.id
  role_id fk -> roles.id
  scope_id fk -> admin_scopes.id

admin_menus
  id pk
  scope_type
  parent_id nullable fk -> admin_menus.id
  code
  label
  route
  required_permission_code
  sort_order
  status

role_menus
  role_id fk -> roles.id
  menu_id fk -> admin_menus.id

admin_permission_cache_versions
  id pk
  admin_user_id fk -> admin_users.id
  scope_id fk -> admin_scopes.id
  version

audit_logs
  id pk
  actor_type
  actor_id
  scope_type
  tenant_id nullable fk -> partner_tenants.id
  partner_id nullable fk -> partners.id
  action
  target_type
  target_id
  request_id
  ip_address
  user_agent
  payload_redacted_json
```

## Central Stock

```text
games
  id pk
  code unique
  name
  sale_start_at
  draw_at
  close_at
  closed_at
  status
  reward_version

stock_generation_batches
  id pk
  game_id fk -> games.id
  type
  status
  requested_count
  generated_count
  total_rounds
  processed_rounds
  chunk_rounds
  started_at
  completed_at
  failed_at
  failure_reason

stock_generation_batch_chunks
  id pk
  batch_id fk -> stock_generation_batches.id
  chunk_index
  start_round
  round_count
  status
  attempt_count
  started_at
  completed_at
  failed_at
  failure_reason

stock_items
  id pk
  game_id fk -> games.id
  full_number
  front3
  back3
  back2
  image_key
  image_thumb_key
  status

lottery_image_background_asset_sets
  id pk
  game_id fk -> games.id
  version
  set_type odd/even/charity
  status ready/inactive/retired
  source_asset_id fk -> platform_assets.id
  full_asset_id fk -> platform_assets.id
  thumb_asset_id fk -> platform_assets.id
  source_storage_path
  full_storage_path
  thumb_storage_path
  source/full/thumb dimensions and size metadata

lottery_image_mix_settings
  id pk
  game_id unique fk -> games.id
  odd_percentage
  even_percentage
  charity_percentage
  updated_by_admin_id nullable fk -> admin_users.id

partner_quotas
  id pk
  partner_id fk -> partners.id
  tenant_id fk -> partner_tenants.id
  game_id fk -> games.id
  quota_count
  allocated_count
  sale_start_at nullable partner override
  sale_close_at nullable partner override

partner_stock_allocations
  id pk
  partner_id fk -> partners.id
  tenant_id fk -> partner_tenants.id
  game_id fk -> games.id
  status
  requested_count calculated target count for legacy compatibility
  allocation_percent_basis_points nullable percent workflow snapshot
  allocated_count
  recalled_count
  payload_hash
  cursor
```

## Partner Store, Booking, Checkout

```text
local_stock_items
  id pk
  tenant_id fk -> partner_tenants.id
  partner_id fk -> partners.id
  game_id fk -> games.id
  stock_item_id fk -> stock_items.id
  full_number
  front3
  back3
  back2
  image_url
  image_thumb_url
  status

stock_sync_batches
  id pk
  tenant_id fk -> partner_tenants.id
  allocation_id fk -> partner_stock_allocations.id
  status
  cursor
  processed_count

stock_reservations
  id pk
  tenant_id fk -> partner_tenants.id
  customer_id fk -> customers.id
  game_id fk -> games.id
  status
  expires_at

stock_reservation_items
  reservation_id fk -> stock_reservations.id
  local_stock_item_id fk -> local_stock_items.id

customers
  id pk
  tenant_id fk -> partner_tenants.id
  phone unique per tenant
  status

orders
  id pk
  tenant_id fk -> partner_tenants.id
  customer_id fk -> customers.id
  reservation_id fk -> stock_reservations.id
  status
  total_amount
  currency

order_items
  id pk
  tenant_id fk -> partner_tenants.id
  order_id fk -> orders.id
  local_stock_item_id fk -> local_stock_items.id
  ticket_id nullable fk -> tickets.id
  status

tickets
  id pk
  tenant_id fk -> partner_tenants.id
  customer_id fk -> customers.id
  order_id fk -> orders.id
  local_stock_item_id fk -> local_stock_items.id
  game_id fk -> games.id
  status
```

## Wallet And Payment

```text
wallets
  id pk
  tenant_id fk -> partner_tenants.id
  customer_id fk -> customers.id
  status
  balance_amount
  currency

wallet_ledger
  id pk
  tenant_id fk -> partner_tenants.id
  wallet_id fk -> wallets.id
  customer_id fk -> customers.id
  entry_type
  status
  amount
  currency
  balance_after
  reference_type
  reference_id
  idempotency_key unique per tenant/reference

payments
  id pk
  tenant_id fk -> partner_tenants.id
  order_id nullable fk -> orders.id
  provider
  status
  amount
  currency
  idempotency_key

topup_requests
  id pk
  tenant_id fk -> partner_tenants.id
  customer_id fk -> customers.id
  wallet_id fk -> wallets.id
  provider
  status
  amount
  currency
  idempotency_key
```

## Reward

```text
reward_results
  id pk
  game_id fk -> games.id
  status
  version

reward_prizes
  id pk
  reward_result_id fk -> reward_results.id
  prize_type
  prize_number
  amount
  currency

reward_check_batches
  id pk
  reward_result_id fk -> reward_results.id
  game_id fk -> games.id
  status
  chunk_count

reward_check_items
  id pk
  reward_check_batch_id fk -> reward_check_batches.id
  tenant_id fk -> partner_tenants.id
  cursor_from
  cursor_to
  status

winning_tickets
  id pk
  tenant_id fk -> partner_tenants.id
  game_id fk -> games.id
  ticket_id fk -> tickets.id
  reward_prize_id fk -> reward_prizes.id
  prize_type
  prize_number
  amount
  currency
  status
  unique(game_id, ticket_id, prize_type, prize_number)

reward_publish_logs
  id pk
  reward_result_id fk -> reward_results.id
  game_id fk -> games.id
  reward_version
  published_by_admin_id fk -> admin_users.id
```

## SEO, Maintenance, Support

```text
partner_tenant_seo_settings
partner_tenant_seo_pages
partner_tenant_redirects
partner_tenant_sitemap_entries

partner_tenant_maintenance_settings
partner_tenant_maintenance_events
partner_tenant_maintenance_bypasses
partner_tenant_maintenance_schedules

support_access_requests
support_access_approvals
support_impersonation_sessions
support_impersonation_events
support_impersonation_blocked_actions
```

## Sync And Idempotency

```text
sync_outbox
  id pk
  event_id unique
  event_type
  producer
  tenant_id nullable fk -> partner_tenants.id
  partner_id nullable fk -> partners.id
  idempotency_key
  payload_json
  status
  available_at
  processed_at

sync_inbox
  id pk
  event_id unique
  event_type
  consumer
  tenant_id nullable fk -> partner_tenants.id
  partner_id nullable fk -> partners.id
  idempotency_key
  payload_hash
  status
  processed_at

idempotency_keys
  id pk
  actor_type
  actor_id
  route_key
  idempotency_key
  payload_hash
  response_status
  response_body_json
  expires_at
```

## Required Indexes

```text
partner_tenant_domains(host, status)
roles(scope_type, tenant_id, code)
permissions(scope_type, code)
audit_logs(tenant_id, action, created_at)
stock_items(game_id, status)
stock_items(game_id, full_number)
local_stock_items(tenant_id, game_id, status)
local_stock_items(tenant_id, game_id, full_number)
local_stock_items(tenant_id, game_id, front3, status)
local_stock_items(tenant_id, game_id, back3, status)
local_stock_items(tenant_id, game_id, back2, status)
stock_reservations(tenant_id, status, expires_at)
orders(tenant_id, customer_id, status, created_at)
tickets(tenant_id, customer_id, game_id, status)
wallet_ledger(tenant_id, wallet_id, created_at)
sync_outbox(status, available_at)
sync_inbox(event_id)
winning_tickets(game_id, ticket_id, prize_type, prize_number)
```
