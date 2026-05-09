#!/usr/bin/env sh
set -eu

docker compose exec platform-api php artisan platform:runtime:readiness --format=json
