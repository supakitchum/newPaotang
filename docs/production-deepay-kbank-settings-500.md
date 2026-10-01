# Production DeePay KBank Settings HTTP 500

Date: 2026-08-03

Status: local application fix implemented and verified on `newpaotang_test`; deployment and production verification are still pending. No Kubernetes resource or production database record was changed.

## Summary

Saving the DeePay KBank payment-provider connection from the Siamblend partner back office returns HTTP 500.

Affected page:

```text
https://bo.siamblend.com/admin/tenant/payment-provider-settings
```

Affected endpoint:

```text
PUT /api/v1/admin/tenant/payment-settings/deepay-kbank
```

The request reaches the Platform API successfully. The failure occurs inside Laravel while inserting `tenant_payment_provider_connections.metadata_json`.

## Production Environment

```text
Kubernetes context: do-sgp1-lotto80
Namespace: newpaotang-prod
Platform API image: registry.digitalocean.com/lotto80-registry/newpaotang-platform-api:79d0ae11049d
Application commit: 79d0ae11049dd20df726f7c6c43c7c5f6cabec5a
Database: lottery80
Tenant: ten_2637f84274a214c56e63
Partner domain: siamblend.com
Back-office domain: bo.siamblend.com
```

## Evidence

Production ingress logs recorded repeated HTTP 500 responses for the endpoint around 13:06-13:07 Asia/Bangkok on 2026-08-03.

Example request IDs:

```text
req_mscttnxr_47mvube8
req_mscttq4h_zwsg294d
req_msctu0gf_02ixfk3h
req_msctu6h7_fash47g0
req_msctuat4_ew76mvjn
```

Laravel reported:

```text
production.ERROR: Array to string conversion
Connection: pgsql
Database: lottery80
SQL operation: insert into "tenant_payment_provider_connections"
Failing field: metadata_json
```

Relevant stack frames:

```text
Illuminate\Database\Connection->bindValues()
Illuminate\Database\Query\Builder->updateOrInsert()
App\Modules\AdminOperations\Services\TenantPaymentSettingsService.php:167
App\Modules\AdminOperations\Http\Controllers\TenantPaymentSettingsController.php:87
```

The API pods remained ready with zero restarts. API health endpoints and the Siamblend back-office route returned HTTP 200, so this is not an ingress, DNS, certificate, pod-capacity, or general availability problem.

## Root Cause

In `TenantPaymentSettingsService::saveDeepayKbankConnection()`, the service calls:

```php
TenantPaymentProviderConnection::query()->updateOrInsert(...)
```

The values passed to that query include a PHP array:

```php
'metadata_json' => [
    ...$metadata,
    'callback_path' => $this->providerCallbackPath($provider),
    'webhook_auth_mode' => $webhookAuthMode,
],
```

`updateOrInsert()` is forwarded to the query builder and does not apply the model's `metadata_json => array` Eloquent cast. PDO therefore receives an array as a SQL binding and throws `Array to string conversion`.

Relevant files:

- `apps/platform-api/app/Modules/AdminOperations/Services/TenantPaymentSettingsService.php:167`
- `apps/platform-api/app/Models/TenantPaymentProviderConnection.php:34`
- `apps/platform-api/database/migrations/2026_06_24_000001_create_tenant_payment_provider_connections.php:21`

## Database Verification

Read-only production checks confirmed:

```text
2026_07_24_000003_add_payment_webhook_authentication: applied
Siamblend deepay_kbank connection row count: 0
```

The required migration is present. This is not a missing-column or pending-migration issue.

The exception occurs inside a database transaction before the audit write. Each failed request was rolled back, so no partial DeePay connection record was left in production.

## Impact

- Siamblend administrators cannot create the DeePay KBank provider connection.
- Both `active` and `inactive` save attempts can fail because both execute the same insert path.
- Tenants that do not already have a provider connection are expected to hit the same defect.
- Existing connections may also fail when updated because the same array binding is used by the update branch.
- Checkout and ordering paths that do not use this settings write endpoint are not directly affected by this exception.

## Recommended Remediation

Use one of these approaches:

1. Minimal change: JSON-encode `metadata_json` before passing it to `updateOrInsert()` using `json_encode(..., JSON_THROW_ON_ERROR)`.
2. Model-based change: replace the query-builder operation with an Eloquent write method that applies model casts, while preserving the unique `(tenant_id, provider)` behavior and concurrency safety.

The minimal change has the smallest behavioral surface. Do not change existing encrypted credential handling as part of this fix unless separately reviewed.

## Implemented Remediation

`TenantPaymentSettingsService::saveDeepayKbankConnection()` now serializes `metadata_json` with `json_encode(..., JSON_THROW_ON_ERROR)` before passing the value to `updateOrInsert()`. This preserves the existing atomic upsert and encrypted credential behavior while ensuring PostgreSQL receives a valid JSON string.

Focused feature coverage verifies:

- create and update both return HTTP 200;
- metadata is stored as valid JSON;
- callback path and authentication mode survive round trips;
- a blank API key on update preserves the existing encrypted value;
- invalid active configuration returns HTTP 422 without writing a row; and
- the plaintext API key is absent from the API response.

Verification command:

```sh
docker compose run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=deepay_kbank
```

Result: focused DeePay settings tests passed on `newpaotang_test`.

## DeePay Callback Trust Policy

The HTTP 500 and webhook authentication are separate concerns. DeePay is an external provider and the available integration contract does not provide a shared webhook secret or a callback signature that this application can configure.

Following the approved runtime policy, `deepay_kbank` callbacks use `trusted_provider` mode and do not require a webhook secret. HMAC and token verification remain enabled for other providers.

An unsigned DeePay callback is accepted only when all of these values match an existing transaction created by this application:

- the provider transaction ID equals `payments.provider_reference`;
- `reference1` equals the related Topup ID;
- `reference2` is `wallet`;
- Payment, Topup, tenant, and provider relationships are consistent; and
- `reference3`, when supplied, equals the transaction tenant.

Existing callback idempotency and wallet-ledger idempotency remain active, so duplicate callbacks cannot credit the same Topup twice. This policy verifies transaction correlation but does not cryptographically prove that the sender is DeePay. If DeePay later provides signing or transaction-status verification, production should move to that stronger mechanism.

## Required Tests

Add focused feature coverage for the authenticated tenant endpoint:

1. Creating a new DeePay KBank connection returns HTTP 200 and stores valid JSON metadata.
2. Updating an existing connection returns HTTP 200 and preserves existing metadata keys.
3. `callback_path` and `webhook_auth_mode` are persisted and returned correctly.
4. Leaving the API key blank on an existing connection preserves the existing encrypted value.
5. Validation failures return the expected 422 response and do not write a row.
6. The API response and logs never expose the plaintext API key.

Run tests only against `newpaotang_test`. Do not run `migrate:fresh`, `db:wipe`, reseeding, or destructive verification against the protected runtime or production database.

## Acceptance Criteria

- Saving a new DeePay KBank connection from the Siamblend BO succeeds without HTTP 500.
- A valid row exists with JSON metadata for the Siamblend tenant after an explicitly approved production verification save.
- Re-saving the connection updates the same row and does not create a duplicate.
- The payment settings read endpoint returns the saved status and webhook authentication mode.
- Platform API logs contain no `Array to string conversion` for this endpoint.
- Focused backend tests pass on `newpaotang_test`.

## Deployment Notes

This fix should require an application image deployment only. No schema migration is expected.

Do not perform a production save or any database write for verification without the user's explicit approval. Production verification should be performed through the normal authenticated BO workflow after deployment.
