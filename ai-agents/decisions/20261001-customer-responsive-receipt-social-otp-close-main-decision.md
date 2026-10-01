# Customer Receipt / News / Social OTP Closure and Main Integration

Date: 2026-10-01, Asia/Bangkok
Owner: Coordinator

## User Acceptance and Authorization

The user instructed: “ปิดเลยส่วนนั้นทดสอบไปแล้ว merge งานเข้า main เลยจะอัพเดท prod”.

Close this delivery and QA-G02 / QA-G03 based on the user's statement that testing was completed. QA-G01 was already independently approved. Preserve the original QA reports and their observed limitations; do not claim new coordinator-run runtime, device, provider, SMS or production acceptance. The pending runtime/login proposal is superseded.

The instruction explicitly authorizes committing the scoped delivery, merging develop into main and pushing the result. Production deployment is the user's next step; this integration does not dispatch a deployment, restart containers, migrate databases or change credentials.

## Selected Delivery

- Responsive Flutter/Nuxt receipts, fixed actions, horizontal Siamblend logo and localized primary-wallet display.
- Purchase dock safe-area alignment and Home news preloading during splash.
- OTP-verified existing social account linking in Flutter/Nuxt, generic/LINE backend services, security tests and matching API documentation.
- Focused receipt/social/news/dock regression tests and the fixture preview source. Include the existing one-line news-card color expectation correction, which matches the already committed application theme and is required by this focused suite.
- Current coordination decisions, tasks, handoffs and QA reports.

Concurrent push-channel localization, account-deletion localization, activity-detail cache, support interactions, production-preflight adjustments and unrelated tests remain local. In the shared localization file, stage only wallet/social hunks. Preserve all other working bytes and all local QA artifacts. Generated QA web bundles and raw local logs/evidence are not release source.

## Main History and Resolution

Before integration, develop and origin/develop point at `c8f130cdcc1a1addc3a7526597bd7a17107d574d`; origin/main points at `e93dcc14b5c383f67aa6c0d121474e905a7f9767`. Main is an independent initial deploy branch, with no common ancestor. Its Nuxt tree matches develop's root `30d4caec` apart from the older AI_PROJECT_CONTEXT.md file.

Use an isolated integration checkout from origin/main. Preserve both histories in a merge commit and resolve the obsolete main snapshot to the reviewed current develop tree, including its intentional replacement of `pages/profile.vue` with the current profile routes. Do not resurrect old routes or replace the dirty canonical checkout. The only working files overwritten for resolution belong to the new integration checkout.

Verify the final merge tree equals the scoped develop delivery, both branch histories are ancestors, local unrelated files retain their prior hashes, and remote main resolves to the pushed merge. No history rewrite or force push is authorized.

## Deployment Behavior

`.github/workflows/production-deploy.yml` builds images on develop pushes. Pushing main does not trigger it. Production deployment requires a manual workflow dispatch with `deploy=true` and `run_platform_migration=true`; this integration does not perform that action. Updated backend must precede updated clients because the minimal `existing_only` probe depends on the new backend contract. This delivery introduces no migration.

Next Agent: User for the intended production update after the verified main integration.
