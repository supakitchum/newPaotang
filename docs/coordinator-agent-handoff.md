# Coordinator Agent Handoff

## 2026-05-15 Hotfix Summary

Latest pushed commits on `develop`:

- `b9880dc` - hardened admin session restore.
- `bf56bfd` - added lottery `logo_num_set` layout support.

Current follow-up commit in this handoff records the remaining BO layout adjustment for lottery images.

## Admin Session Hotfix

- Admin access tokens now last 8 hours (`expires_in=28800`).
- A second admin login revokes other active sessions for the same admin user.
- Revoked old sessions caused by another login return `admin_session_replaced`.
- BO stores the replacement-session notice and redirects to `/login` instead of staying on the `Restoring admin session` loader.
- The admin layout now clears stalled restore state and redirects when session verification leaves the browser unauthenticated.

Verification already completed:

- `php artisan test --filter=AdminAuthTest`
- `php artisan test --filter=M10AdminSecurityLinePolicyClosureTest`
- `npm run lint`
- `npm run build`
- Runtime `migrate:fresh --seed`
- Local API login and duplicate-login revocation check.

## Lottery Image Layout Hotfix

- `LotteryImageGenerator::DEFAULT_LAYOUT` now uses the project runtime DB layout as the project default.
- New migration `2026_05_15_000004_adopt_current_lottery_image_layout_defaults.php` writes the adopted layout into `platform_system_settings.lottery_image_layout`.
- Existing reset migration was aligned to the same layout baseline.
- Added `logo_num_set` layout slot:
  - Uses the same partner asset file as `logo_qr`.
  - Has independent `x`, `y`, `width`, and `height` values.
  - Renders only for partner-branded images.
  - Central base images remain unbranded.
- BO layout editor labels `logo_num_set` as `Logo Num Set`.
- Lottery image docs, OpenAPI text, and resource README mention that `logo_num_set` reuses the `logo_qr` asset.

Verification already completed:

- `php -l` for changed PHP files.
- `php artisan test --filter=LotteryImage` passed 16 tests.
- `npm run lint`
- `npm run build`
- Runtime `migrate:fresh --seed`
- Runtime DB check confirmed `logo_num_set`, updated `emoji_1`, and updated `logo_qr` layout values.
- Seeded admin login check passed after restore.

## BO Lottery Image Page Layout Adjustment

- `AdminLotteryImageOperations.vue` now places Image Zip Import as a full-width panel before Background Asset Sets.
- Background Asset Sets remains full-width below import, keeping pagination, selection, sorting, and bulk status actions.

## Agent Rules

- After any QA/test run that mutates the runtime DB, restore local runtime state with:

```sh
docker compose -p newpaotang exec -T platform-api php artisan migrate:fresh --seed
```

- Do not add a separate upload field for `logo_num_set`; it must follow the partner `logo_qr` asset and only use a separate layout slot.
- Partner branding overlays (`logo_qr`, `logo_num_set`, `right_sidebar`, `logo_bottom`) must not render on central base stock images.
- Partner/tenant users must not access lottery image or lottery branding management.

