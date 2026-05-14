# Lottery Image Central Ops Usability Zip Preview Decision

Date: 2026-05-14
Owner: Coordinator
Task: `lottery-image-central-ops-usability-zip-preview`
Result: OPEN - ORCHESTRATOR DISPATCH REQUIRED

## Context

The expanded lottery image generation delivery passed its final development launch gate. The owner now requires a usability and operations follow-up for central lottery image management.

This follow-up changes the operator workflow from technical asset-id entry to a central-friendly flow:

```text
game selection by name
single PNG zip upload per background set
backend-generated full/thumb variants
central preview rendering before stock creation
partner branding preview from the partner branding page
clear central-only entry points and permissions
```

## Decision

Coordinator opens a new implementation phase:

```text
lottery-image-central-ops-usability-zip-preview
```

This is not a production rollout task. It is a Backend + Back-office contract/UI follow-up over the already approved lottery image delivery.

## Security And Access Rules

The following surfaces must be central-only:

```text
/admin/central/lottery-images
/admin/central/partners/{partner_id}/lottery-branding
all lottery image operations APIs
all partner lottery branding APIs
```

Partner/tenant users must not see, open, or call these workflows.

Backend must enforce central-only access through auth/scope/permission checks. BO must also hide menu/actions outside central scope, but UI hiding alone is not sufficient.

## Required Backend Scope

Backend Develop must add API support for PNG zip background upload and previews.

### PNG Zip Background Import

Add a central-only endpoint, suggested contract:

```text
POST /api/v1/admin/central/lottery-images/background-asset-sets/import-zip
```

The endpoint should accept:

```text
game_id
version
set_type: odd | even | charity
zip asset/upload containing PNG files only
expected_count or backend-configured count where applicable
status / supersede_existing where applicable
```

Rules:

```text
zip contains PNG files only
operator uploads one zip per game + version + set_type
backend extracts and validates file count, names, mime type, dimensions, and size
backend normalizes ordering, e.g. 001.png ... 100.png
backend generates optimized WebP full and thumb variants
backend registers the background asset set after generated variants are ready
existing pending_assets behavior remains unchanged
no silent fallback from even/charity to odd
```

BO should no longer require operators to upload `source`, `full`, and `thumb` separately.

### Lottery Images Preview

Add a central-only preview endpoint, suggested contract:

```text
POST /api/v1/admin/central/lottery-images/preview
```

Payload should support:

```text
game_id
version
set_type: odd | even | charity
lottery_number
partner_id optional
mode optional: central_unbranded | partner_branded
```

Rules:

```text
preview must not create stock rows
preview must not create permanent lottery image records
preview must not lock partner branding
default preview is central_unbranded
if a partner is selected in lottery-images, initial/default preview remains unbranded until partner_branded mode is explicitly requested
partner_branded mode may render full partner composition only when that partner has ready branding assets
if partner assets are missing, return an actionable warning/fallback response
```

### Lottery Branding Preview

Add a central-only partner-locked preview endpoint, suggested contract:

```text
POST /api/v1/admin/central/partners/{partner_id}/lottery-branding/preview
```

Rules:

```text
partner_id must come from the route
request must not accept a different partner_id in the body
preview uses the selected partner branding assets for full composition
preview must not lock branding
preview must not create stock rows
preview must not create permanent lottery image records
```

### API / Test Requirements

Backend must update:

```text
docs/openapi.yaml
feature tests for central-only permission enforcement
feature tests for PNG zip validation and generated full/thumb registration
feature tests for lottery-images preview central_unbranded and partner_branded behavior
feature tests for lottery-branding preview with route-locked partner_id
regression tests for pending_assets retry and mix behavior
```

## Required BO Scope

BO Develop must update central UI after Backend contract is ready.

### Navigation And Buttons

Add clear entry points:

```text
central dashboard/menu button to /admin/central/lottery-images
Games table action button to /admin/central/lottery-images?game_id={game_id}
Partners table action button to /admin/central/partners/{partner_id}/lottery-branding
visible button/link into lottery-branding from relevant partner surfaces
```

Do not expose these buttons in tenant/partner scope.

### Game Selection

Replace manual Game ID entry with a selection control:

```text
load games from GET /api/v1/admin/central/games
display game name
store/send game_id
support URL query game_id for deep links from Games table
handle missing/archived games gracefully
```

### Background Upload Form

Replace source/full/thumb upload fields with:

```text
one zip upload field
PNG-only guidance
set_type selector: odd | even | charity
version field
expected count display or input if backend requires it
upload progress/error states
readiness refresh after import
```

### Lottery Images Preview Panel

Add preview panel to:

```text
/admin/central/lottery-images
```

Controls:

```text
game select
version
set_type
lottery_number manual input
optional partner select
mode control where default is central_unbranded
preview action
image preview result
warning/fallback display from backend
```

### Lottery Branding Preview Panel

Add preview panel to:

```text
/admin/central/partners/{partner_id}/lottery-branding
```

Controls:

```text
game select
version
set_type
lottery_number manual input
preview action
```

Rules:

```text
partner_id is locked to route param
no partner selector on this page
preview uses this partner's branding composition
show warning if branding assets are incomplete or locked/readiness state blocks preview
```

## QA Requirements

QA Tester must validate:

```text
central can access lottery-images and lottery-branding
tenant/partner scope cannot see or access lottery-images and lottery-branding
Games table action opens lottery-images with the selected game preselected
Partners table action opens lottery-branding with the route partner locked
game select displays names and sends game_id
PNG zip import creates/registers generated full/thumb variants
invalid zip/mixed file type/non-PNG/count errors are rejected with usable messages
readiness updates after zip import
lottery-images preview works as central_unbranded
lottery-images partner selection defaults to unbranded and only renders partner_branded when explicitly requested
lottery-branding preview uses route partner_id and does not expose a partner selector
preview actions do not create stock rows, permanent image rows, or lock partner branding
mix and pending_assets retry behavior still pass
OpenAPI parses
artifact credential scan passes
```

## Sequencing

Recommended Orchestrator split:

```text
Lane A - Backend contract: PNG zip import, preview APIs, central-only enforcement, OpenAPI/tests
Lane B - BO UI: navigation/actions, game select, zip upload UI, preview panels, central-only visibility
Lane C - QA: full workflow and permission validation after A and B complete
```

Backend should run before BO because BO depends on the new API contracts. BO may prepare route/action wiring in parallel only where it does not require final API response shape.

## Next Agent

```text
Orchestrator
```

Orchestrator must create the Backend and BO task briefs and preserve this sequence.
