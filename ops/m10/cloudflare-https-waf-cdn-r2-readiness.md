# M10 Cloudflare HTTPS WAF CDN R2 Readiness

## Boundary

This artifact is local/dev readiness only. It is not staging, production, Cloudflare activation, DNS ownership, SSL, WAF enforcement, R2 delivery, CDN cache-hit, or client-delivery approval.

The backend verifier is:

```sh
docker compose exec platform-api php artisan platform:cloudflare:readiness --format=json
```

It does not call or mutate Cloudflare/R2. It reports presence-only configured flags, constant redacted placeholders, domain readiness fields, local rule artifacts, ticket-image CDN prerequisites, blockers, and `production_approved=false`.

## Required Evidence Before Production Approval

```text
Cloudflare account and non-production/prod zone owner identified
Cloudflare DNS records verified for every public tenant host
Cloudflare proxy enabled where required
SSL/TLS Full strict or equivalent origin certificate verified
Always Use HTTPS or equivalent redirect verified
WAF/rate-limit rules deployed and sampled
cache-bypass rules deployed and sampled for dynamic/payment/webhook paths
R2/object-storage bucket and CDN URL policy verified
real ticket-image object path tested through CDN using `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH`
secret management approved outside local env examples
QA report links concrete screenshots/logs/JSON evidence
```

## Domain Readiness Fields

`partner_tenant_domains` keeps the existing source-of-truth fields:

```text
verified_at
ssl_ready_at
```

The backend adds nullable readiness evidence fields:

```text
dns_verified_at
cloudflare_proxy_verified_at
https_enforced_at
cloudflare_readiness_checked_at
```

Custom domains must not become `active` unless DNS ownership, SSL readiness, Cloudflare proxy expectation, and HTTPS enforcement are all satisfied. Local `.test` subdomains may remain active as local-only test domains, and the verifier marks that boundary explicitly.

## Ops Artifacts

```text
ops/m10/cloudflare-waf-rate-limit-rules.json
ops/m10/cloudflare-cache-bypass-rules.json
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
```

The JSON rules are templates. Apply them to real Cloudflare zones only after Coordinator/Ops approval and QA evidence.

## Docker Validation

```sh
docker compose exec platform-api php artisan platform:cloudflare:readiness --format=json
bash -n scripts/platform-cloudflare-readiness.sh
bash -n scripts/ticket-image-cdn-check.sh
jq empty ops/m10/cloudflare-waf-rate-limit-rules.json
jq empty ops/m10/cloudflare-cache-bypass-rules.json
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

## Blockers Carried Forward

```text
real Cloudflare credentials and zones are not present in this workspace
real DNS/proxy/SSL/HTTPS evidence is not present in this workspace
real WAF/cache rules are not deployed by this slice
real R2 bucket/object path is not present in this workspace
real ticket-image CDN load test remains blocked until CDN_BASE_URL and IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH point at CDN/R2
production secret management remains a separate release gate
```
