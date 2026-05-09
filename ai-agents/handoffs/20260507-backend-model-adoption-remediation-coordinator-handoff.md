# Backend Model Adoption Remediation Coordinator Handoff

## Agent

Coordinator

## Task

Pause the current back-office continuation and open Backend Model Adoption Remediation because the previous model remediation added model classes but did not sufficiently adopt them in service-layer CRUD/read/detail/update paths.

## What Was Done

Coordinator reviewed:

```text
ai-agents/BOARD.md
ai-agents/decisions/20260507-backend-model-remediation-decision.md
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
apps/platform-api/app/Models/**
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Shared/**
```

Coordinator confirmed:

```text
Eloquent models exist under apps/platform-api/app/Models.
Controller DB::table() usage remains in TenantReservationController and TenantStockSyncController.
Service layer still has extensive DB::table() usage.
Current model usage in services is limited and does not represent broad model adoption.
docs/backend-query-builder-exceptions.md is too broad and needs service/method-specific exception entries.
```

Coordinator recorded:

```text
ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-coordinator-handoff.md
ai-agents/BOARD.md
```

## Validation

Coordinator performed source inspection only. No application runtime/test/migration commands were run.

Static checks used for evidence:

```sh
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers apps/platform-api/app/Modules/Platform -g "*.php"
find apps/platform-api/app/Models -maxdepth 2 -type f -name "*.php"
rg "DB::table\(" apps/platform-api/app -g "*.php"
rg -F "use App\\Models" apps/platform-api/app -g "*.php"
```

Key evidence:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php has DB::table('partner_tenants') in partnerIdForTenant()
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php has DB::table('partner_tenants') in partnerIdForTenant()
apps/platform-api/app/Shared services still contain broad DB::table() usage
service-level App\Models imports are currently very limited
```

## Known Risks

Backend Develop must avoid blind replacement. Query Builder should remain for:

```text
bulk insert/upsert
aggregate/report queries
lockForUpdate transactions
atomic stock/wallet/order/ticket updates
idempotency internals
outbox/inbox worker flows
security-sensitive token hash checks
performance-sensitive worker paths
```

The exception documentation must identify each remaining Query Builder usage by service/method and reason.

## Questions For Coordinator

None.

If Backend Develop discovers a required API contract change or business-rule ambiguity, stop that part and return the blocker to Coordinator.

## Next Agent

Orchestrator
