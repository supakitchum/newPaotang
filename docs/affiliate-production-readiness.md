# Affiliate Production Readiness

Updated: 2026-07-24

## Readiness Verdict

- Code-level security, migration, concurrency, financial, checkout, reporting,
  wallet, topup, and reward regressions pass locally.
- The feature is not yet approved for production traffic. Runtime data
  preflight, runtime migration, staging concurrency/load, and post-deploy smoke
  tests remain mandatory gates.
- No runtime database migration or query was executed during this audit.

## Enforced Invariants

### Affiliate identity and referral

- A customer can have only one Affiliate account per tenant.
- Store names are tenant-scoped, whitespace-collapsed, Unicode-normalized,
  case-folded, and reserved while pending.
- Store names reject invisible/control characters and concurrent duplicate
  claims are resolved by a database unique constraint.
- Public stores expose only active Affiliate accounts with an approved name.
- Affiliate owners cannot apply or earn from their own referral.
- A paid order keeps its bound Affiliate attribution even if commission
  processing is delayed or a later referral is opened.
- Customer/public Affiliate writes have independent configurable rate limits.

### Tier campaigns and commission

- Bronze, Silver, Gold, Platinum, and Diamond are tenant runtime data.
- Commission is ticket count multiplied by the Tier rate effective at the
  order `paid_at`; the transaction stores ticket, Tier, and rate snapshots.
- Delayed calculation cannot select a rate changed after payment.
- Fixed-threshold campaigns can promote or demote. Ranking campaigns are
  promotion-only and use reached time then Affiliate code as tie-breakers.
- Campaign create/update/finalize/cancel operations lock tenant Affiliate
  configuration, and overlapping scheduled/active campaigns are rejected.
- Finalization reconciles paid ticket attribution, freezes results, writes Tier
  history, and sends idempotent notifications.
- Commission and campaign schedulers isolate failures per order/campaign,
  continue the remaining batch, report failed IDs, and return a non-zero exit
  code so monitoring cannot treat a partial batch as successful.
- Both scheduled commands use `onOneServer()` in addition to row and tenant
  locks.

### Payout and wallet evidence

- `pending`, `approved`, and `paid` payouts reserve Affiliate balance.
- Every create and approve path rechecks available funds while locking the
  Affiliate account.
- Currency must match the Affiliate account. Wallet credit is THB-only.
- Bank transfer requires a bank name and account number snapshot. Customer
  reward-bank details are used only as an explicit fallback.
- Affiliate payout snapshots, Affiliate payout profiles, and the shared
  customer reward-bank profile are encrypted at rest with the application
  encryption key. Legacy JSON columns are retained only as null compatibility
  columns.
- Customer payout responses expose only a masked account number and last four
  digits. Full payout snapshots are returned only through tenant
  payout-management endpoints.
- Wallet payout approval posts one atomic wallet ledger entry and immediately
  becomes `paid`. The payout stores wallet, ledger, payment reference, payer,
  and paid time.
- External bank/manual payout follows `pending -> approved -> paid`. Marking it
  paid requires a payment reference and records payer/time evidence.
- Payment references are tenant/method unique. A PostgreSQL advisory lock
  prevents concurrent reuse before the unique constraint is reached.
- Wallet ledger writes validate entry type and amount direction, lock the
  wallet, reject conflicting idempotency replays, prevent negative balance,
  and commit ledger/balance atomically.
- Reports and settlements count only `paid` Affiliate payouts using `paid_at`.
  An approved external payout is not reported as cash paid.

### Payment and refund lifecycle

- Generic order update accepts only the admin note. It cannot mutate order or
  payment status.
- Paid/refunded orders cannot use the cancel endpoint. Paid orders must enter
  the dedicated refund lifecycle.
- Wallet refunds post one atomic reversal ledger entry before order status and
  Affiliate commission reversal change.
- External refunds require a unique finance/provider reference and the original
  payment record. The payment and order become refunded in the same transaction
  that creates immutable `order_refunds` evidence.
- Refund evidence records amount, currency, method, order/payment/ledger links,
  processor, reason, and idempotency key. External refund references are
  redacted from audit payloads.
- A commission is reversed only after refund evidence is committed.
- Payment callbacks are authenticated per tenant/provider with either:
  - `hmac_sha256`: `X-Webhook-Timestamp` plus
    `X-Signature: sha256=<hex>`, calculated over
    `{timestamp}.{raw_request_body}`; default replay window is 300 seconds.
  - `token`: `X-Webhook-Token` or Bearer token.
- Callback lookup is provider-strict. An event sent to one provider route
  cannot settle another provider's payment.
- Active provider connections and new external checkouts require an encrypted
  webhook secret. Callback traffic is rate limited independently.

## Migration Behavior

Relevant migrations, in repository order:

```text
2026_07_22_000001_create_affiliate_tiers_campaigns_and_store_name_reviews
2026_07_22_000002_backfill_affiliate_tier_admin_access
2026_07_24_000001_harden_affiliate_financial_integrity
2026_07_24_000003_add_payment_webhook_authentication
2026_07_24_000004_create_order_refund_evidence
2026_07_24_000005_encrypt_affiliate_bank_payloads
```

The financial-integrity migration:

1. Aborts before schema changes if duplicate tenant/customer Affiliate
   accounts exist.
2. Aborts before schema changes if an approved legacy wallet-credit payout
   exists without ledger evidence.
3. Adds payout wallet/ledger/reference/payer/time evidence and uniqueness.
4. Backfills legacy approved bank/manual payouts to paid with the marker
   `migration-20260724-approved:{payout_id}`.
5. Creates effective-dated Tier rate history and reconstructs available audit
   history.
6. Adds the tenant/customer Affiliate-account unique constraint.

Rollback recognizes only the migration marker above and restores those legacy
external payouts to `approved` before dropping the new evidence columns.

The webhook migration adds an encrypted per-connection secret without
hardcoding providers or credentials. Existing active connections intentionally
become not-ready until operations configure a secret.

The refund migration creates append-only, tenant-scoped evidence with unique
order, external-reference, and admin-idempotency constraints. It intentionally
does not invent evidence for legacy refunded orders; the post gate blocks until
finance reconciles those rows.

The bank-payload migration adds encrypted text columns for Affiliate payout
snapshots, Affiliate payout profiles, and the shared customer reward-bank
profile. It encrypts each non-empty legacy JSON payload, verifies that the row
can be represented as an object, then clears the legacy plaintext column. The
rollback decrypts each row before dropping the encrypted column and aborts
rather than discarding data when the active application key cannot decrypt it.

`APP_KEY` is therefore payout data key material. Back it up in the production
secret manager before migration. Losing or replacing it without a reviewed
re-encryption procedure makes payout data unreadable. Do not rotate `APP_KEY`
by simply replacing the environment value.

## Runtime Preflight

Pause Affiliate payout writes, Tier edits, commission workers, and campaign
finalization before running these checks. Keep checkout/order traffic running;
Affiliate processing must not be required by checkout.

Run the read-only command first and archive its JSON output:

```sh
docker compose exec platform-api \
  php artisan affiliate:production-preflight --phase=pre --json
```

If finance confirms that every legacy bank/manual `approved` payout was
actually delivered, repeat with the explicit acknowledgement and archive the
approval beside the output:

```sh
docker compose exec platform-api \
  php artisan affiliate:production-preflight --phase=pre \
  --ack-legacy-external-approved --json
```

An acknowledgement changes only gate severity; it never writes data.

### 1. Duplicate Affiliate accounts

```sql
SELECT tenant_id, customer_id, COUNT(*) AS account_count
FROM affiliate_accounts
WHERE customer_id IS NOT NULL
GROUP BY tenant_id, customer_id
HAVING COUNT(*) > 1;
```

Expected: zero rows. Resolve every duplicate through an approved remediation
procedure before migration.

### 2. Legacy wallet payouts without evidence

```sql
SELECT id, tenant_id, affiliate_account_id, amount, currency,
       approved_by_admin_id, approved_at
FROM affiliate_payouts
WHERE status = 'approved'
  AND payout_method = 'wallet_credit'
ORDER BY tenant_id, approved_at, id;
```

Expected: zero rows. The migration intentionally aborts otherwise. For every
row, establish from audited wallet history whether money was already credited.
Do not synthesize a ledger or change payout status without an approved,
reconciled remediation record.

### 3. Legacy external approval sign-off

```sql
SELECT payout_method, COUNT(*) AS payout_count, SUM(amount) AS amount
FROM affiliate_payouts
WHERE status = 'approved'
  AND payout_method IN ('bank_transfer', 'manual_cash')
GROUP BY payout_method;
```

Business/finance must confirm that legacy `approved` was the terminal paid
state. The migration converts these rows to `paid`. If approval did not mean
money was delivered, remediate those rows before migration.

### 4. Overlapping campaign audit

```sql
SELECT a.tenant_id, a.id AS campaign_a, b.id AS campaign_b
FROM affiliate_tier_campaigns a
JOIN affiliate_tier_campaigns b
  ON b.tenant_id = a.tenant_id
 AND b.id > a.id
 AND b.starts_at < a.ends_at
 AND b.ends_at > a.starts_at
WHERE a.status IN ('scheduled', 'active')
  AND b.status IN ('scheduled', 'active');
```

Expected: zero rows.

## Deployment Gate

1. Back up the platform database and the exact active `APP_KEY`; verify tested
   restore access to both.
2. Pause Affiliate writes/workers, external checkout creation, payment
   callbacks, and order refund actions. Drain old application and queue-worker
   instances so none can write the legacy plaintext bank columns after
   migration. Keep ordinary read traffic available.
3. Run and archive the `--phase=pre --json` result. Do not migrate if it exits
   non-zero.
4. Record finance sign-off for legacy external payout semantics.
5. Run migrations with the backed-up `APP_KEY`, then deploy/start the
   encryption-aware application and workers. Do not start new code before the
   encrypted columns exist, and do not restart old writers after the migration
   clears plaintext.
6. In each tenant's payment-provider settings, configure a new webhook secret
   and reviewed auth mode. Update the provider/gateway to sign callbacks with
   the same secret. Never reuse API keys as webhook secrets.
7. Reconcile every legacy refunded order into approved immutable evidence.
   Never synthesize a provider reference or wallet ledger.
8. Run and archive:

   ```sh
   docker compose exec platform-api \
     php artisan affiliate:production-preflight --phase=post --json
   ```

   Every blocker count must be zero before callbacks, refunds, or Affiliate
   workers resume. This includes zero plaintext bank payloads, zero
   undecryptable ciphertext rows, and a valid encrypted snapshot for every
   bank-transfer payout.
9. Configure or accept reviewed defaults:
   `AFFILIATE_PUBLIC_REFERRAL_CLICKS_PER_MINUTE=60` and
   `AFFILIATE_CUSTOMER_WRITES_PER_MINUTE=20`.
10. Resume scheduler/worker and confirm
   `affiliate-tier-campaigns:finalize --limit=25` is scheduled.
11. Run staging concurrency/load and the smoke matrix.
12. Resume production traffic only after evidence, smoke, alerting, and rollback
    ownership are signed off.

## Post-Migration Evidence

### Encrypted payout data

```sql
SELECT
  (SELECT COUNT(*) FROM affiliate_payouts
    WHERE bank_account_json IS NOT NULL) AS payout_plaintext_rows,
  (SELECT COUNT(*) FROM affiliate_accounts
    WHERE payout_profile_json IS NOT NULL) AS profile_plaintext_rows,
  (SELECT COUNT(*) FROM customers
    WHERE reward_payout_bank_account_json IS NOT NULL) AS customer_plaintext_rows,
  (SELECT COUNT(*) FROM affiliate_payouts
    WHERE payout_method = 'bank_transfer'
      AND (bank_account_encrypted IS NULL OR bank_account_encrypted = ''))
    AS bank_transfers_without_ciphertext;
```

Expected: every value is zero. Do not select, export, or log encrypted payload
contents. The post-migration preflight additionally decrypts each ciphertext
inside the application and blocks when the active `APP_KEY` cannot read it.

### Paid payout evidence

```sql
SELECT id, tenant_id, payout_method, status, payout_ledger_id,
       payment_reference, paid_by_admin_id, paid_at
FROM affiliate_payouts
WHERE status = 'paid'
  AND (
    paid_at IS NULL
    OR payment_reference IS NULL
    OR (payout_method = 'wallet_credit' AND payout_ledger_id IS NULL)
  );
```

Expected: zero rows.

### Wallet payout/ledger reconciliation

```sql
SELECT p.id, p.tenant_id, p.amount AS payout_amount,
       l.amount AS ledger_amount, p.currency, l.currency
FROM affiliate_payouts p
LEFT JOIN wallet_ledger l ON l.id = p.payout_ledger_id
WHERE p.status = 'paid'
  AND p.payout_method = 'wallet_credit'
  AND (
    l.id IS NULL
    OR l.entry_type <> 'credit'
    OR l.reference_type <> 'affiliate_payout'
    OR l.reference_id <> p.id
    OR l.amount <> p.amount
    OR l.currency <> p.currency
  );
```

Expected: zero rows.

### Tier history coverage

```sql
SELECT p.tenant_id, p.id, p.code
FROM affiliate_programs p
LEFT JOIN affiliate_tier_rate_history h
  ON h.tenant_id = p.tenant_id
 AND h.affiliate_program_id = p.id
WHERE p.tier_rank IS NOT NULL
GROUP BY p.tenant_id, p.id, p.code
HAVING COUNT(h.id) = 0;
```

Expected: zero rows.

### Authenticated payment-provider readiness

```sql
SELECT tenant_id, provider, status
FROM tenant_payment_provider_connections
WHERE status = 'active'
  AND (
    webhook_secret_encrypted IS NULL
    OR webhook_secret_encrypted = ''
  );
```

Expected: zero rows. Never select or export decrypted secrets.

### Refunded orders without immutable evidence

```sql
SELECT o.id, o.tenant_id, o.payment_method, o.status, o.payment_status,
       o.refunded_at
FROM orders o
LEFT JOIN order_refunds r
  ON r.tenant_id = o.tenant_id
 AND r.order_id = o.id
WHERE (o.status = 'refunded' OR o.payment_status = 'refunded')
  AND r.id IS NULL;
```

Expected: zero rows.

### Wallet refund/ledger reconciliation

```sql
SELECT r.id, r.tenant_id, r.order_id, r.amount, r.currency,
       r.wallet_ledger_id, l.reference_type, l.reference_id
FROM order_refunds r
LEFT JOIN wallet_ledger l ON l.id = r.wallet_ledger_id
WHERE r.method = 'wallet_refund'
  AND (
    l.id IS NULL
    OR l.entry_type <> 'reversal'
    OR l.reference_type <> 'order_refund'
    OR l.reference_id <> r.order_id
    OR l.amount <> r.amount
    OR l.currency <> r.currency
  );
```

Expected: zero rows.

### External refund/payment reconciliation

```sql
SELECT r.id, r.tenant_id, r.order_id, r.payment_id,
       r.external_reference, p.status AS payment_status
FROM order_refunds r
LEFT JOIN payments p ON p.id = r.payment_id
WHERE r.method IN ('manual_refund', 'original_payment')
  AND (
    r.external_reference IS NULL
    OR r.external_reference = ''
    OR p.id IS NULL
    OR p.status <> 'refunded'
    OR p.amount <> r.amount
    OR p.currency <> r.currency
  );
```

Expected: zero rows.

## Staging Smoke Matrix

- Register Affiliate; retry same idempotency key; reject changed payload.
- Submit/approve/reject store name and verify duplicate/cooldown behavior.
- Complete external referral purchase and delayed commission calculation.
- Reject unsigned, stale, malformed, and cross-provider payment callbacks;
  accept a valid signed callback exactly once.
- Change Tier rate after order payment and verify the original rate snapshot.
- Run concurrent payout requests against one available balance.
- Approve wallet payout twice and verify one ledger/outbox/notification.
- Approve external payout, mark paid, retry, and reject duplicate reference.
- Verify paid-only tenant/central report totals and settlement totals.
- Finalize fixed campaign at threshold boundaries, including demotion.
- Finalize ranking campaign with ties, cancellation/refund, and retry.
- Inject one commission-order failure and one campaign failure; verify later
  rows process, the command exits non-zero, and failed IDs reach monitoring.
- Reject paid-order cancellation. Verify wallet refunds create one ledger and
  external refunds require one unique provider/finance reference before
  commission reversal.
- Stop Affiliate worker during checkout and confirm order latency/success is
  unaffected; process the delayed commission after recovery.
- Exercise Back Office Tier, campaign, store review, payout, and report flows.

## Monitoring

- Alert on failed commission calculation and campaign finalization jobs.
- Treat any non-zero batch command exit as an incident even when some rows
  succeeded; include failed tenant/order/campaign IDs in structured logs.
- Alert on payout balance conflicts, duplicate payment references, and wallet
  ledger idempotency conflicts.
- Alert on webhook authentication failures, replay-window failures, unexpected
  provider-route mismatches, and callback rate limiting.
- Alert on refunded orders without refund evidence and refund/ledger/payment
  reconciliation mismatch.
- Alert when an external payout remains `approved` beyond the operating SLA.
- Reconcile paid attributed ticket counts against commission ticket snapshots.
- Monitor referral and customer-write `429` rates separately by tenant host.
- Track audit actions: `affiliate.tier.update`,
  `affiliate.tier_campaign.finalize`, `payout.created`, `payout.approved`,
  `payout.paid`, and `payout.rejected`.

## Rollback Notes

- Disable Affiliate writes before rolling application code or migration back.
- Do not drop rate history while delayed commission jobs can still run.
- Do not roll back after new paid payouts or Tier-rate changes without finance
  reconciliation and an approved recovery plan.
- Rejected payouts release balance by status; no wallet mutation is required.
- Campaign results, Tier history, commission transactions, payout evidence, and
  wallet ledger/order refund rows are financial records and must not be
  deleted.

## Verification Evidence

All backend commands used `APP_ENV=testing` and
`DB_DATABASE=newpaotang_test`.

- Affiliate security/concurrency/migrations/preflight, Tier campaigns,
  commissions, referral, checkout, authenticated webhooks, refunds, topup,
  reports, settlements, and provisioning: 78 passed, 1,543 assertions.
- Wallet/topup/reward/activity shared-ledger regression:
  53 passed, 1,212 assertions.
- Total non-overlapping backend evidence in this audit:
  131 tests, 2,755 assertions.
- PHP 8.4 container syntax checks pass for every changed security, financial,
  migration, command, and focused-test file.
- Back Office `npm run lint`, `npm test`, and `npm run build` pass.
- Back Office build retains existing non-blocking warnings for Nitro
  `compatibilityDate` and large client chunks.
- `git diff --check` passes.

## Remaining Unproven Gates

- Runtime duplicate and legacy-payout preflight.
- Runtime migration and post-migration reconciliation.
- Staging concurrency/load against deployment topology.
- Post-deploy Affiliate/checkout smoke and monitoring evidence.
