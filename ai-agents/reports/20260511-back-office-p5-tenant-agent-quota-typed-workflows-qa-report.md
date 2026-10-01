# back-office-p5-tenant-agent-quota-typed-workflows - QA Report

Date: 2026-05-11

Agent: QA Tester

## Result

PASS.

Focused QA passed for:

```text
tenant:agents
tenant:agent_quotas
```

Both rows are completion candidates for Coordinator review.

## Scope Under Test

HEAD under test:

```text
4e786adfd3b80e97b4f780f371acabc64e356611
```

Implementation commit under test:

```text
4be4957083de80b9ef63395d1479b8a78be83f55
```

BO handoff commit:

```text
260e095772dadccb9ee34cf0a8a16978a72a7c53
```

Routes tested:

```text
/admin/tenant/growth/agents
/admin/tenant/growth/agent-quotas
```

Customer frontend was not used.

## Docker Validation

All required validation ran through Docker.

| Command | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `validation/git-diff-check.log` |
| `docker compose up -d postgres valkey platform-api back-office` | PASS | `validation/docker-compose-up.log` |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` | PASS | `validation/migrate-fresh-seed.log` |
| `docker compose run --rm platform-api php artisan test --filter=AgentTest` | PASS, 1 passed / 16 assertions | `validation/agent-test.log` |
| `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` | PASS, 5 passed / 26 assertions | `validation/admin-menu-test.log` |
| `docker compose run --rm back-office npm run lint` | PASS | `validation/back-office-lint.log` |
| `docker compose run --rm back-office npm run test` | PASS | `validation/back-office-test.log` |
| `docker compose run --rm back-office npm run build` | PASS | `validation/back-office-build.log` |
| `docker compose up -d --force-recreate back-office` | PASS | `validation/back-office-force-recreate.log` |

Non-blocking build warnings matched BO handoff notes:

```text
[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated.
/admin-template/assets/images/media/media-33.jpg did not resolve at build time and remains runtime-resolved.
```

After backend tests, QA re-ran `migrate:fresh --seed` before API/browser evidence because focused backend tests use database refresh behavior.

## API Evidence

Evidence:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa/api/api-evidence.json
```

Tenant scope used:

```text
X-Admin-Scope: tenant
X-Tenant-Id: ten_demo_alpha
```

Agent API workflow:

| Step | Endpoint | Result |
| --- | --- | --- |
| Create | `POST /api/v1/admin/tenant/agents` | 201, tenant_id matched, id returned, metadata object round-tripped |
| Detail after create | `GET /api/v1/admin/tenant/agents/{agent_id}` | 200, id/code matched, quotas array present |
| Update | `PATCH /api/v1/admin/tenant/agents/{agent_id}` | 200, code/name updated, metadata array round-tripped |
| Inactive filter | `GET /api/v1/admin/tenant/agents?status=inactive` | 200, updated agent found, cursor meta present |
| Agent-route quota update | `PATCH /api/v1/admin/tenant/agents/{agent_id}/quotas` | 200, quota_count/used_count updated, payload object round-tripped |
| Detail after agent-route quota | `GET /api/v1/admin/tenant/agents/{agent_id}` | 200, quota_count visible |

Dedicated quota API workflow:

| Step | Endpoint | Result |
| --- | --- | --- |
| Dedicated quota update | `PATCH /api/v1/admin/tenant/agents/{agent_id}/quotas` | 200, quota_count/used_count/status updated, payload array round-tripped |
| Detail after dedicated quota | `GET /api/v1/admin/tenant/agents/{agent_id}` | 200, quota status and quota_count visible |

Every API write request carried `Idempotency-Key`.

## Browser Evidence

Evidence:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa/browser/browser-summary.json
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa/browser/*.png
```

Browser QA used a Docker Playwright browser against a BO dev server configured with Docker-internal API base. The real BO tenant login and real tenant sidebar/menu links were used.

Tenant agents browser workflow:

| Check | Result |
| --- | --- |
| Tenant dashboard reached after authenticated login | PASS |
| Real menu link `/admin/tenant/growth/agents` clicked | PASS |
| List API loaded with tenant scope headers | PASS |
| Typed Create agent modal fields visible | PASS: code, name, phone, email, store_id, status, metadata JSON |
| Create request | PASS, `POST /admin/tenant/agents`, 201, idempotency present |
| Created row appeared in list and detail | PASS |
| Typed Update agent modal prefilled | PASS |
| Update request | PASS, `PATCH /admin/tenant/agents/{id}`, 200, idempotency present |
| Update quotas modal fields visible | PASS: game_id, quota_count, used_count, status, payload JSON, reason |
| Quota modal context/reason guard | PASS, Confirm disabled until reason |
| Quota request | PASS, `PATCH /admin/tenant/agents/{id}/quotas`, 200, idempotency present |
| Detail quota response visible | PASS, detail JSON showed updated quota_count |

Dedicated agent quotas browser workflow:

| Check | Result |
| --- | --- |
| Real menu link `/admin/tenant/growth/agent-quotas` clicked | PASS |
| Route used `GET /admin/tenant/agents` for list | PASS |
| Detail opened through `GET /admin/tenant/agents/{agent_id}` | PASS |
| Update quotas modal fields visible | PASS |
| Reason guard | PASS, Confirm disabled until reason |
| Dedicated quota request | PASS, `PATCH /admin/tenant/agents/{id}/quotas`, 200, idempotency present |
| Detail quota response visible | PASS, detail JSON showed updated quota_count and status |
| Status filter | PASS, inactive filter found the updated safe agent |

Request summary confirms:

```text
usedCustomerFrontend: false
menuAgentsClicked: true
menuAgentQuotasClicked: true
```

## Defects

No new defects found.

## Completion Recommendation

Recommended for Coordinator review:

```text
tenant:agents -> complete candidate
tenant:agent_quotas -> complete candidate
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

Artifacts intentionally store only request metadata, payload keys, safe fixture IDs, and screenshots without bearer/access/refresh tokens or seeded password values.

Sensitive values not written:

```text
bearer tokens
access tokens
refresh tokens
seeded tenant password
private keys
support tokens
customer secrets
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
