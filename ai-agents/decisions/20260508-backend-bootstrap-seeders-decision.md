# Backend Bootstrap Seeders Decision

Date: 2026-05-08
Agent: Coordinator

## Decision

Open and complete a focused backend bootstrap seeder remediation before continuing the main plan.

The project had RBAC/menu seed data, but it did not have enough first-run data for local development, QA, and back-office protected-page verification. Add seeders for:

```text
central platform admin
central super admin role/scope assignments
three active demo partners and tenants
tenant owner admin users
tenant settings/theme/feature/maintenance/runtime defaults
menu routes needed by back-office navigation
```

## Constraints

- Use Laravel/Eloquent model classes for seeder writes where model casts/fillable matter.
- Keep seeders idempotent so `db:seed` can be rerun safely.
- Keep default passwords configurable through env values.
- Do not change API contracts, customer flow, tenant isolation, or business rules.
- Use Docker only for Artisan/test commands.
- Document seeded accounts and Docker commands.

## Acceptance Criteria

```text
DatabaseSeeder runs RBAC/menu, bootstrap admin, and demo tenant seeders.
Central admin can log in with seeded credentials.
Three demo tenants exist with active domains and owner accounts.
Tenant owner can log in to tenant scope.
Seeders can run twice without duplicate core records.
Back-office menu routes are seeded for key central and tenant paths.
Platform API test suite passes through Docker.
```

## Next Agent

QA Tester
