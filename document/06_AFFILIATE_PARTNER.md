# 06 Partner And Affiliate

## Partner Management Module

Partner คือร้านค้าย่อย/tenant ภายใน NewPaotang Platform ที่ได้รับ stock จาก Central Stock Module

Partner ไม่ใช่โปรเจคแยก แต่เป็น tenant/config/resource profile ภายใน platform เดียว

### Partner Types

```text
partner_store
agent_network
white_label
api_partner
internal
```

### Partner Use Cases

```text
create partner
issue API client
set quota
set price rule
allocate stock
receive sold event
view settlement
suspend partner
bootstrap partner monitoring
view partner usage
view partner health
```

## Partner Creation Flow

เมื่อสร้าง partner ใหม่ platform ต้องสร้างข้อมูลด้าน operation และ monitoring ไปพร้อมกัน ไม่ใช่แค่สร้าง account

```text
create partner profile
  -> create partner API client
  -> create quota policy
  -> create price rule default
  -> create deployment profile
  -> create monitoring profile
  -> create usage meter counters
  -> create alert policy
  -> create billing plan binding
  -> create default dashboard link
  -> create audit log
```

## Partner Monitoring Requirements

ทุก partner ต้องมี monitoring profile ของตัวเอง

```text
partner_monitoring_profiles
partner_usage_meters
partner_daily_usage_summaries
partner_alert_policies
partner_alert_events
partner_health_checks
```

Metrics per partner:

```text
api_request_count
rate_limited_count
stock_allocated_count
stock_synced_count
sold_ticket_count
order_count
sync_lag_seconds
queue_lag_seconds
image_bandwidth_gb
storage_gb
error_rate
checkout_fail_count
booking_fail_count
```

Partner health status:

```text
healthy
warning
critical
suspended
```

## Billing Usage

Monitoring data must feed billing.

```text
base package
stock quota overage
API request overage
image bandwidth overage
storage overage
custom domain fee
dedicated resource fee
```

## Affiliate Module

Affiliate ใหม่ไม่ใช้ hierarchy เดิมแบบ Company/Senior/Member

### New Model

```text
Affiliate Program
Affiliate Account
Affiliate Link
Attribution
Commission Rule
Commission Transaction
Affiliate Wallet
Payout
```

### Commission Rule Types

```text
fixed_per_order
percent_sales
percent_profit
per_ticket
first_purchase_bonus
tier_by_sales
multi_level optional
```

## Affiliate Flow

```text
Customer enters with ref code
  -> create attribution
  -> order paid
  -> commission worker calculates
  -> create commission transaction
  -> credit affiliate wallet
```

## Rules

- Do not put affiliate logic directly inside checkout controller.
- Commission must reference order_id and rule_id.
- Reversal must be ledger transaction, not delete.
