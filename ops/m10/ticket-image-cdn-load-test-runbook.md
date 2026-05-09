# Ticket Image CDN Load Test Runbook

## Boundary

This runbook only proves ticket-image CDN/R2 behavior when a real CDN base URL and real object path are supplied. Normal API `BASE_URL` must not count as image CDN coverage.

## Prerequisites

```text
CDN_BASE_URL points at Cloudflare/CDN/R2 infrastructure
IMAGE_PATH points at an existing immutable ticket image object
TICKET_IMAGE_CDN_IMAGE_PATH may be used instead of IMAGE_PATH when the same object evidence should be shared with platform readiness
object returns HTTP 200 through CDN
Cache-Control is present and appropriate for immutable images
no generated bearer tokens or signed URLs are committed
```

## Syntax Check

```sh
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

## Readiness Helper

Without `CDN_BASE_URL` and `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH`, the helper inspects the script and prints a blocker:

```sh
scripts/ticket-image-cdn-check.sh
```

With a real CDN/R2 object:

```sh
CDN_BASE_URL="<cdn-base-url>" IMAGE_PATH="<ticket-image-object-path>" scripts/ticket-image-cdn-check.sh
```

## Baseline Runner Behavior

`scripts/k6-run-baseline.sh` runs the six API-backed scenarios locally. It runs `ticket-image-cdn-spike.js` only when `CDN_BASE_URL` and either `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH` are present. If either value is missing, it writes `ticket-image-cdn-spike.skipped.json`.

The k6 script intentionally ignores `BASE_URL` and rejects `CDN_BASE_URL` values that are exactly the same as `BASE_URL`.

## QA Evidence To Capture

```text
command used
redacted CDN host and image path
k6 summary JSON
response status distribution
Cache-Control sample
confirmation that image bytes came from CDN/R2, not Laravel
remaining blockers
```
