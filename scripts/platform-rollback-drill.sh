#!/usr/bin/env sh
set -eu

docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
docker compose run --rm platform-api php artisan migrate:status
docker compose exec platform-api php artisan platform:smoke --no-seed-login
