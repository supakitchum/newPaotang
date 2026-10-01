# Back Office P4 Administration/Security Settings QA Report

Date: 2026-05-10
Role: QA Tester
Task: `back-office-p4-administration-security-settings-workflows`
Verdict: FAIL - send to Coordinator for defect triage

## Scope

Reviewed P4 rows:

- `central:admin_users`
- `central:roles_permissions`
- `central:menu_management`
- `central:system_settings`
- `tenant:admin_users`
- `tenant:roles_permissions`
- `tenant:menu_management`
- `tenant:maintenance`
- `tenant:support_access_logs`
- `tenant:settings`

Source-of-truth and handoff files read:

- `ai-agents/BOARD.md`
- `ai-agents/decisions/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-decision.md`
- `ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-coordinator-handoff.md`
- `ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md`
- `ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-qa.md`
- `ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md`
- `ai-agents/rules/global-rules.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-crud-coverage.md`
- `docs/back-office-menu-completion.md`
- `docs/permissions.md`

## Findings

### Finding 1 (apps/back-office/pages/admin/tenant/maintenance.vue:84-95) [P2]
Maintenance bypass can be created without the required ticket ID.

The P4 QA criteria require the create bypass flow to require reason/ticket. BO surfaces `Ticket ID`, but the submit button is only disabled by `saving || !tenantId || !bypass.reason.trim()`. I also verified the backend accepts the same write without `ticket_id`: `POST /admin/tenant/maintenance/bypasses` returned `201` with `"ticket_id": null`, then I cleaned up the created bypass. Evidence: `api/maintenance-bypass-missing-ticket-check.json`.

Impact: operators can create audit-sensitive maintenance bypasses without the ticket linkage required by the accepted P4 workflow.

### Finding 2 (apps/back-office/components/AdminMenuTreeEditor.vue:65-74) [P2]
Menu tree save bypasses the required confirmation/context step.

The P4 menu-management criteria require save confirmation with scope and changed-item context. The editor only collects a free-text reason and calls `save` directly from the `Save menu` button; `AdminOperationsPage.saveMenuTree` immediately sends `PUT /admin/{scope}/menu-management` with `{ items, reason }`. There is no confirmation modal and no changed-item context review before committing the full menu tree.

Impact: a security-sensitive menu tree rewrite can be submitted after typing any reason, without the wrong-target protection required for this workflow.

## Validation

Passed:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest`
- `docker compose run --rm platform-api php artisan test --filter=Maintenance`
- `docker compose run --rm platform-api php artisan test --filter=Support`
- `docker compose exec -T platform-api php artisan route:list`
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`

Observed carry-forward warnings only:

- Node `DEP0180`
- Meno `media-33.jpg` unresolved-at-build warning

After PHP tests, I reran `migrate:fresh --seed` before API QA because the focused tests reset the local database.

## API Evidence

Artifact: `ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/api/p4-api-evidence.json`

Covered successful safe local writes with redacted tokens/secrets:

- central role create/update/archive
- central admin user create/detail/update/disable
- central menu reversible save/restore
- central system settings update/restore
- tenant role create/update/archive with `X-Tenant-Id: ten_demo_alpha`
- tenant admin user create/detail/update/disable with `X-Tenant-Id: ten_demo_alpha`
- tenant menu reversible save/restore with `X-Tenant-Id: ten_demo_alpha`
- tenant maintenance save, bypass create/revoke
- tenant support access create/detail/approve/impersonate/elevated-action/end-session/revoke, with token fields redacted
- tenant settings update/restore
- tenant theme update/restore
- tenant domain create/detail/verify/update/delete

`jq` check found zero API evidence steps with `status >= 400`. Secret scan found no raw seeded passwords, bearer strings, JWT-looking tokens, or unredacted access/refresh token values in the P4 artifact directory.

## Browser QA

Browser evidence is limited and recorded in `browser/browser-blockers.md`.

- In-app browser retained a stale session after DB reset and stayed on the protected shell at "Restoring admin session"; logout UI did not clear it.
- Browser-use blocked storage clearing via `javascript:` URL; I did not bypass that policy.
- Docker Playwright clean-context fallback was attempted, but Alpine browser runtime setup did not complete in a reasonable time and the temporary container was stopped.

Because findings above already fail the task, I did not ask implementation agents to fix anything directly. Per role rules, this report is for Coordinator triage.

## Workspace State

Current branch: `develop`
Current head at QA start: `1842cdb00a77dcf7419bdcea44738df4383d76e0`

Unrelated pre-existing dirty files were not modified:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

QA-created artifacts:

- `ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/`
