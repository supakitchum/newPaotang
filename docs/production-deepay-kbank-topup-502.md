# Production DeePay KBank Top-up HTTP 502 and Missing Provider Evidence

Date: 2026-08-12

Status: root cause confirmed from the DeePay request contract and remediation implemented locally. Production remains unchanged until the additive migration and API image are deployed and an explicitly approved controlled top-up is completed.

Owner: Coordinator / application development

## Summary

A Siamblend customer attempted to create a QR top-up on production. The request reached the Platform API, but the customer received HTTP 502 and no top-up or payment record was created.

The DeePay endpoint was reachable and responded in approximately half a second. A validation-only probe using the configured production credential confirmed that DeePay accepts the API key. This rules out DNS, TLS, endpoint availability, timeout, and an invalid API key at the time of investigation.

The exact HTTP status and response body returned by DeePay for the original failed request cannot be recovered. The provider adapter returns those details in memory, but `CommerceService` discards the provider HTTP status and response payload on failure. Nothing is persisted, and non-exception provider responses are not logged. This is the primary observability defect that must be fixed before the request-specific DeePay rejection can be diagnosed reliably.

## Confirmed Root Cause

The DeePay KBank bill endpoints validate `reference1`, `reference2`, `reference3`, and `reference4` as strings with a maximum length of 20 characters. The Platform API previously sent the full generated top-up ID as `reference1` and the full tenant ID as `reference3`; both can exceed 20 characters. DeePay therefore rejects the bill request during validation before creating a transaction.

The remediation now sends deterministic 20-character provider references and stores their durable mapping to the full platform top-up/payment IDs. Callback lookup and authentication use that mapping while retaining compatibility with previously created records.

The original provider response remains unrecoverable, so the exact body for the 09:05 request is still unknown. The contract violation is independently confirmed and matches the observed immediate HTTP failure.

## Implemented Remediation

- Added additive `payment_provider_attempts` storage with request ID, safe references, classification, provider status/code/message, and latency.
- Reserved idempotency before the external request and persisted initiating Topup, Payment, and attempt rows in a short transaction.
- Moved the DeePay HTTP request outside the database transaction and finalized the result in a second short transaction.
- Added short DeePay references, callback mapping, and callback authentication support.
- Classified rejected, invalid, transport, and unknown outcomes without blind retries; unresolved outcomes remain processing and cannot be cancelled into a duplicate flow.
- Sanitized and bounded provider diagnostics; API keys, raw responses, and QR/base64 data are excluded from attempt records, logs, and admin diagnostics.
- Added tenant BO lookup by `request_id` through the existing top-up API and a sanitized provider-attempt detail.
- Added localized safe customer errors with the platform request ID.

Local verification used `newpaotang_test` only: 14 focused tests passed with more than 330 assertions across customer top-ups, tenant top-up operations, provider rejection/invalid/unknown outcomes, idempotency, transaction boundaries, and successful webhook wallet crediting.

## Affected Environment

```text
Kubernetes context: do-sgp1-lotto80
Namespace: newpaotang-prod
Database: lottery80
Tenant: ten_2637f84274a214c56e63
Tenant code: siamblend
Provider: deepay_kbank
Provider endpoint: https://ks-intershop.com/api/v1/payments/kbank
Provider timeout: 15 seconds
Platform API image: d36dc50880a1
```

The provider connection is active. Its API key is encrypted at rest and was not printed, copied, or included in this report.

## Production Incident

All times below use Asia/Bangkok unless UTC is shown explicitly.

```text
Local time:  2026-08-12 09:05:12+07
UTC time:    2026-08-12 02:05:12Z
Request ID:  req_1786500312201541_845876c6ce7b6a1a
Method:      POST
Path:        /api/v1/customer/topups
Client:      Dart/3.12 (dart:io)
API status:  502
Response:    185 bytes
Total time:  0.584 seconds
Upstream:    0.583 seconds
```

Ingress evidence:

```text
POST /api/v1/customer/topups HTTP/1.1
status=502 response_bytes=185
upstream_status=502 upstream_time=0.583
request_id=req_1786500312201541_845876c6ce7b6a1a
```

The Platform API pod also recorded the same request as HTTP 502. API health probes remained HTTP 200 and all replicas were available, so this was not a general API, ingress, pod-capacity, or cluster outage.

## Provider Probes

The following probes were deliberately unable to create a bill. They were used only to separate network and credential failures from request-specific provider behavior.

### Endpoint reachability

A GET request to the POST-only bill endpoint returned immediately:

```text
HTTP 405
The GET method is not supported for this route. Supported methods: POST.
```

This confirms DNS, TLS, routing, and application reachability from the production Platform API pod.

The 405 body exposed a Laravel stack trace and server filesystem path from the external service. This should be reported to DeePay as a separate provider security and production-hardening concern. It is not the cause of the top-up failure.

### Request without an API key

An empty POST without a key returned:

```json
HTTP 401
{
  "code": 1000,
  "message": "Please Login."
}
```

### Validation-only request with the production key

An empty POST using the configured production key returned:

```json
HTTP 400
{
  "amount": [
    "The amount field is required."
  ]
}
```

This result confirms that the configured key was decrypted successfully and accepted by DeePay. The request omitted the amount and every reference field, so it could not create a payment bill.

This HTTP 400 response is probe evidence. It is not the raw response from the original 09:05 incident.

## Database and Log Evidence

Read-only production checks found:

```text
Deepay connection status: active
verified_at: null
last_tested_at: null
last_test_status: null
last_error: null
topup_requests created during the incident window: 0
payments created during the incident window: 0
matching provider exception in stderr logs: none
Laravel log files inside the pod: none
```

The absence of an exception plus the 0.583-second response is consistent with DeePay returning an HTTP response promptly rather than a connection timeout or transport exception. The application response is most consistent with `payment_provider_failed`, but the original provider status and body were not retained, so the exact DeePay error must not be claimed as confirmed.

## Root Cause of the Missing Evidence

`DeepayKbankPaymentProvider::createTopupBill()` captures the provider HTTP status and response in its return value:

- `apps/platform-api/app/Modules/Commerce/Services/PaymentProviders/DeepayKbankPaymentProvider.php:43`
- `apps/platform-api/app/Modules/Commerce/Services/PaymentProviders/DeepayKbankPaymentProvider.php:53`

For a non-success response it returns:

```php
[
    'error_code' => 'payment_provider_failed',
    'message' => $this->errorMessage($data),
    'http_status' => $response->status(),
    'payload' => ['request' => $payload, 'response' => $data],
]
```

`CommerceService::createCustomerTopup()` calls the provider inside a database transaction. On failure it keeps only `error_code` and `message`:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:686`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:705`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:708`

The following fields are discarded:

```text
provider HTTP status
sanitized provider response
generated topup ID used as reference1
provider request context
provider latency
```

The function returns before inserting `payments`, `topup_requests`, or an idempotency response. Because an ordinary HTTP 4xx/5xx response does not throw, `report($exception)` is not called either.

`CustomerCommerceController` then maps the application error to an outer HTTP 502 response:

- `apps/platform-api/app/Modules/Commerce/Http/Controllers/CustomerCommerceController.php:302`

The provider call also occurs while a database transaction is open. This unnecessarily keeps database transaction scope around an external network request and makes a failure leave no durable attempt record.

## Confirmed and Unconfirmed Findings

### Confirmed

- The customer request reached production and received HTTP 502.
- Platform API, customer proxy, ingress, and Kubernetes workloads remained healthy.
- DeePay was reachable from the production pod.
- The configured DeePay API key was active and accepted by the provider during the validation probe.
- No top-up or payment row was created for the failed attempt.
- The original provider status and body are not available in application logs or the database.

### Not yet confirmed

- The exact HTTP status returned by DeePay for the original request.
- The exact provider message shown to the customer.
- Whether DeePay rejected amount, reference formatting, account configuration, KBank configuration, or another request-specific condition.
- Whether DeePay returned a success status with a response shape unsupported by the adapter.

Do not rotate the API key or change Kubernetes networking based on this incident alone; current evidence does not identify either as faulty.

## Required Remediation

### 1. Add safe structured provider diagnostics

Record one structured event for every DeePay attempt with:

```text
request_id
provider_attempt_id
tenant_id
provider
operation (bill, billCredit, cancel)
channel
topup_id/reference1
application_error_code
provider_http_status
safe provider code/message
response classification
latency_ms
attempted_at/completed_at
```

Never log or persist:

```text
x-api-key
encrypted credential values
QR image or base64 QR payload
full request/response payloads
customer access tokens
unredacted personal data
```

Provider text must be length-bounded and sanitized before it enters logs or the database.

### 2. Preserve a durable provider-attempt record

Add an additive provider-attempt model/table or an equivalent durable audit mechanism. A failed outbound call must remain traceable even when no successful payment or top-up exists.

The record should use a state machine such as:

```text
initiated -> succeeded
initiated -> provider_rejected
initiated -> invalid_response
initiated -> transport_failed
initiated -> outcome_unknown
```

Store only a sanitized response summary. Link it to the platform request ID and idempotency identity without storing the plaintext idempotency key if a hash is sufficient.

### 3. Remove the provider call from the long database transaction

Do not hold the main database transaction open while waiting for DeePay. Establish durable initiating state, commit it, perform the provider call, then finalize success or failure in a short transaction.

The design must account for an unknown outcome: a network interruption after DeePay creates a bill must not cause an automatic duplicate bill. Do not enable blind HTTP retries unless DeePay documents an idempotent request key or a safe status lookup by `reference1`.

### 4. Standardize the customer error response

- Return a safe localized message and the platform `request_id` to the customer.
- Do not expose arbitrary provider stack traces or raw response bodies.
- Keep the provider's safe code/message available to authorized BO operations staff.
- Preserve distinct application codes for provider rejection, invalid response, timeout, and unknown outcome.

### 5. Implement a supported connection test

Use a documented non-billing DeePay authentication or status endpoint if one exists. Update `verified_at`, `last_tested_at`, `last_test_status`, and `last_error` with a sanitized result.

If DeePay provides no non-billing test endpoint, do not use bill creation as an automatic health check. Document that limitation and rely on configuration validation plus controlled transaction testing.

### 6. Confirm the provider contract

Obtain the current DeePay contract for:

- required fields and amount units;
- minimum and maximum amounts;
- reference field length and allowed characters;
- success and error response schemas;
- transaction lookup by merchant reference;
- duplicate handling and idempotency guarantees;
- webhook authentication; and
- bill cancellation behavior.

Update the adapter and tests against that contract. Do not infer production behavior only from validation probes.

## Required Tests

1. DeePay HTTP 400 records `provider_rejected`, provider status, safe message, latency, and request ID.
2. DeePay HTTP 401 is classified separately without exposing the API key.
3. DeePay HTTP 200 without QR or transaction reference records `invalid_response`.
4. Timeout and connection failure record `transport_failed` or `outcome_unknown` as appropriate.
5. A successful response creates exactly one payment and top-up with the expected provider reference.
6. Repeating a customer idempotency key never creates a second DeePay bill.
7. No API key, encrypted credential, QR base64 value, access token, or full provider payload appears in logs or persisted diagnostics.
8. Provider response text is sanitized and length-bounded.
9. The customer receives a safe error plus the same request ID visible in provider-attempt diagnostics.
10. External HTTP execution is outside the long database transaction.
11. Unknown provider outcomes are not retried automatically.
12. Existing successful callback and wallet-credit idempotency remain unchanged.

Run database-reset or destructive tests only with:

```sh
docker compose run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

Never run destructive test setup against the runtime or production database.

## Acceptance Criteria

- The next failed DeePay top-up can be traced by request ID to its sanitized provider HTTP status, safe response code/message, and latency.
- A failed provider call leaves a durable diagnostic attempt without creating a successful payment or crediting a wallet.
- A successful customer request creates exactly one DeePay bill, payment, and top-up.
- Unknown outcomes cannot produce an automatic duplicate bill.
- Customer-facing errors remain safe and include a correlation request ID.
- Production credentials and QR data never appear in logs, API errors, or diagnostic records.
- Focused provider, top-up, idempotency, webhook, and transaction-boundary tests pass against `newpaotang_test`.
- Deployment and rollback do not modify or delete existing payment, top-up, or wallet records.

## Deployment Notes

If a provider-attempt table is added, deploy its additive migration before the API image. Do not use `migrate:fresh`, `db:wipe`, reseeding, or any destructive migration command.

After deployment, verify diagnostics with an explicitly approved customer test top-up. Do not create a real DeePay bill solely for troubleshooting without user approval. Confirm that logs and records contain no secret or QR payload before closing the incident.

The original response cannot be recovered by deploying the fix. The fix makes the next failure diagnosable.

## Coordinator Task Prompt

```text
Fix the DeePay top-up failure observability and transaction-boundary defects documented in:
docs/production-deepay-kbank-topup-502.md

Production incident:
- 2026-08-12 09:05:12 Asia/Bangkok
- request_id req_1786500312201541_845876c6ce7b6a1a
- POST /api/v1/customer/topups -> HTTP 502 in 0.583 seconds
- no payment/top-up row and no recoverable raw provider response
- provider endpoint reachable and production API key accepted by a non-billing validation probe

Required scope:
1. Add safe structured diagnostics and a durable provider-attempt lifecycle.
2. Preserve provider HTTP status, sanitized response code/message, request ID, and latency.
3. Move outbound provider HTTP execution outside the long database transaction.
4. Handle unknown outcomes without blind retries or duplicate bills.
5. Return safe correlated customer errors and expose sanitized diagnostics only to authorized operations staff.
6. Confirm and test the current DeePay request/response contract.

Constraints:
- Never log or persist x-api-key, encrypted credentials, QR/base64 data, access tokens, or full provider payloads.
- Do not automatically replay the failed production request.
- Do not create a real provider bill for diagnostics without explicit user approval.
- Use only additive migrations and preserve all existing payments, top-ups, and wallet data.
- Run destructive test setup only against newpaotang_test.

Return to QA with migration order, rollback notes, redacted diagnostics evidence, transaction-boundary tests, idempotency tests, and one explicitly approved controlled provider verification plan.
```
