# 12 Monitoring Observability

## Purpose

Monitoring และ observability เป็น core module ของ platform โดยเฉพาะระบบ partner/tenant เพราะแต่ละ partner ใช้ resource ไม่เท่ากัน และต้องใช้ข้อมูลนี้ดูแล infra รวมถึงคิดค่าบริการ

## Goals

- รู้ว่า partner ไหนใช้ resource มาก
- รู้ว่า partner ไหนทำให้ระบบหน่วง
- ดู health ของ Central Stock Module, Partner Store Module, customer app, back-office app, Queue, DB, CDN ได้
- ใช้ usage metrics ไปคิดค่าบริการ
- alert ก่อนระบบล่ม
- รองรับวันหวยออกและช่วงประกาศผล

Monitoring ต้องมอง NewPaotang เป็นระบบเดียวที่มีหลาย module ไม่ใช่หลายโปรเจคแยกกัน

## Recommended Stack

Self-hosted option:

```text
Prometheus
Grafana
Loki
Tempo or Jaeger
Sentry
Laravel Horizon
Uptime Kuma
```

Managed option:

```text
Grafana Cloud
Datadog
New Relic
Sentry
Cloudflare Analytics
AWS CloudWatch
```

## Monitoring Levels

### Infrastructure

```text
CPU
RAM
disk
network
container health
load balancer health
PostgreSQL health
Redis/Valkey health
CDN origin health
```

### Application

```text
API request rate
API latency p95/p99
error rate
slow endpoints
login failures
booking failures
checkout failures
payment callback failures
reward check failures
permission denied spikes
cross-tenant access attempts
maintenance mode changes
support impersonation sessions
```

### Business

```text
stock sync lag
stock allocation count
reservation success/fail
order paid count
wallet ledger mismatch
central sync pending
reward publish status
reward check batch progress
reward winners count
reward payout amount
commission job failures
cashback job failures
```

### Partner/Tenant

```text
requests per partner
orders per partner
sold tickets per partner
stock count per partner
queue lag per partner
sync lag per partner
image bandwidth per partner
storage usage per partner
error rate per partner
rate limited count per partner
```

## Partner Creation Requirement

When a partner is created, the system must bootstrap monitoring defaults.

```text
create partner
  -> create monitoring profile
  -> create usage meter counters
  -> create alert policy
  -> create dashboard tags/folder
  -> create health check record
  -> bind billing plan
  -> start collecting metrics
```

## Tables

```text
partner_monitoring_profiles
partner_usage_meters
partner_usage_events
partner_daily_usage_summaries
partner_alert_policies
partner_alert_events
partner_health_checks
partner_billing_plan_bindings
```

## partner_monitoring_profiles

```text
id
partner_id
status
dashboard_uid
metrics_label
alert_policy_id
health_status
last_checked_at
metadata jsonb
```

## Usage Meters

Usage meters are used for billing and resource control.

```text
api_requests
booking_requests
checkout_requests
orders
sold_tickets
stock_allocated
stock_synced
image_bandwidth_gb
storage_gb
queue_jobs
custom_domains
sync_events
```

## Daily Usage Summary

```text
partner_id
date
api_request_count
booking_request_count
checkout_request_count
order_count
sold_ticket_count
image_bandwidth_gb
storage_gb
queue_job_count
rate_limited_count
error_count
```

## Alert Policies

Default partner alerts:

```text
api_error_rate_high
booking_fail_rate_high
checkout_fail_rate_high
sync_lag_high
queue_lag_high
image_cdn_hit_ratio_low
storage_quota_near_limit
api_rate_limit_exceeded
payment_callback_failure
reward_check_failure
permission_denied_spike
cross_tenant_access_attempt
```

## Dashboards

Required dashboards:

```text
Platform Overview
Central Stock Module Health
Partner Store Module Health
Partner Health
Partner Usage
Stock Sync
Booking Realtime
Checkout Wallet
Image CDN
Queue Horizon
Database
Billing Usage
Reward Checking
Security Permission
SEO And Domains
Maintenance And Support Access
```

## Metrics Labels

All metrics must include labels where applicable:

```text
platform=newpaotang
module=central_stock|partner_store|customer_web|shared
partner_id
partner_tenant_id
tenant_id
deployment_mode
package
endpoint
queue
game_id
```

## Reward Metrics

```text
reward_check_batch_count
reward_check_rows_processed
reward_check_duration_seconds
reward_check_failed_jobs
winning_ticket_count
reward_publish_latency
reward_cache_invalidation_time
duplicate_winner_prevented_count
```

## Security Metrics

```text
permission_denied_count
cross_tenant_access_denied_count
admin_impersonation_count
role_change_count
permission_cache_invalidated_count
```

## SEO And Cloudflare Metrics

```text
tenant_sitemap_generated_count
tenant_sitemap_error_count
tenant_canonical_mismatch_count
cloudflare_https_inactive_count
custom_domain_ssl_pending_count
```

## Maintenance And Support Metrics

```text
tenant_maintenance_active_count
tenant_maintenance_duration_seconds
maintenance_bypass_count
support_access_request_count
support_access_approval_count
support_impersonation_active_count
support_impersonation_blocked_action_count
support_impersonation_duration_seconds
```

## Billing Integration

Usage summary must feed billing.

Example billable metrics:

```text
monthly base package
sold ticket count
stock quota overage
API request overage
image bandwidth overage
storage overage
custom domain fee
dedicated DB fee
dedicated worker fee
```

## Resource Package Enforcement

Each partner package should define:

```text
api_requests_per_minute
booking_requests_per_minute
max_stock_quota
max_storage_gb
max_image_bandwidth_gb
queue_priority
custom_domain_allowed
dedicated_resource_allowed
```

If usage exceeds package:

```text
warn
rate limit
charge overage
upgrade package
suspend only as last resort
```

## Acceptance Criteria

```text
Every partner has monitoring profile after creation
Every partner has usage meters after creation
Every partner has default alert policy after creation
Dashboard can filter by partner_id
Billing can read daily usage summary
Alerts fire for sync lag and high error rate
Image bandwidth is visible per partner
Queue lag is visible per partner
```
