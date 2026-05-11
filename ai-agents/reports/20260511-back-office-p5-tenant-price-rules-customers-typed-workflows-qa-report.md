# back-office-p5-tenant-price-rules-customers-typed-workflows - QA Report

Date: 2026-05-11

Agent: QA Tester

## Result

PASS.

Focused QA passed for:

```text
tenant:price_rules
tenant:customers
```

Both rows are completion candidates for Coordinator review.

## Scope Under Test

HEAD under test:

```text
2c9b63eb9bc0aa124bb7302c8ee49d3f93e101e8
```

Implementation commit under test:

```text
10ce1bfb720d561e0fab6f886c45f04337a6e239
```

BO handoff commit:

```text
187e21a14968ef0983f60fb943c4173469921bcf
```

Routes tested:

```text
/admin/tenant/price-rules
/admin/tenant/customers
```

Customer frontend was not used.

## Docker Validation

All required validation ran through Docker.

| Command | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `validation/git-diff-check.log` |
| `docker compose up -d postgres valkey platform-api back-office` | PASS | `validation/docker-compose-up.log` |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` | PASS | `validation/migrate-fresh-seed.log` |
| `docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest` | PASS, 3 passed / 161 assertions | `validation/bo-menu-completion-backend-gap-test.log` |
| `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` | PASS, 5 passed / 26 assertions | `validation/admin-menu-test.log` |
| `docker compose run --rm back-office npm run lint` | PASS | `validation/back-office-lint.log` |
| `docker compose run --rm back-office npm run test` | PASS | `validation/back-office-test.log` |
| `docker compose run --rm back-office npm run build` | PASS | `validation/back-office-build.log` |
| `docker compose up -d --force-recreate back-office` | PASS | `validation/back-office-force-recreate.log` |

Non-blocking build warnings matched prior handoff notes:

```text
[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated.
/admin-template/assets/images/media/media-33.jpg did not resolve at build time and remains runtime-resolved.
```

After backend tests, QA re-ran `migrate:fresh --seed` before API/browser evidence because the focused backend tests use database refresh behavior.

## API Evidence

Evidence:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/api/api-evidence.json
```

Tenant scope used:

```text
X-Admin-Scope: tenant
X-Tenant-Id: ten_demo_alpha
```

Price rule API workflow:

| Step | Endpoint | Result |
| --- | --- | --- |
| Create | `POST /api/v1/admin/tenant/price-rules` | 201, tenant_id matched, id returned, conditions object round-tripped |
| Detail after create | `GET /api/v1/admin/tenant/price-rules/{price_rule_id}` | 200, id/code matched |
| Update | `PATCH /api/v1/admin/tenant/price-rules/{price_rule_id}` | 200, name/price updated, conditions array round-tripped |
| Active filter | `GET /api/v1/admin/tenant/price-rules?status=active` | 200, created rule found, cursor meta present |
| Archive | `DELETE /api/v1/admin/tenant/price-rules/{price_rule_id}` | 204, idempotency key present |
| Detail after archive | `GET /api/v1/admin/tenant/price-rules/{price_rule_id}` | 200, status archived |

Member API workflow:

| Step | Endpoint | Result |
| --- | --- | --- |
| Create | `POST /api/v1/admin/tenant/members` | 201, tenant_id matched, id returned, `password_hash` absent |
| Detail after create | `GET /api/v1/admin/tenant/members/{member_id}` | 200, id/phone matched, `password_hash` absent |
| Update | `PATCH /api/v1/admin/tenant/members/{member_id}` | 200, name/email updated |
| Status change | `POST /api/v1/admin/tenant/members/{member_id}/status` | 200, status suspended |
| Suspended filter | `GET /api/v1/admin/tenant/members?status=suspended&q={email}` | 200, updated member found, cursor meta present, `password_hash` absent |

Every API write request carried `Idempotency-Key`.

## Browser Evidence

Evidence:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/browser/browser-summary.json
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/browser/*.png
```

Browser QA used a Docker Playwright browser against a BO dev server configured with Docker-internal API base. This kept app execution inside Docker while allowing the browser container to call `platform-api` directly. The real BO tenant login and real tenant sidebar/menu links were used.

Price rules browser workflow:

| Check | Result |
| --- | --- |
| Tenant dashboard reached after authenticated login | PASS |
| Real menu link `/admin/tenant/price-rules` clicked | PASS |
| List API loaded with tenant scope headers | PASS |
| Typed Create price rule modal fields visible | PASS |
| Create request | PASS, `POST /admin/tenant/price-rules`, 201, idempotency present |
| Created row appeared in list and detail | PASS |
| Typed Update price rule modal prefilled | PASS |
| Update request | PASS, `PATCH /admin/tenant/price-rules/{id}`, 200, idempotency present |
| Archive modal context/reason guard | PASS, Confirm disabled until reason |
| Archive request | PASS, `DELETE /admin/tenant/price-rules/{id}`, 204, idempotency present |
| Archived status/detail evidence | PASS |

Customer/member browser workflow:

| Check | Result |
| --- | --- |
| Real menu link `/admin/tenant/customers` clicked | PASS |
| List API loaded with tenant scope headers | PASS |
| Typed Create member modal fields visible | PASS |
| Password screenshot handling | PASS, screenshot captured before entering password |
| Create request | PASS, `POST /admin/tenant/members`, 201, idempotency present |
| Created member appeared in list and detail | PASS |
| Typed Update member modal prefilled | PASS |
| Update request | PASS, `PATCH /admin/tenant/members/{id}`, 200, idempotency present |
| Change status modal context/reason guard | PASS, Confirm disabled until reason |
| Status request | PASS, `POST /admin/tenant/members/{id}/status`, 200, idempotency present |
| Suspended status filter found member | PASS |

Request summary confirms:

```text
usedCustomerFrontend: false
menuPriceRulesClicked: true
menuCustomersClicked: true
```

## Defects

No new defects found.

## Completion Recommendation

Recommended for Coordinator review:

```text
tenant:price_rules -> complete candidate
tenant:customers -> complete candidate
```

## Known Unrelated Dirty Files Left Untouched

These were present before QA or generated by unrelated runtime/test activity and were not edited, staged, committed, or cleaned:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Redaction Summary

Artifacts intentionally store only request metadata, payload keys, safe fixture IDs, and screenshots without readable password values.

Sensitive values not written:

```text
bearer tokens
refresh tokens
seeded tenant password
generated member password
password_hash
private keys
support tokens
```

Redaction scan result:

```text
PASS - no matches for seeded admin/tenant password values, bearer/access/refresh token fields, private keys, support tokens, or known test password literals in the current QA report/artifact text files.
```

## Routing

Next agent:

```text
Coordinator
```
