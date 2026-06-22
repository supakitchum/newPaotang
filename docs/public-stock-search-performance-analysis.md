# Public Stock Search Performance Analysis

Date: 2026-06-22

Status: investigation only. No runtime behavior has been changed.

## Endpoint

`GET /api/v1/public/stock/search`

Production host used for verification:

`https://xn--80-bsia4ej0dc7e8e3d.online`

Current game observed during investigation:

`gam_01KVDCHAM6EFHXHH8C8VTGG9C4`

## Symptom

The public stock search API can take around 3 seconds or more for broad/random search requests.

Observed timings from production:

| Query shape | Observed total time | Result |
| --- | ---: | --- |
| `mode=random&limit=20` | ~3.7s | Slow |
| `mode=search&number=123456` | ~0.23s | Fast when exact/empty result |
| `mode=search&back2=22` | ~1.3s | Slow-ish broad search |
| `mode=search&number=22` | ~2.5s | Slow broad suffix search |
| `mode=search&front3=123` | ~1.5s | Slow-ish broad search |

This points to broad/random virtual stock search as the bottleneck, not the whole API stack or network. `GET /api/v1/public/games/current` on the same host returned around `0.33s`.

## Main Findings

### 1. Customer search sends random mode too often

The customer search page currently calls `searchStockLegacy()` with `mode: 'random'` even when search digits are present.

Relevant code:

- `apps/customer/pages/buy/search.vue:213`
- `apps/customer/pages/buy/search.vue:243`
- `apps/customer/utils/stockSearchIdentity.js:25`

Impact:

When users search from the UI, the request can be routed into the backend random-search path instead of the narrower `mode=search` path.

### 2. Random search uses a non-indexable hash sort

Backend candidate generation uses:

```php
$query->orderByRaw('md5(full_number || ?)', [$randomSeed]);
```

Relevant code:

- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php:1118`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php:1165`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php:1174`

Impact:

`ORDER BY md5(full_number || seed)` cannot use a normal index. For random browse/search, PostgreSQL has to compute the hash ordering across a wide candidate set before Laravel can return the first page.

### 3. Availability is recalculated per candidate number

For every candidate full number, backend calls `availabilityForNumber()`.

Relevant code:

- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php:590`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php:677`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php:1270`

Inside that path, the code calculates:

- virtual capacity for the number
- partner copy indexes
- partner full-number used count
- central limit settings
- partner limit settings
- front3/back3/back2 remaining limits for central and partner scopes

Impact:

Broad search can become `candidate_count x many DB reads/calculations`. Even if only 20 rows are returned, the service may inspect many candidate numbers before it finds enough available rows.

### 4. Per-row response enrichment adds more repeated work

Each returned virtual stock row calls:

- `previewDescriptor()` for lottery image preview metadata
- `effectivePrice()` for sale price calculation

Relevant code:

- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php:2546`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualLotteryImageService.php:27`
- `apps/platform-api/app/Modules/Pricing/Services/LotterySalePriceService.php:23`

Impact:

The API has N+1-style enrichment work after candidate selection. For a 20-row page, repeated image/price lookups can add latency on top of the random/candidate scan.

## Likely Root Cause

The 3-second response time is primarily caused by the virtual stock random/broad search path:

1. UI often asks for `mode=random`.
2. Backend random mode sorts candidates with `md5(full_number || seed)`, which is not index-friendly.
3. Backend checks virtual availability per candidate.
4. Backend enriches each returned row with preview image and pricing data.

The exact-number path is much faster because it only checks a narrow candidate set.

## Optimization Options

### Priority 1: Fix frontend mode selection

Use `mode=search` whenever the user has typed a number or digit filter. Keep `mode=random` only for browse/no-search screens.

Expected impact:

This should reduce unnecessary random-path calls immediately, especially on `/buy/search`.

### Priority 2: Request-scope caching in `VirtualStockService`

Cache these values once per request/search call:

- active profile and active layers
- allocation rows by layer
- central and partner limit settings
- platform stock pattern defaults
- sale price for `tenant_id + game_id + set_size`
- active partner branding asset set

Expected impact:

Reduces repeated DB reads while still keeping the existing algorithm.

### Priority 3: Batch preview image metadata

Instead of calling `previewDescriptor()` independently per row, batch-load image assignments/background readiness/partner asset set for all stock refs in the response page.

Expected impact:

Reduces row-level enrichment overhead and response-time variance.

### Priority 4: Replace random ordering strategy

Avoid `ORDER BY md5(full_number || seed)` over the candidate set.

Possible alternatives:

- precompute one or more random ranks for `base_lottery_numbers`
- use Redis cached random pages per `game_id + tenant_id + seed + filters`
- use deterministic indexed cursor windows, then shuffle only a bounded subset in application memory
- prebuild virtual-search candidate pages during stock generation

Expected impact:

This is the biggest backend optimization for browse/random traffic.

### Priority 5: Materialize searchable virtual availability

Create a searchable availability table or cache for:

- `game_id`
- `partner_id`
- `tenant_id`
- `full_number`
- `front3`
- `back3`
- `back2`
- available copy count
- first available copy indexes
- image assignment snapshot

Expected impact:

Turns search from runtime virtual calculation into indexed reads. This is the strongest long-term solution, but it changes architecture more than the first three options.

## Recommended Fix Order

1. Change customer frontend to send `mode=search` when digits/number exist.
2. Add request-scope cache/preload inside virtual stock search.
3. Batch image preview and price enrichment.
4. Replace random `md5` ordering with a bounded/index-friendly strategy.
5. Consider materialized virtual availability if traffic grows.

## Validation After Fix

Use production-like tests for:

```bash
curl -sS -w '\nHTTP %{http_code} time_total=%{time_total} starttransfer=%{time_starttransfer}\n' \
  'https://xn--80-bsia4ej0dc7e8e3d.online/api/v1/public/stock/search?game_id=gam_01KVDCHAM6EFHXHH8C8VTGG9C4&mode=random&limit=20'

curl -sS -w '\nHTTP %{http_code} time_total=%{time_total} starttransfer=%{time_starttransfer}\n' \
  'https://xn--80-bsia4ej0dc7e8e3d.online/api/v1/public/stock/search?game_id=gam_01KVDCHAM6EFHXHH8C8VTGG9C4&mode=search&back2=22&limit=20'
```

Target:

- exact search: under 300ms to 500ms
- filtered search: under 800ms
- random browse: under 1s after backend random strategy is improved
