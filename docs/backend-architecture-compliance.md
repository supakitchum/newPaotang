# Backend Architecture Compliance

This remediation addresses `document/09_AI_WORK_INSTRUCTIONS.md` for the current `apps/platform-api` backend.

## Completed

```text
model layer added under App\Models
application-source data access standardized on Eloquent model query builders
application-source model calls standardized on imported short model class names
explicit tenant scope helper added through BelongsToTenant
core relationships represented for tenant/domain, commerce, wallet, reward, affiliate, commission, payout, settlement, and RBAC pivots
dedicated validation classes added under module-owned Http\Requests namespaces
validation_failed envelope preserved through ApiErrorResponse
Query Builder exception policy revised to no app-source DB::table exceptions
strict mass-assignment diagnostics enabled outside production
command-class layer added under App\Console\Commands
production workflow console commands registered through bootstrap/app.php
Modular Monolith controller convention documented under App\Modules\<Domain>\Http\Controllers
tenant-scoped maintenance and support access services/controllers/middleware added for M9
focused model and validation tests added
```

## Backend Structure

```text
controllers use the module controller convention:
apps/platform-api/app/Modules/<Domain>/Http/Controllers/**

domain services use module-owned service namespaces:
apps/platform-api/app/Modules/<Domain>/Services/**

domain request validators use module-owned request namespaces:
apps/platform-api/app/Modules/<Domain>/Http/Requests/**

root apps/platform-api/app/Http/Controllers is intentionally absent

production workflow commands use the command-class layer:
apps/platform-api/app/Console/Commands/**

shared infrastructure is limited to audit, auth/session middleware and contexts,
tenant context/middleware, idempotency, HTTP helpers, base validation helpers,
cross-cutting M10 observability/reporting primitives under App\Shared\Observability,
and Cloudflare/CDN/R2 readiness primitives under App\Shared\Cloudflare
```

## Boundary Rules Preserved

```text
No apps/customer changes
No apps/back-office changes
No docs/openapi.yaml changes
No API URL or response-shape changes intended
No global tenant scopes introduced
No host PHP/Composer/Artisan/Node commands required
```

## Documentation Map

```text
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-console-commands.md
docs/backend-maintenance-support.md
docs/backend-architecture-compliance.md
```

## QA Focus

QA should verify:

```text
required model classes autoload
all application migration tables have concrete models except Laravel runtime tables
app source contains no DB::table(), DB::raw(), or ->from() table shortcuts
app source contains no fully qualified \App\Models\... model calls
every concrete model declares explicit fillable and base models do not globally unguard
tenant-owned models expose scopeForTenant
representative casts and relationships exist
invalid report export and wallet adjustment return validation_failed
invalid payloads do not create idempotency success rows or business mutations
required console commands are registered from command classes
routes/console.php no longer owns production workflow closure commands
controller convention is documented as module-based
domain service and request validation references no longer point at App\Shared domain folders
existing feature tests remain green
maintenance/support access writes enforce tenant RBAC, idempotency, audit, and outbox evidence
support impersonation tokens are hashed at rest and sensitive actions are blocked with evidence
M10 Docker runtime roles, platform:smoke, monitoring defaults, and load-test scaffolding remain present
M10 observability report and alert-check commands emit safe local/dev artifacts without external delivery claims
M10 Cloudflare readiness command emits safe local/dev domain, HTTPS, WAF/cache, CDN/R2 blockers without external Cloudflare/R2 calls
custom domains remain guarded from active status until DNS, SSL, Cloudflare proxy, and HTTPS readiness evidence exists
```
