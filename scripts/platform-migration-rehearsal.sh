#!/usr/bin/env sh
set -eu

docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
