# M10 Runtime Hardening Readiness

## Boundary

This artifact summarizes local/dev runtime hardening for queues, Horizon, Reverb, and scheduler. It is not staging, production, or client-delivery approval.

Machine-readable verifier:

```sh
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
```

## Local/Dev Evidence

```text
queue worker profile catalog exists and covers PLATFORM_WORKER_QUEUES
bounded queue worker validation uses docker compose run --rm platform-api php artisan queue:work --once
scheduler workloads are registered and visible through schedule:list
admin realtime auth routes remain registered
Horizon/Reverb blockers are explicit when packages/runtime profiles are unavailable
production_approved is always false
```

## Related Artifacts

```text
ops/m10/queue-worker-profiles.json
ops/m10/horizon-queue-supervision.md
ops/m10/reverb-deployment-readiness.md
ops/m10/scheduler-workload-runbook.md
```

## Remaining Production Blockers

```text
horizon_package_missing
horizon_config_missing
horizon_supervisor_not_configured
horizon_dashboard_access_policy_not_verified
horizon_production_process_manager_missing
reverb_package_missing
reverb_runtime_profile_not_configured
reverb_tls_and_public_host_not_verified
reverb_scaling_and_load_not_verified
production scheduler leadership and SLO evidence missing
```
