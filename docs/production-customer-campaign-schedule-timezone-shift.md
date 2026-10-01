# Production Customer Campaign Schedule: Seven-Hour Timezone Shift

Date: 2026-08-16

Status: root cause fixed in the application worktree with focused API and BO coverage. Deployment and controlled production verification are still pending. No infrastructure, queue state, campaign state, runtime database, or production data was changed.

Owner: Coordinator / application development

## Summary

A scheduled customer public-relations campaign was published immediately after creation instead of waiting for the time selected in the tenant back office.

The campaign scheduler, notification queue, and Firebase Cloud Messaging delivery path are operational. The defect is in timestamp persistence between the offset-aware ISO-8601 value sent by the back office and the `timestampTz` value written by Laravel to PostgreSQL.

For a browser in `Asia/Bangkok`, the back office correctly converts a selected local time such as `13:40+07` to the equivalent UTC instant `06:40Z`. The API parses that instant into a UTC Carbon value, but Eloquent later formats it for SQL without its offset. Because the production PostgreSQL session uses `Asia/Bangkok`, PostgreSQL interprets the resulting clock value `06:40` as `06:40+07`, moving the persisted instant seven hours earlier.

The scheduler then sees the campaign as overdue and publishes it on its next approximately one-minute cycle.

## Remediation Implemented

The focused application fix now:

- accepts scheduled timestamps only when they carry an explicit RFC 3339 `Z` or `+/-HH:MM` offset;
- parses the request once and converts that same Carbon instance to the active database connection timezone before Eloquent persistence;
- uses the normalized instance for validation and persistence, preserving the submitted Unix timestamp;
- keeps canonical UTC timestamps in API responses and browser-local conversion in the BO;
- leaves immediate delivery, historical campaigns, schema, global database timezone, and scheduler cadence unchanged.

Automated coverage uses `newpaotang_test`, forces the application and PostgreSQL session to `Asia/Bangkok`, and proves persistence, API round-trip, pre-due exclusion, due publication, idempotency, supported offsets, missing-offset rejection, and BO Bangkok local/UTC round-trip behavior.

## Affected Environment

```text
Kubernetes context: do-sgp1-lotto80
Namespace: newpaotang-prod
Tenant: ten_2637f84274a214c56e63
Platform API image: fe6c4034ecd6
Platform API timezone: Asia/Bangkok
Scheduler timezone: Asia/Bangkok
PostgreSQL session timezone: Asia/Bangkok
```

No customer message body, FCM token, token hash, Firebase credential, or other secret is included in this report.

## User-Visible Symptom

- An operator selects a future campaign date and time in the tenant BO.
- The campaign is accepted as valid and is shown as scheduled.
- It is published during the next scheduler cycle instead of at the selected time.
- Customers receive the native push shortly afterward.
- The BO history displays the publication time, making the campaign appear to have ignored its schedule.

## Latest Production Incident

All timestamps below use Asia/Bangkok unless explicitly marked as UTC.

```text
Campaign ID:     ccp_01M04FJ23FE8BCYFFS4S00W70X
Campaign name:   ประกาศอีก 30 นาทีปิดการขาย
Audience:        all_customers
Created at:      2026-08-16 12:08:53+07
Stored schedule: 2026-08-16 06:40:00+07
Published at:    2026-08-16 12:09:54+07
Notification ID: cnt_01M04FKX835GJP9D91Q0565NM1
Campaign error:  null
```

The stored schedule was already 5 hours, 28 minutes, and 53 seconds in the past when the row was created. The next scheduler cycle began at approximately `12:09:53`, and the campaign was published at `12:09:54`.

Two native push delivery rows were created and both were sent successfully:

```text
Delivery status: sent
Attempts:        1
Provider error:  null
Sent at:         2026-08-16 12:09:55+07
Delivery count:  2
```

This confirms that Firebase authentication, device registration, queue consumption, and provider delivery were not responsible for the schedule mismatch.

## Additional Corroborating Evidence

A second campaign was created immediately afterward:

```text
Campaign ID:     ccp_01M04FME50H53TPPECFZ6XF1XQ
Campaign name:   ปิดแผง
Created at:      2026-08-16 12:10:11+07
Stored schedule: 2026-08-16 07:10:00+07
Cancelled at:    2026-08-16 12:10:38+07
Status:          cancelled
```

For a Bangkok browser, `07:10Z` corresponds to `14:10+07`. The row instead contains `07:10+07`, showing the same seven-hour persistence shift. This campaign was cancelled before another scheduler publication and produced no notification.

Earlier scheduled campaigns from 2026-08-06 show the same pattern. This is a deterministic application defect rather than an isolated infrastructure event.

At the end of this investigation:

```text
Pending scheduled campaigns: 0
Notification queue backlog:  0
New scheduler errors:         0
```

No pending campaign currently requires data correction or cancellation.

## Confirmed Root Cause

### 1. BO sends an offset-aware instant

The tenant BO uses a browser-local `datetime-local` input and converts it to an ISO UTC instant before submission:

- `apps/back-office/pages/admin/tenant/customer-notifications.vue:630`

```ts
new Date(form.scheduled_at).toISOString()
```

This is the correct boundary contract. For example:

```text
Selected in Bangkok: 2026-08-16 13:40+07
Request value:       2026-08-16T06:40:00.000Z
```

### 2. API validation compares the correct instant

The API validates the request using `Carbon::parse()`:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerCommunicationCampaignService.php:456`

At validation time, `06:40Z` still represents `13:40+07`, so the API correctly considers it to be in the future and accepts the campaign.

### 3. Persistence loses the parsed offset

The service parses the value again and assigns the resulting Carbon instance directly to the Eloquent model:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerCommunicationCampaignService.php:160`
- `apps/platform-api/database/migrations/2026_08_04_000001_create_customer_communication_campaigns.php:27`

```php
$scheduledAt = Carbon::parse((string) $normalized['scheduled_at']);
```

The parsed Carbon instance remains in UTC. Eloquent's normal database date formatting emits a clock value without a timezone offset. PostgreSQL therefore receives `06:40:00`, and the production session interprets it in `Asia/Bangkok` as `06:40:00+07` rather than the intended `13:40:00+07`.

The absolute instant is shifted seven hours earlier only during persistence. This also explains why validation succeeds while the stored row becomes immediately due.

### 4. Scheduler correctly publishes the now-overdue row

The due query selects scheduled rows whose `scheduled_at <= now()`:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerCommunicationCampaignService.php:256`

The command is registered every minute with overlap and single-server protection:

- `apps/platform-api/routes/console.php:67`

Production logs show the command completing normally. The scheduler acted correctly on an incorrectly persisted timestamp.

## Scheduler Timing Characteristic

The production `schedule:work` process runs several scheduled commands sequentially. Recent logs show campaign checks approximately every 60 to 65 seconds rather than exactly on the minute boundary.

After the timezone defect is fixed, a campaign may therefore publish up to roughly 65 seconds after its selected instant. That bounded delay is separate from the seven-hour early-publication defect. Product acceptance criteria should state an allowed dispatch tolerance, suggested at no more than 90 seconds unless the scheduler architecture is changed.

## Test Gap

The existing feature test submits:

```php
now()->addMinutes(10)->toISOString()
```

It does not set a non-UTC application/database timezone and does not assert that the persisted schedule represents the same instant as the request. The test then manually updates `scheduled_at` into the past before invoking the publish command.

Relevant test:

- `apps/platform-api/tests/Feature/CustomerCommunicationCampaignTest.php:69`
- `apps/platform-api/tests/Feature/CustomerCommunicationCampaignTest.php:89`

This verifies due publication and idempotency but cannot detect offset loss during initial persistence.

## Required Remediation

### 1. Normalize once before persistence

Keep the BO contract as an offset-aware ISO-8601 instant. In the API, parse the submitted value once and normalize the Carbon object to the timezone expected by the active database connection before Eloquent formats it.

For the current production configuration, the narrow fix is equivalent to:

```php
Carbon::parse($value)->setTimezone(config('app.timezone'))
```

Use the same normalized value for validation and persistence. Do not independently parse the timestamp in multiple branches.

The Coordinator should verify the exact database session timezone in automated integration tests. A broader change that moves the entire database connection to UTC has a much larger timestamp blast radius and should not be introduced as part of this focused fix without a separate audit.

### 2. Preserve the instant in the API response

- Return one canonical offset-aware instant.
- Confirm that request, stored value, and response all represent the same Unix timestamp.
- Continue converting the instant to the browser locale only for display.
- Reject missing-offset values or define explicitly that they are interpreted in the application timezone.

### 3. Keep deployment non-destructive

- This fix should not require a schema migration.
- Do not rewrite or replay already-published campaign rows.
- Do not automatically resend historical campaigns.
- Do not modify cancelled campaigns.
- Deploy the API fix before re-enabling scheduled-campaign use operationally.

## Required Tests

1. Freeze application time in `Asia/Bangkok` and submit an explicit UTC request such as `2026-08-16T06:40:00Z`.
2. Assert that the stored value represents exactly `2026-08-16T13:40:00+07` and the same Unix timestamp as the request.
3. Assert that the API response round-trips the same instant.
4. Run the due publisher before `13:40+07` and assert that it selects zero campaigns.
5. Run it at or after `13:40+07` and assert that it publishes exactly once.
6. Repeat with explicit `+07:00`, `Z`, and another valid offset to prove instant preservation.
7. Reject a timestamp without a supported timezone contract.
8. Reject a schedule less than one minute in the future after normalization.
9. Verify that repeated scheduler runs do not duplicate the notification or push delivery.
10. Add a BO unit test proving that a Bangkok `datetime-local` value becomes the expected UTC ISO request value and renders back as the original local time.

Run database-reset or destructive tests only against `newpaotang_test`. Never use the protected runtime or production database for test setup.

## Acceptance Criteria

- A time selected in the BO persists as the same absolute instant in the database.
- A campaign never publishes before the selected instant.
- A due campaign publishes once within the agreed scheduler tolerance, suggested at 90 seconds.
- BO history displays the selected Bangkok time before publication and the actual publication time afterward without a seven-hour shift.
- `Z`, `+07:00`, and other supported offsets round-trip without changing their Unix timestamp.
- Existing immediate-send behavior remains unchanged.
- Existing published and cancelled campaigns are not replayed or rewritten.
- Focused backend and BO tests pass against the test database.

## Operational Workaround

Until the remediation is deployed and verified:

- Do not use scheduled campaigns in production.
- Use `Send now` only when the message is ready for immediate delivery.
- Do not compensate manually by adding seven hours; that workaround can become an accidental late send immediately after the fix is deployed.
- Confirm that the scheduled-campaign list remains empty during the temporary restriction.

## Production Verification After Fix

After deployment, perform one explicitly approved controlled test using a single test customer and device:

1. Schedule a campaign at least five minutes in the future.
2. Read back the saved campaign and verify that the selected local time and returned instant match.
3. Confirm that no notification or delivery exists before the due instant.
4. Confirm publication within the agreed scheduler tolerance.
5. Confirm exactly one push delivery reaches `sent` with no provider error.
6. Confirm repeated scheduler cycles do not create a duplicate.

This controlled production test creates campaign, notification, and delivery records. Obtain explicit approval before running it.

## Coordinator Task Prompt

```text
Fix the seven-hour scheduled customer-campaign timezone shift documented in:
docs/production-customer-campaign-schedule-timezone-shift.md

Scope:
1. Preserve one offset-aware instant from BO request through validation, Eloquent persistence, API response, and scheduler comparison.
2. Normalize the parsed timestamp to the active application/database timezone before Eloquent formats it, without changing the global database timezone in this focused patch.
3. Add Asia/Bangkok integration coverage and BO request/round-trip tests listed in the report.
4. Keep immediate-send behavior and scheduler idempotency unchanged.

Constraints:
- No schema migration should be required.
- Do not rewrite, replay, or resend historical campaigns.
- Do not run destructive tests against runtime or production databases.
- Use APP_ENV=testing, DB_DATABASE=newpaotang_test, and --env=testing for database-reset test setup.

Return the implementation with focused test evidence, deployment order, rollback notes, and a proposed controlled production verification plan. Do not execute the controlled production campaign without explicit approval.
```
