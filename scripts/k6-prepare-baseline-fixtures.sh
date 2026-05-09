#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESULTS_DIR=${K6_RESULTS_DIR:-"$ROOT_DIR/load-tests/results"}
BASE_URL=${BASE_URL:-"http://host.docker.internal:8000"}
TENANT_HOST=${TENANT_HOST:-"alpha.newpaotang.test"}
STOCK_COUNT=${STOCK_COUNT:-"40"}

mkdir -p "$RESULTS_DIR"

docker compose -f "$ROOT_DIR/compose.yaml" run --rm \
  -v "$RESULTS_DIR:/k6-results" \
  platform-api \
  php artisan load-tests:k6:prepare \
    --output-json=/k6-results/k6-baseline-env.json \
    --output-env=/k6-results/k6-baseline.env \
    --base-url="$BASE_URL" \
    --tenant-host="$TENANT_HOST" \
    --stock-count="$STOCK_COUNT"
