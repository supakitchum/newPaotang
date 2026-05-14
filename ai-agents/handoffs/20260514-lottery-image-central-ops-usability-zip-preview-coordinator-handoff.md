# Lottery Image Central Ops Usability Zip Preview Coordinator Handoff

## Agent

Coordinator

## Task

Open implementation phase:

```text
lottery-image-central-ops-usability-zip-preview
```

## Source Decision

```text
ai-agents/decisions/20260514-lottery-image-central-ops-usability-zip-preview-decision.md
```

## Owner Requirements

Implement the following:

```text
lottery-images must have clear buttons/entry points
Games table must have an action button to lottery-images
Game ID must become a game-name selection control backed by central games API
background upload must accept one PNG zip and backend must generate full/thumb variants
lottery-images needs manual-number preview
lottery-images preview can select partner, but default/initial preview remains unbranded until branded mode is requested
partner/tenant must not see lottery-images
lottery-images and lottery-branding are central-only
Partners table must have an action button to lottery-branding
lottery-branding must have preview with partner_id locked to the route param
```

## Required Orchestrator Work

Create and dispatch tasks in this order:

```text
1. Backend Develop - lottery-image-central-ops-zip-preview-backend
2. BO Develop - lottery-image-central-ops-zip-preview-bo
3. QA Tester - lottery-image-central-ops-zip-preview-qa
```

## Backend Task Requirements

Backend task must include:

```text
central-only endpoint for PNG zip background import
backend extraction/validation/normalization for PNG files
backend-generated optimized WebP full/thumb variants
background asset set registration after generated variants are ready
central-only lottery-images preview API
optional partner preview mode in lottery-images preview API
default central_unbranded preview even when partner_id is selected until branded mode is requested
central-only lottery-branding preview API with route-locked partner_id
OpenAPI updates
tests for permissions, zip import, preview, no stock creation, no branding lock, pending_assets/mix regression
```

Suggested API names:

```text
POST /api/v1/admin/central/lottery-images/background-asset-sets/import-zip
POST /api/v1/admin/central/lottery-images/preview
POST /api/v1/admin/central/partners/{partner_id}/lottery-branding/preview
```

## BO Task Requirements

BO task must include:

```text
clear button/link to /admin/central/lottery-images
Games table action to /admin/central/lottery-images?game_id={game_id}
Partners table action to /admin/central/partners/{partner_id}/lottery-branding
game select using central games list and displaying game name
query param support for preselecting game_id
single PNG zip upload UI for background sets
lottery-images preview panel with optional partner select and explicit mode/default unbranded behavior
lottery-branding preview panel with no partner selector and partner_id locked from route
tenant/partner scope hiding and route guard behavior
updated structural checks/tests
```

## QA Task Requirements

QA task must cover:

```text
central-only visibility and backend enforcement
Games action deep link
Partners action deep link
game select display/value behavior
valid PNG zip import
invalid zip and non-PNG rejection
generated full/thumb readiness
lottery-images central_unbranded preview
lottery-images partner selection default unbranded behavior
lottery-images explicit partner_branded preview behavior
lottery-branding route-locked partner preview
no stock rows or permanent image rows created by preview
no partner branding lock caused by preview
mix/pending retry regression
OpenAPI parse
credential/artifact scan
```

## Workspace Note

The shared worktree contains unrelated dirty and staged files from other agents, including generated lottery image assets. Do not clean, revert, unstage, overwrite, or commit unrelated files.

## Next Agent

```text
Orchestrator
```
