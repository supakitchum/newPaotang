#!/usr/bin/env bash
set -euo pipefail

docker compose exec platform-api php artisan platform:observability:report --format=json
