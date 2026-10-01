#!/usr/bin/env sh
set -eu

QUEUE=${PLATFORM_WORKER_QUEUE:-default}

docker compose run --rm \
  -e PLATFORM_WORKER_QUEUE="$QUEUE" \
  platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue="$QUEUE"
