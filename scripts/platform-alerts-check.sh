#!/usr/bin/env bash
set -euo pipefail

docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json
