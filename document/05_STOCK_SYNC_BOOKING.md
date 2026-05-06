# 05 Stock Sync And Booking

## Stock Principle

- Central Stock Module owns master stock.
- Partner Store Module owns tenant-local sale stock.
- Customer search must read tenant-local stock through Platform API.
- Booking must lock tenant-local stock.

## Stock Sync Flow

```text
Central Stock Module allocates stock
  -> create allocation event
  -> Partner Store Module pulls by cursor
  -> bulk upsert local_stock_items
  -> update sync cursor
  -> stock ready to sell
```

## Large Stock Strategy

Use chunk/cursor.

```text
chunk size: 5,000 - 20,000 rows
bulk insert/upsert
partition by game_id
precompute full_number, front3, back3, back2
```

## Search Index

```text
game_id + full_number
game_id + front3 + status
game_id + back3 + status
game_id + back2 + status
game_id + status
```

## Booking Lock

```text
DB transaction
SELECT local_stock_items WHERE token = ? FOR UPDATE
validate status = available
create reservation
mark reserved
commit
```

## Reservation Expiration

```text
reservation expiration job
  -> lock reservation
  -> if not paid
  -> mark expired
  -> release stock
```

## Sync Back To Central Stock Module

Partner Store Module sends:

```text
StockSold
StockReturned
ReservationExpired
OrderCancelled
```

Every event must have idempotency key.

## Burst Sync Protection

Central Stock Module must not process all partner tenant update requests synchronously during peak traffic.

Recommended pattern:

```text
Partner Store Module sends event batch
  -> Central Stock Module validates auth/idempotency
  -> Central Stock Module writes inbox quickly
  -> Central Stock Module returns accepted
  -> queue worker processes state changes
```

## Backpressure

When Central Stock Module is overloaded:

```text
429 Too Many Requests
503 Service Unavailable
Retry-After header
partner-specific rate limits
```

Partner Store Module must retry with exponential backoff and idempotency key.

## Reward Stock Matching Principle

Reward checking must read sold/order stock by `game_id` and indexed lottery number fields.

```text
reward result published
  -> create reward_check_batch
  -> split sold tickets by game_id and tenant chunks
  -> match full_number/front3/back3/back2 by index
  -> write winning_tickets
  -> publish summary
```

Rules:

- Do not scan all stock without `game_id` filter.
- Do not load all sold tickets into memory.
- Use chunk/cursor processing.
- Use unique keys to prevent duplicate winner records.
- Reward checking jobs must be retryable and idempotent.
