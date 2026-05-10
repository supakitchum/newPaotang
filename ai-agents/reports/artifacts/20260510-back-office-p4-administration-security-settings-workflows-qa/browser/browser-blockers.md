Browser QA notes:

- In-app browser was already on `http://localhost:3100/admin/tenant/sync-logs`, but after `migrate:fresh --seed` it retained a stale `sessionStorage` session and rendered the authenticated shell indefinitely at "Restoring admin session".
- The user-menu dropdown opened, but the Logout click did not clear the stale client session, likely because the shell had not fully hydrated.
- Browser-use blocked a `javascript:` URL storage-clear attempt; I did not attempt to bypass that policy.
- A separate Docker Playwright clean-context attempt was prepared with API request routing from `localhost:8000` to `platform-api:8000`. Playwright package install worked, but the fallback browser binary was incompatible with Alpine, and installing Alpine Chromium was still mid-package install after several minutes. I stopped the temporary container to avoid leaving long-running QA infrastructure active.
- No browser screenshots were captured for this run. API and code-review evidence were collected instead.
