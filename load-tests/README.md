# NewPaotang M10 Load Tests

Run every k6/PHP step through Docker from the workspace root. Do not run local k6, PHP, Composer, Artisan, or Node commands.

## Local/dev baseline

1. Start the API dependencies and migrate/seed through Docker if needed.
2. Generate local/dev fixtures and bearer tokens:

```sh
scripts/k6-prepare-baseline-fixtures.sh
```

This writes generated artifacts to `load-tests/results/`:

- `k6-baseline-env.json` machine-readable fixture metadata.
- `k6-baseline.env` Docker/k6 env file.

Generated tokens are intentionally not committed. `load-tests/results/` is ignored except for its `.gitignore`.

3. Run the short API-backed baseline:

```sh
scripts/k6-run-baseline.sh
```

The runner defaults to `K6_PROFILE=smoke` and writes `*.summary.json` artifacts under `load-tests/results/<run-id>/`.

Use larger profiles only after the short baseline is healthy:

```sh
K6_PROFILE=baseline scripts/k6-run-baseline.sh
K6_PROFILE=release-candidate scripts/k6-run-baseline.sh
```

## Scenarios

- `customer-stock-search.js`
- `concurrent-booking-same-stock.js`
- `checkout-wallet-consistency.js`
- `partner-tenant-burst-sync.js`
- `reward-publish-spike.js`
- `reward-checking-queue-chunk.js`
- `ticket-image-cdn-spike.js`

The first six scenarios run against local/dev API fixtures. `ticket-image-cdn-spike.js` remains a runnable CDN/object-storage template; the baseline runner records a skipped artifact unless `CDN_BASE_URL` and `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH` are supplied for a real Cloudflare/CDN/R2 ticket image path.

`ticket-image-cdn-spike.js` intentionally ignores normal API `BASE_URL`. CDN/R2 coverage is only claimable with explicit `CDN_BASE_URL` and `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH`.
