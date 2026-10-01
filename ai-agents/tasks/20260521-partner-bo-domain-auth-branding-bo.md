# partner-bo-domain-auth-branding-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back Office UI part of:

```text
partner-bo-domain-auth-branding
```

Do not start until Backend Develop has completed and pushed:

```text
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md
```

## Canonical Worktree Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or overlapping dirty files exist.

## Objective

Make Back Office support two modes:

```text
Central BO mode: existing behavior
Partner BO mode: host starts with bo. and login is tenant-only
```

Partner BO must use same-origin `/api/v1` and show tenant branding on login.

## Source Of Truth

Read before implementation:

```text
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-orchestrator.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-backend.md
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
```

Relevant current code:

```text
apps/back-office/pages/login.vue
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/middleware/admin.global.ts
apps/back-office/layouts/admin.vue
apps/back-office/components/AdminSidebar.vue
apps/back-office/scripts/check.mjs
```

## Scope

BO Develop owns:

```text
partner BO host mode detection
same-origin API base for bo.* mode
admin site config fetch/cache
partner branded login page
tenant-only login payload from bo.* mode
partner BO redirect restrictions
central BO unchanged behavior
BO tests/check scripts/build
BO handoff
```

Out of scope:

```text
apps/platform-api/**
apps/customer/**
changing post-login sidebar/header branding beyond necessary safe defaults
custom BO domain labels other than bo.*
```

## Required BO Behavior

Host mode:

```text
if browser host starts with bo. => partner BO mode
else => central BO mode
```

API base:

```text
partner BO mode uses /api/v1
central BO mode uses current NUXT_PUBLIC_ADMIN_API_BASE behavior
```

Partner BO login:

```text
fetch GET /api/v1/public/admin-site-config before/while rendering login
show tenant/partner display name from site.display_name or tenant.name
show brand.logo_url if present; fallback to current NewPaotang logo/text if null
hide scope selector
hide Tenant ID / Partner ID inputs
submit email/password with scope=tenant and no tenant_id
after login route to /admin/tenant/dashboard
safe redirect allows only /admin/tenant/*
block /admin/central/* redirects in partner BO mode
```

Central BO login:

```text
keep current scope selector
keep existing tenant login input/behavior
keep current NUXT_PUBLIC_ADMIN_API_BASE behavior
do not fetch partner admin-site-config unless useful and non-disruptive
```

Session behavior:

```text
partner BO mode must not let session align to central paths
if authenticated session on bo.* has no tenant scope for current partner, clear session and show login notice
tenant API calls still send X-Admin-Scope=tenant and matching X-Tenant-Id from login response
```

## Required Validation

Docker only:

```sh
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
git diff --check
```

Add/update BO checks for:

```text
partner host detection for bo.*
partner mode uses /api/v1
partner login hides scope and tenant id fields
partner login submits tenant scope without tenant_id
partner mode safe redirect blocks /admin/central/*
central login still has scope selector and tenant id input
login can render partner brand name/logo from admin-site-config
```

## Handoff Requirements

Write:

```text
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-bo-handoff.md
```

Include:

```text
backend handoff/commit consumed
worktree path
HEAD and origin/develop
commits pushed
files changed summary
test commands/results
known risks/blockers
```
