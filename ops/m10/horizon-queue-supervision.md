# M10 Horizon Queue Supervision

## Boundary

This artifact is local/dev readiness only. It is not approval for a public Horizon dashboard, production queue supervision, process-manager configuration, or queue SLOs.

Run the local verifier:

```sh
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
```

## Current Local Status

```text
Horizon package is not installed in this repository.
Horizon config is not present.
No Horizon dashboard route is registered.
Queue workers are validated through bounded Docker queue:work --once commands only.
```

The readiness command must therefore carry explicit blockers:

```text
horizon_package_missing
horizon_config_missing
horizon_supervisor_not_configured
horizon_dashboard_access_policy_not_verified
horizon_production_process_manager_missing
```

## Queue Supervision Policy

Queue ownership is recorded in:

```text
ops/m10/queue-worker-profiles.json
```

Critical customer, checkout, stock sync, webhook, and reward queues must not share production worker capacity with `report-build`, `usage-metering`, or `partner-monitoring`.

## Production Evidence Required

```text
Laravel Horizon package and config approved
Horizon supervisors mapped to queue-worker profiles
dashboard route restricted by admin auth, network controls, and production access policy
process manager or orchestration config manages Horizon workers
queue lag dashboards and alert thresholds verified
restart/drain procedure documented and rehearsed
```
