#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
K6_IMAGE=${K6_IMAGE:-"grafana/k6:latest"}
CDN_URL=${CDN_BASE_URL:-}
IMAGE=${IMAGE_PATH:-${TICKET_IMAGE_CDN_IMAGE_PATH:-}}

docker run --rm \
  -v "$ROOT_DIR/load-tests/k6:/scripts:ro" \
  "$K6_IMAGE" inspect /scripts/ticket-image-cdn-spike.js

if [ "$CDN_URL" = "" ] || [ "$IMAGE" = "" ]; then
  echo "ticket-image-cdn-spike: blocked until explicit CDN_BASE_URL and IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH are supplied for a real CDN/R2 image."
  exit 0
fi

docker run --rm \
  -v "$ROOT_DIR/load-tests/k6:/scripts:ro" \
  -e CDN_BASE_URL="$CDN_URL" \
  -e IMAGE_PATH="$IMAGE" \
  -e TICKET_IMAGE_CDN_IMAGE_PATH="$IMAGE" \
  -e K6_PROFILE="${K6_PROFILE:-smoke}" \
  "$K6_IMAGE" run /scripts/ticket-image-cdn-spike.js
