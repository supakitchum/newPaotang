# back-office-p5-tenant-affiliate-commission-typed-workflows - QA Report

Date: 2026-05-12

Agent: QA Tester

## Result

PASS.

Focused QA passed for:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

All four rows are completion candidates for Coordinator review.

## Scope Under Test

HEAD under test:

```text
a422cfb44ccae3a2a9794358bb54669d83d5ed9f
```

Implementation commit under test:

```text
fdd8ae946c52fb3ce7e4ffd71615cab546433cf2
```

BO handoff commit:

```text
2462ce91a94f676a4fb590ee2e84921aef5c6e66
```

Routes tested:

```text
/admin/tenant/growth/affiliate-programs
/admin/tenant/growth/affiliates
/admin/tenant/growth/affiliate-links
/admin/tenant/growth/commission-rules
```

Customer frontend was not used.

## Docker Validation

All required validation ran through Docker.

| Command | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `validation/git-diff-check.log` |
| `docker compose up -d postgres valkey platform-api back-office` | PASS | `validation/docker-compose-up.log` |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` | PASS | `validation/migrate-fresh-seed.log` |
| `docker compose run --rm platform-api php artisan test --filter=AffiliateTest` | PASS, 1 passed / 22 assertions | `validation/affiliate-test.log` |
| `docker compose run --rm platform-api php artisan test --filter=CommissionTest` | PASS, 3 passed / 24 assertions | `validation/commission-test.log` |
| `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` | PASS, 5 passed / 26 assertions | `validation/admin-menu-test.log` |
| `docker compose run --rm back-office npm run lint` | PASS | `validation/back-office-lint.log` |
| `docker compose run --rm back-office npm run test` | PASS | `validation/back-office-test.log` |
| `docker compose run --rm back-office npm run build` | PASS | `validation/back-office-build.log` |
| `docker compose up -d --force-recreate back-office` | PASS | `validation/back-office-force-recreate.log` |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` before evidence | PASS | `validation/migrate-fresh-seed-before-evidence.log` |

Non-blocking build warnings matched BO handoff notes:

```text
[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated.
/admin-template/assets/images/media/media-33.jpg did not resolve at build time and remains runtime-resolved.
```

## API Evidence

Evidence:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/api/api-evidence.json
```

Tenant scope used:

```text
X-Admin-Scope: tenant
X-Tenant-Id: ten_demo_alpha
```

API workflow summary:

| Row | Create | Update | Archive | Filter/detail evidence |
| --- | --- | --- | --- | --- |
| Affiliate programs | `POST /api/v1/admin/tenant/affiliate-programs` 201 | `PATCH /api/v1/admin/tenant/affiliate-programs/{id}` 200 | `DELETE /api/v1/admin/tenant/affiliate-programs/{id}` 204 | inactive filter found safe row; archived detail returned `status=archived` |
| Affiliate accounts | `POST /api/v1/admin/tenant/affiliates` 201 | `PATCH /api/v1/admin/tenant/affiliates/{id}` 200 | N/A by contract | status filter found safe row; payout_profile and metadata arrays round-tripped |
| Affiliate links | `POST /api/v1/admin/tenant/affiliate-links` 201 | `PATCH /api/v1/admin/tenant/affiliate-links/{id}` 200 | `DELETE /api/v1/admin/tenant/affiliate-links/{id}` 204 | affiliate filter found safe row; archived detail returned `status=archived` |
| Commission rules | `POST /api/v1/admin/tenant/commission-rules` 201 | `PATCH /api/v1/admin/tenant/commission-rules/{id}` 200 | `DELETE /api/v1/admin/tenant/commission-rules/{id}` 204 | affiliate account filter found safe row; amount object round-tripped; archived detail returned `status=archived` |

API checks were true for:

```text
program_create_update_archive
affiliate_create_update_no_archive
link_create_update_archive
rule_create_update_archive
filters_found_safe_rows
all_writes_had_idempotency_key
tenant_scope_headers_present
```

## Browser Evidence

Evidence:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/browser/browser-summary.json
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/browser/*.png
```

Browser QA used a Docker Playwright browser against a BO dev server configured with Docker-internal API base. The real tenant BO login and real tenant menu links were used.

Browser workflow summary:

| Check | Result |
| --- | --- |
| Real menu link `/admin/tenant/growth/affiliate-programs` clicked | PASS |
| Typed program create/update/archive modal evidence | PASS |
| Real menu link `/admin/tenant/growth/affiliates` clicked | PASS |
| Typed affiliate account create/update modal evidence | PASS |
| Affiliate account archive action absent as expected | PASS |
| Real menu link `/admin/tenant/growth/affiliate-links` clicked | PASS |
| Typed affiliate link create/update/archive modal evidence | PASS |
| Real menu link `/admin/tenant/growth/commission-rules` clicked | PASS |
| Typed commission rule create/update/archive modal evidence | PASS |
| Archive confirmations show context and disable Confirm until reason | PASS |
| Status and relation filters found safe QA-created rows | PASS |
| List/detail calls carried tenant scope headers | PASS |
| Write calls carried `Idempotency-Key` | PASS |
| Customer frontend/API not used | PASS |

Captured screenshots include list, create modal, detail, update modal, filter, and archive modal states for the scoped workflows.

## Completion Recommendation

Recommended for Coordinator review:

```text
tenant:affiliate_programs -> complete candidate
tenant:affiliate_accounts -> complete candidate
tenant:affiliate_links -> complete candidate
tenant:commission_rules -> complete candidate
```

## Defects

No new defects found.

## Known Unrelated Dirty Files Left Untouched

These were present before QA or generated by unrelated runtime/test activity and were not edited, staged, committed, or cleaned:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Redaction Summary

Artifacts intentionally store only request metadata, payload keys, safe local fixture IDs, booleans, and screenshots. They do not include bearer token values, access token values, refresh token values, seeded password values, private keys, support tokens, or customer secrets.

Redaction scan result:

```text
PASS - no matches for seeded admin/tenant password values, bearer/access/refresh token fields, private keys, support tokens, or known test password literals in the current QA report/artifact text files.
```

## Routing

Next agent:

```text
Coordinator
```
