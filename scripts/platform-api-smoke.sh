#!/usr/bin/env sh
set -eu

docker compose up -d postgres valkey platform-api
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
curl -I --max-time 10 http://localhost:8000/health
curl -I --max-time 10 http://localhost:8000/health/live
curl -I --max-time 10 http://localhost:8000/health/ready
