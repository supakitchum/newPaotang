# Production DeePay Top-up HTTP 500 After Successful Bill Creation

Date: 2026-08-12

Status: **Production mitigated; permanent application remediation implemented locally and awaiting release**

Owner: Coordinator / Platform API / Realtime

## DevOps Mitigation Applied (2026-08-12)

The production Platform Reverb limits were raised from the project defaults of
`10,000` bytes to `64,000` bytes:

```text
REVERB_MAX_REQUEST_SIZE=64000
REVERB_APP_MAX_MESSAGE_SIZE=64000
```

The change was applied only to `newpaotang-platform-config` and only the
`platform-api-reverb` Deployment was rolled out. Platform API, workers,
scheduler, Order, Checkout, and database workloads were not restarted. Both
Reverb replicas became Ready with zero restarts.

Runtime verification confirmed that both replicas loaded `64,000` for the
server request limit and application message limit. A synthetic event with a
serialized payload of `12,083` bytes and no customer or provider data was
accepted without a `Payload too large` or broadcast exception. The public API
health endpoint remained healthy for application, database, and cache.

At mitigation time this was operational containment only: it prevented the
known QR-sized payload from turning a committed Top-up into HTTP 500 but did not
make the realtime payload design acceptable. The permanent application work
described below now removes QR/base64/provider bodies and isolates broadcast
transport failures; it still requires release deployment.

## Permanent Remediation Prepared (2026-08-12)

The application remediation is implemented in the current worktree but has not
been deployed or migrated against a runtime database:

- Admin and customer `topup.updated` events now carry IDs and compact status
  fields only. They exclude the QR, provider payload, slip data, and full Top-up
  resource. Consumers refetch authoritative data through the authenticated API.
- Realtime transport failures are caught after commit and logged with safe
  tenant/customer/Top-up identifiers, exception class, and sanitized message.
  They no longer turn a committed HTTP 201 Top-up into HTTP 500.
- The BO Top-up consumer accepts the compact event and refetches its lists.
- Provider QR and Credit QR requests receive a server-owned five-minute expiry.
  A bounded scheduler requests provider cancellation and marks the customer
  Top-up expired. If provider cancellation is not confirmed, it retries while
  the Payment remains reconcilable and authenticated successful confirmation
  can still win.
- The authenticated API hides expired or cancelled QR/redirect data. Flutter
  displays a server-aligned countdown and removes the QR at expiry.
- Flutter quick-amount selection creates QR immediately, blocks duplicate
  interaction while DeePay responds, and navigates directly to the request
  detail. Manually typed amounts use one Create QR action. Bank-transfer slip
  flow remains separate.

Verification completed against `newpaotang_test` only:

```text
Platform CustomerTopupTest + PaymentWebhookTest: 17 passed, 362 assertions
Flutter Topup focused suites: 36 passed
Flutter focused analysis: no issues
git diff --check: passed
```

The Platform tests assert a 300-second expiry boundary, immediate overview
unblocking at the deadline, provider cancellation, repeat-safe expiry,
immediate QR removal after customer cancellation, safe authenticated late
payment settlement when provider cancellation is unconfirmed, current-state
idempotency replay that cannot expose an expired QR, and compact realtime events
under 2 KB with no `topup`, `payment`, or `qr_code` field. Runtime migration and
application deployment remain pending an explicit release instruction.

## Summary

A production customer created a DeePay KBank QR top-up and received HTTP 500.
DeePay did not fail: it returned HTTP 200 with provider code `0`, supplied a QR
code and transaction reference, and the Platform API committed the successful
provider attempt, Top-up, Payment, and idempotency response.

The HTTP request failed after the database commit when the synchronous
`topup.updated` broadcast attempted to send a payload containing the base64 QR
image. Pusher rejected the event with `Payload too large`, and the resulting
`BroadcastException` propagated back through the original HTTP request.

This is an application/realtime payload defect, not a DeePay, database,
Kubernetes, ingress, or credential failure.

## Affected Environment

```text
Kubernetes context: do-sgp1-lotto80
Namespace: newpaotang-prod
Database: lottery80
Tenant: ten_2637f84274a214c56e63
Provider: deepay_kbank
Platform API image: 29aa4e6fc857
```

No credential, API key, access token, QR body, or full provider payload was
printed or included in this report.

## Incident Evidence

All local times use Asia/Bangkok.

```text
Local time:          2026-08-12 13:59:41+07
UTC time:            2026-08-12 06:59:41Z
Method:              POST
Path:                /api/v1/customer/topups
API status:          500
Response size:       44 bytes
Client:              Dart/3.12 (dart:io)
Request ID:          req_1786517976128199_398e7cc9864e5c89
Provider attempt ID: pat_01KZTC9XJYXQ1EEMZX87XR0Z36
Top-up ID:           top_01KZTC9XJYXQ1EEMZX87XR0Z34
Payment ID:          pay_01KZTC9XJYXQ1EEMZX87XR0Z35
```

The nginx access log recorded exactly one matching top-up HTTP 500 during the
review window.

## DeePay Result

The structured provider-attempt record and application log agree:

```text
provider:                deepay_kbank
operation:               bill
channel:                 qr
attempt status:          succeeded
provider HTTP status:    200
provider code:           0
response classification: succeeded
latency:                 4321 ms
provider message:        null
application error code:  null
```

The provider success log was written immediately before the broadcast error:

```text
production.INFO: payment_provider_attempt_completed
production.ERROR: Pusher error: Payload too large.
```

Do not classify this incident as a DeePay HTTP 500 or provider rejection.

## Database State After the HTTP 500

Read-only production checks confirmed that the transaction had already
committed:

```text
Provider attempt: succeeded
Top-up status:    processing
Payment status:   pending
Payment paid_at:  null
Wallet ledger:    no entry for this Top-up
Idempotency:      completed with stored HTTP 201 response
```

The Top-up amount is stored as `50000` minor units in THB. The wallet was not
credited, so this incident did not create an incorrect balance or posted ledger
entry.

The stored idempotency response is important:

```text
route_key:           customer.topups.create
response_status:     201
response_body_bytes: 11461
completed_at:        2026-08-12 13:59:41+07
```

A retry using the same Idempotency-Key and request payload should replay the
stored 201 response without calling DeePay again. A retry using a new key can
create another Top-up and another provider bill and must not be used as an
operational workaround.

## Confirmed Root Cause

The successful DeePay response includes a base64 QR image. The Platform API
stores the provider payload on both the Payment and Top-up; each stored payload
was `11292` bytes for this incident.

`CommerceService::topupResource()` includes the QR body in every resource:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3575`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:3594`

After provider success, `createCustomerTopup()` stores that resource as the
idempotent HTTP 201 response and schedules a Top-up broadcast:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:937`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:953`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:955`

The after-commit callback then reuses the full resource, including the QR, in
both admin and customer realtime events:

- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:4557`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:4573`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php:4583`

Both event classes implement `ShouldBroadcastNow`, so broadcasting occurs
synchronously in the original request path:

- `apps/platform-api/app/Modules/Commerce/Events/TopupUpdated.php:11`
- `apps/platform-api/app/Modules/Commerce/Events/CustomerTopupUpdated.php:11`

The causal sequence is:

1. DeePay creates the bill and returns HTTP 200.
2. The Platform API commits Provider Attempt, Payment, Top-up, and idempotency
   response.
3. The database after-commit callback dispatches `TopupUpdated` synchronously.
4. The event contains the base64 QR plus customer and Top-up summary fields.
5. Pusher rejects the event as too large.
6. `BroadcastException` escapes the after-commit callback.
7. The original customer request returns HTTP 500 despite committed success.

The stack trace points to `CommerceService.php:4573`, the first synchronous
admin Top-up broadcast. The customer broadcast on line 4583 is also oversized
by design and remains vulnerable even though execution did not reach it during
this incident.

## Customer and Operational Impact

- The customer sees a server error instead of the QR top-up response.
- The provider bill exists and the platform record remains `processing`.
- A retry with a new Idempotency-Key may create a duplicate provider bill.
- Realtime Top-up updates are not delivered for the failed broadcast.
- The wallet remains unchanged until an authenticated payment confirmation or
  audited manual reconciliation occurs.
- Automatic DeePay callbacks remain fail-closed by design; this incident must
  not be resolved by weakening callback authentication.

The API health endpoint remained healthy for application, database, and cache.
All production Platform API replicas were Ready with zero restarts.

## Required Remediation

### 1. Use compact realtime payloads

Do not include any of the following in broadcast events:

```text
base64 QR data
provider payload JSON
slip image data
large asset bodies
credentials or access tokens
```

Broadcast identifiers and compact state only, for example:

```text
event_type
tenant_id
customer_id when applicable
topup_id
source_status
presentation status
notification_status
pending_count when applicable
updated_at
```

Consumers should refetch the Top-up detail through the authenticated API when
they need the QR or complete resource.

### 2. Isolate non-critical broadcast failures

A realtime side effect must not change a successfully committed create request
from HTTP 201 to HTTP 500. Use an established project pattern such as a queued
broadcast/outbox or a bounded best-effort dispatcher that logs sanitized
failure diagnostics without throwing into the primary request.

Do not merely catch and discard every exception. Preserve an observable event
name, tenant/top-up identifiers, exception class, and safe error message so
realtime delivery problems remain diagnosable.

### 3. Preserve idempotent recovery

The same Idempotency-Key must replay the stored successful response without a
second DeePay request. The client must not automatically generate a new key
after an ambiguous HTTP 500 from a create operation.

### 4. Keep payment security unchanged

Do not mark the Payment paid, post a wallet ledger entry, or enable unsigned
DeePay callbacks as part of this fix. Provider bill creation and payment
confirmation are separate states.

## Required Tests

1. A DeePay success response containing a QR larger than the realtime provider
   limit still returns HTTP 201 to the customer.
2. The successful attempt, `processing` Top-up, `pending` Payment, provider
   reference, and idempotency response are committed exactly once.
3. Admin and customer `topup.updated` payloads exclude `payment.qr_code` and all
   provider/base64 bodies.
4. Serialized realtime payload size remains below an explicit project limit.
5. A broadcast transport exception does not alter the HTTP create response.
6. Broadcast failure is logged with safe identifiers and no QR/API key data.
7. Retrying the same Idempotency-Key returns the stored 201 response and does
   not call DeePay again.
8. A successful bill creation does not post a wallet ledger entry.
9. The authenticated Top-up detail endpoint still returns the QR required by
   the customer application.
10. Existing Top-up status and pending-count realtime behavior remains correct
    after reducing the payload.

## Release Acceptance Criteria

- A controlled test with a QR payload at least as large as the production
  incident returns HTTP 201.
- No realtime event contains base64 QR data.
- No broadcast exception can turn a committed Top-up into an HTTP 500 response.
- Same-key replay is verified without a second provider call.
- Payment and wallet state remain unchanged until confirmed payment.
- Focused Platform API tests pass against `newpaotang_test` only.
- Production rollout includes API, workers, scheduler, and Reverb image parity
  checks and post-deploy health verification.

## Investigation Safety

This investigation was read-only. It did not retry the provider request,
approve or reject the Top-up, post a wallet entry, change payment state, rotate
credentials, or modify production data.
