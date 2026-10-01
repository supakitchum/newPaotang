#!/usr/bin/env sh
set -eu

docker compose run --rm platform-api php artisan schedule:list
