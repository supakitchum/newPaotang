#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESULTS_DIR=${K6_RESULTS_DIR:-"$ROOT_DIR/load-tests/results"}
ENV_FILE=${K6_ENV_FILE:-"$RESULTS_DIR/k6-baseline.env"}
RUN_ID=$(date -u +"%Y%m%dT%H%M%SZ")
RUN_DIR="$RESULTS_DIR/$RUN_ID"
K6_IMAGE=${K6_IMAGE:-"grafana/k6:latest"}
K6_PROFILE=${K6_PROFILE:-"smoke"}
OVERRIDE_CDN_BASE_URL=${CDN_BASE_URL:-}
OVERRIDE_IMAGE_PATH=${IMAGE_PATH:-}
OVERRIDE_TICKET_IMAGE_CDN_IMAGE_PATH=${TICKET_IMAGE_CDN_IMAGE_PATH:-}

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE. Run scripts/k6-prepare-baseline-fixtures.sh first." >&2
  exit 1
fi

mkdir -p "$RUN_DIR"

set -a
. "$ENV_FILE"
set +a

CDN_BASE_URL=${OVERRIDE_CDN_BASE_URL:-${CDN_BASE_URL:-}}
TICKET_IMAGE_CDN_IMAGE_PATH=${OVERRIDE_TICKET_IMAGE_CDN_IMAGE_PATH:-${TICKET_IMAGE_CDN_IMAGE_PATH:-}}
IMAGE_PATH=${OVERRIDE_IMAGE_PATH:-${IMAGE_PATH:-${TICKET_IMAGE_CDN_IMAGE_PATH:-}}}
export CDN_BASE_URL IMAGE_PATH TICKET_IMAGE_CDN_IMAGE_PATH

run_k6() {
  scenario_file="$1"
  scenario_name=$(basename "$scenario_file" .js)

  docker run --rm \
    --add-host=host.docker.internal:host-gateway \
    --env-file "$ENV_FILE" \
    -e CDN_BASE_URL="$CDN_BASE_URL" \
    -e IMAGE_PATH="$IMAGE_PATH" \
    -e TICKET_IMAGE_CDN_IMAGE_PATH="$TICKET_IMAGE_CDN_IMAGE_PATH" \
    -e K6_PROFILE="$K6_PROFILE" \
    -v "$ROOT_DIR/load-tests/k6:/scripts:ro" \
    -v "$RUN_DIR:/results" \
    "$K6_IMAGE" run \
      --summary-export "/results/$scenario_name.summary.json" \
      "/scripts/$scenario_file"
}

run_k6 customer-stock-search.js
run_k6 concurrent-booking-same-stock.js
run_k6 checkout-wallet-consistency.js
run_k6 partner-tenant-burst-sync.js
run_k6 reward-publish-spike.js
run_k6 reward-checking-queue-chunk.js

if [ "${IMAGE_PATH:-}" != "" ] && [ "${CDN_BASE_URL:-}" != "" ]; then
  run_k6 ticket-image-cdn-spike.js
else
  cat > "$RUN_DIR/ticket-image-cdn-spike.skipped.json" <<'JSON'
{
  "scenario": "ticket-image-cdn-spike",
  "status": "skipped",
  "reason": "Local/dev baseline has no Cloudflare CDN/R2 ticket image path. Set CDN_BASE_URL and IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH to run this scenario."
}
JSON
fi

echo "k6 summaries written to $RUN_DIR"
