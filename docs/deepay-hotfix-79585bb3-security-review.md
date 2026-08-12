# DeePay Hotfix 79585bb3 Security and Deployment Review

Date: 2026-08-12

Reviewed commit: `79585bb3e0ace76bd727de7911fcb64365892328`

Status: **BLOCKED - DO NOT DEPLOY**

Owner: Coordinator / Backend / DevOps / QA

## Coordinator Remediation (2026-08-12)

The blockers in this review have been remediated in the current worktree. The
reviewed commit remains blocked; the remediation itself must still be reviewed
and committed before deployment.

### Security design and trust source

- DeePay is fail-closed by default with `webhook_auth_mode` set to
  `manual_reconciliation`. The current provider integration does not expose a
  documented signature or authenticated transaction-status lookup, so an
  ordinary DeePay callback cannot credit a wallet.
- An unresolved `initiated`, `invalid_response`, `transport_failed`, or
  `outcome_unknown` bill cannot learn a provider transaction reference from an
  unsigned callback. It remains unresolved for audited manual reconciliation.
- The callback verification path can be enabled only after configuring a
  cryptographic `hmac_sha256` or token secret outside the current DeePay BO
  flow. Even then, the payload must match the existing bill attempt, provider
  transaction reference, all four merchant references, amount, `THB` currency,
  tenant/top-up/payment ownership, and an explicit paid status/status code.
- A callback with no explicit success status is rejected. Ledger idempotency
  remains defense in depth and is not treated as authentication.

### Correlation and race policy

- Payment lookup and authentication select only `bill`/`billCredit` attempts.
  A `cancel` attempt cannot supply payment references or be updated as a paid
  bill.
- An authenticated callback may update only the matching bill attempt.
- If payment success and cancellation overlap, the state committed first wins.
  A late cancellation result cannot replace a succeeded Payment/Top-up; its
  attempt becomes `superseded` and the cancellation returns a conflict.

### Deployment order

The production workflow now follows this order:

1. Build and push images.
2. Render and client-validate manifests without applying them.
3. Run `php artisan migrate --force` in an isolated Job using the new Platform
   image and wait for successful completion.
4. Run pre-rollout translation/RBAC/Support migration jobs when requested.
5. Apply the rendered manifests, which starts the new workload rollouts.
6. Wait for every Platform workload and verify image parity before smoke tests.

A migration or pre-rollout job failure therefore prevents all new Platform
workloads from receiving traffic. The migration remains additive. No runtime
database command was run while implementing this remediation.

### Verification

Focused tests ran with `DB_DATABASE=newpaotang_test`:

```text
23 tests passed
535 assertions passed
```

Coverage includes unsigned and arbitrary-reference callback rejection, missing
success status, amount mismatch, exact-once signed callback credit, bill versus
cancel attempt correlation, unknown-outcome immutability, cancellation race,
provider diagnostics/idempotency, and payment-settings mode. Back Office lint,
PHP syntax, workflow YAML parsing, migration-before-rollout order, and
`git diff --check` also passed.

### Rollback and controlled production verification

- Application rollback may use the previous image because the new table is
  additive; do not roll back or drop the migration during an incident.
- Keep DeePay callbacks in manual reconciliation mode until DeePay provides a
  documented cryptographic callback contract or authenticated inquiry API.
- Do not run a real provider bill or deploy this work without explicit owner
  approval. A controlled verification must confirm the additive migration ran
  first, unsigned callbacks remain rejected, one approved provider transaction
  credits exactly once, and diagnostics contain no API key, QR/base64, access
  token, or raw provider body.

## Executive Summary

Commit `79585bb3` adds useful DeePay diagnostics, durable provider-attempt records, idempotency reservation, shortened DeePay references, and moves outbound provider calls outside the main database transaction.

The commit must not be deployed in its current form because it introduces a critical wallet-credit vulnerability. An unsigned public DeePay callback can supply an arbitrary provider transaction reference for an unresolved payment attempt. The application binds that value to the payment, treats a callback without an explicit status as successful, and credits the customer wallet.

Two additional release blockers were found:

1. The production workflow starts rolling out the new API image before running the migration that creates `payment_provider_attempts`.
2. Webhook authentication selects the latest provider attempt without restricting it to `bill` or `billCredit`, so a later cancellation attempt can break correlation for a legitimate payment callback.

Focused tests pass, but one of the new tests explicitly verifies the unsafe unsigned-callback behavior. Passing tests therefore do not make this commit production-safe.

## Review Scope

Primary files reviewed:

- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php`
- `apps/platform-api/app/Modules/Commerce/Services/PaymentProviders/DeepayKbankPaymentProvider.php`
- `apps/platform-api/app/Models/PaymentProviderAttempt.php`
- `apps/platform-api/database/migrations/2026_08_12_000001_create_payment_provider_attempts.php`
- `apps/platform-api/app/Shared/Idempotency/IdempotencyService.php`
- `apps/platform-api/tests/Feature/CustomerTopupTest.php`
- `apps/platform-api/tests/Feature/PaymentWebhookTest.php`
- `.github/workflows/production-deploy.yml`

The unrelated Back Office operations changes included in the same commit were not fully reviewed as part of this DeePay security assessment.

## Production State at Review Time

```text
Kubernetes context: do-sgp1-lotto80
Namespace: newpaotang-prod
Platform API image: d36dc50880a1
Back Office image: d36dc50880a1
Customer image: d3aaf9502444
payment_provider_attempts migration: not applied
payment_provider_attempts table: absent
```

All production replicas were ready. Commit `79585bb3` was not running on production when this review was completed, so the newly introduced callback vulnerability was not yet exposed by the production workloads.

No Kubernetes resource, production database record, payment, top-up, or wallet balance was changed during this review.

## Finding 1: Critical Unsigned Callback Can Credit a Wallet

Severity: **P0 / Critical**

Deployment impact: **hard release blocker**

### Vulnerable flow

The top-up webhook is public and protected only by request throttling:

- `apps/platform-api/routes/api.php:1098`

DeePay uses `trusted_provider` callback mode rather than HMAC or token authentication:

- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php:37`

When `payments.provider_reference` is empty, the new authenticator accepts any non-empty callback `partnerTxnUid` if the related attempt has one of these states:

```text
initiated
invalid_response
transport_failed
outcome_unknown
```

Relevant code:

- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php:80`
- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php:87`
- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php:90`

The callback still needs `reference1`, but this value is derived from the customer-visible Top-up ID and truncated to 20 characters. `reference3` is optional during verification:

- `apps/platform-api/app/Modules/Commerce/Services/PaymentProviders/DeepayKbankPaymentProvider.php:303`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3527`
- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php:108`

After this weak correlation passes, the application binds the arbitrary callback transaction reference to the payment and marks unresolved attempts successful:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:2417`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3264`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3280`

A callback without an explicit payment status is treated as successful whenever `partnerTxnUid` is non-empty and `reference2` equals `wallet`:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3323`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3326`

The successful callback then posts a wallet ledger credit and marks the Top-up and Payment successful:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3163`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3179`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3180`

### Practical impact

An authenticated customer can see their own Top-up ID through the normal customer Top-up API. If that Top-up has an unresolved provider attempt, a forged unauthenticated callback can provide:

```text
an arbitrary non-empty partnerTxnUid
the provider reference1 derived from the Top-up ID
reference2=wallet
```

The current flow can accept the callback as paid without cryptographic proof or a server-to-server transaction verification and credit the customer's wallet for the chosen Top-up amount.

This is a direct financial-integrity issue. Throttling, ULID entropy, and ledger idempotency do not fix it. Ledger idempotency prevents repeated credit of the same Top-up, but it does not prevent the first fraudulent credit.

### Test evidence

The new test demonstrates the unsafe behavior. It simulates a failed connection, then sends an unsigned callback containing references but no payment status. The callback is accepted and the wallet balance increases:

- `apps/platform-api/tests/Feature/CustomerTopupTest.php:538`
- `apps/platform-api/tests/Feature/CustomerTopupTest.php:573`
- `apps/platform-api/tests/Feature/CustomerTopupTest.php:579`
- `apps/platform-api/tests/Feature/CustomerTopupTest.php:594`

This test currently treats the vulnerability as expected behavior and must be replaced.

### Required remediation

1. Never bind a missing `payment.provider_reference` from an unauthenticated callback solely because the attempt is unresolved.
2. Never credit a wallet from a callback whose provider transaction reference was not established by a trusted source.
3. Require one of these trust mechanisms before finalization:
   - a DeePay-provided HMAC/signature or callback token;
   - a server-to-server DeePay transaction-status lookup that verifies transaction ID, merchant account, amount, currency, `reference1`, `reference2`, tenant reference, and paid status; or
   - another cryptographically authenticated provider mechanism documented by DeePay.
4. If DeePay provides no signature or status lookup, keep unresolved attempts in `outcome_unknown` and require audited manual reconciliation. Do not credit automatically.
5. Do not treat a callback with no explicit success status as paid unless the verified DeePay contract requires that exact format and the callback has already passed strong authentication.
6. Preserve ledger idempotency as defense in depth, not as callback authentication.

IP allowlisting may reduce exposure but must not be the only financial authentication control unless DeePay formally guarantees stable exclusive source ranges and the infrastructure verifies the real source address correctly.

## Finding 2: API Image Rolls Out Before Required Migration

Severity: **P1 / High**

Deployment impact: **release blocker**

The new API code reads and writes `payment_provider_attempts`, and the table is introduced by:

```text
2026_08_12_000001_create_payment_provider_attempts
```

The production workflow currently applies manifests and changes all workload images before starting the migration job:

- `.github/workflows/production-deploy.yml:240`
- `.github/workflows/production-deploy.yml:243`
- `.github/workflows/production-deploy.yml:253`
- `.github/workflows/production-deploy.yml:276`

Changing a Deployment image starts rollout immediately. New Platform API pods can become ready and receive traffic before the migration job creates the table. Top-up creation, webhook processing, and affected BO queries can fail with a missing-table database exception during this window.

### Required remediation

1. Build and push the new image.
2. Run the additive Platform migration job using the new image.
3. Wait for migration completion and fail the workflow if it does not complete.
4. Only then apply or update Platform API, worker, scheduler, and reverb images.
5. Wait for rollout and verify image parity.
6. Run smoke checks after rollout.

Ensure the earlier `Apply base manifests` step cannot independently change Deployment images before migration. Rendering manifests with the new image and applying them before the migration would preserve the same race even if `kubectl set image` is moved.

The migration must remain additive and non-destructive. Use only:

```sh
php artisan migrate --force
```

Never use `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe`, schema reload, or reseeding against production.

## Finding 3: Cancellation Attempt Can Break Payment Callback Correlation

Severity: **P1 / High**

Deployment impact: **release blocker for reliable reconciliation**

Webhook authentication loads the latest payment-provider attempt without filtering by operation:

- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php:80`
- `apps/platform-api/app/Modules/Commerce/Services/PaymentWebhookAuthenticator.php:83`

A cancellation attempt is stored against the same Payment but its `provider_reference1` through `provider_reference4` values are null:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:1165`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:1177`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:1180`

If a cancellation attempt becomes the latest attempt, authentication can compare an incoming bill callback against the wrong attempt. The fallback uses the full Top-up ID while DeePay bill creation sends a shortened 20-character `reference1`. A legitimate payment callback can therefore be rejected.

`bindProviderReferenceFromTrustedCallback()` also updates every unresolved attempt for the Payment without filtering operation. If a callback is accepted, it can incorrectly mark an unresolved cancellation attempt as a successful payment callback:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3287`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3289`

### Required remediation

1. Payment/top-up callback correlation must select only the original `bill` or `billCredit` attempt.
2. Cancellation attempt state must never supply payment creation references.
3. Payment callbacks must update only the matching bill attempt.
4. Cancellation callbacks or responses must update only the matching cancel attempt.
5. Add race tests for payment success arriving before, during, and after cancellation attempts.

## Positive Changes That Should Be Preserved

The following changes are directionally correct and should remain after remediation:

- Outbound DeePay bill and cancel HTTP calls are moved outside the main database transaction.
- A durable `payment_provider_attempts` lifecycle is introduced.
- Request ID, safe provider code/message, HTTP status, latency, and classification are retained.
- API keys and QR payloads are excluded from provider-attempt diagnostics.
- Customer-facing errors no longer expose raw provider messages.
- An idempotency reservation exists before the external call.
- Unknown outcomes are not blindly retried with the same customer request.
- DeePay reference values are capped at 20 characters, addressing the likely reference-length rejection found during production investigation.
- BO operations can search Top-ups by platform request ID.
- Platform image-parity verification now covers API, workers, scheduler, and reverb.

## Verification Completed

Focused tests were run against the allowed test database using the protected pattern:

```sh
docker compose run --rm \
  -e APP_ENV=testing \
  -e DB_DATABASE=newpaotang_test \
  platform-api php artisan test --env=testing \
  --filter='CustomerTopupTest|PaymentWebhookTest'
```

Result:

```text
13 tests passed
281 assertions passed
Duration: 24.00 seconds
```

The tests confirm the new attempt lifecycle and idempotency behavior, but they also encode the P0 unsigned-callback behavior as a passing case. Additional security tests are required before approval.

## Required Security Tests

1. An unsigned callback cannot bind a missing provider transaction reference.
2. An unsigned callback for `initiated`, `invalid_response`, `transport_failed`, or `outcome_unknown` cannot credit a wallet.
3. An arbitrary `partnerTxnUid` is rejected even when `reference1` and `reference2` match.
4. A callback without an explicit success status cannot credit a wallet unless the strongly authenticated provider contract explicitly allows that payload.
5. A signed callback or verified server-to-server lookup must match amount, currency, tenant, customer payment, Top-up ID, merchant reference, and paid state.
6. A forged callback leaves Payment, Top-up, provider attempt, wallet balance, and ledger unchanged.
7. A valid callback credits exactly once.
8. Duplicate valid callbacks do not post a second ledger entry.
9. A bill callback selects only a `bill` or `billCredit` attempt.
10. A cancellation attempt cannot replace bill references during callback authentication.
11. A payment callback arriving during an unresolved cancellation is handled according to a documented state policy.
12. Provider credentials, QR/base64 data, access tokens, and raw provider payloads remain absent from diagnostics and logs.

All destructive setup must run only against `newpaotang_test`.

## Release Acceptance Criteria

- P0 callback forgery is no longer possible.
- No callback can credit a wallet without cryptographic authentication or trusted server-to-server transaction verification.
- Missing provider references remain unresolved until verified; they are not learned from an untrusted callback.
- Payment and cancellation attempts are correlated by operation and immutable reference identity.
- The additive migration completes before any new API workload receives traffic.
- Migration failure prevents rollout of all new Platform workloads.
- Focused Top-up, webhook, idempotency, callback-security, cancellation-race, and migration-order tests pass.
- Production deployment uses no destructive database commands.
- A controlled production verification is performed only after explicit user approval.
- The production verification confirms no secret, QR payload, or raw provider body is exposed.

## Coordinator Task Prompt

```text
Remediate the blocked DeePay hotfix reviewed in:
docs/deepay-hotfix-79585bb3-security-review.md

Reviewed commit:
79585bb3e0ace76bd727de7911fcb64365892328

Release status:
BLOCKED - DO NOT DEPLOY

Required fixes:
1. Remove the ability for an unsigned callback to bind an arbitrary provider transaction reference to an unresolved payment.
2. Prevent all wallet credit unless the callback is cryptographically authenticated or the transaction is verified server-to-server with DeePay.
3. Do not treat a callback with no explicit status as successful without a strongly authenticated documented provider contract.
4. Correlate bill callbacks only with bill/billCredit attempts; never use cancellation attempts as payment references.
5. Update only the matching operation attempt during callback reconciliation.
6. Reorder production deployment so the additive migration succeeds before any new Platform image rollout begins.
7. Replace the current test that accepts an unsigned post-timeout callback with rejection and trusted-verification tests.

Preserve:
- durable provider attempts;
- safe structured diagnostics;
- request-ID lookup;
- outbound HTTP outside the long DB transaction;
- idempotency reservation and no blind retries;
- 20-character provider references;
- secret/QR redaction; and
- image-parity verification.

Constraints:
- Do not deploy commit 79585bb3 as currently written.
- Do not replay the failed production Top-up.
- Do not create a real DeePay bill without explicit user approval.
- Do not expose x-api-key, encrypted credentials, QR/base64 data, access tokens, or raw provider payloads.
- Use only additive migrations.
- Run destructive test setup only against newpaotang_test.

Return to QA with:
- security design and trust source;
- exact callback verification contract;
- migration/deployment order;
- rollback notes;
- focused security and race-test results;
- redacted diagnostics evidence; and
- an explicitly approved controlled production verification plan.
```
