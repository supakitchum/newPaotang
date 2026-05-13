# Lottery Image Assets

This directory stores source assets used by the backend lottery image renderer.

Generated lottery images must not be stored here. Generated full and thumbnail WebP files belong in S3-compatible object storage under the configured `lotteries/...` prefix.

## Structure

```text
system/v1/emoji/e1
system/v1/emoji/e2
system/v1/emoji/e3
system/v1/emoji/e4
system/v1/number
system/v1/text_eng
system/v1/num_set_center
system/v1/num_set_right
system/v1/fonts
system/v1/beside
games/{game_id}/backgrounds/{version}/odd
games/{game_id}/backgrounds/{version}/even
games/{game_id}/backgrounds/{version}/charity
```

## Rules

- Keep central base image assets unbranded.
- Do not place partner-specific `logo_qr`, `right_sidebar`, or `logo_bottom` assets here.
- Partner-specific branding assets should be stored per partner/version in private object storage or a later partner-owned asset path.
- Backgrounds are game-scoped. Do not put game backgrounds under `system/v1`.
- Keep file names stable because generated image jobs may reference assets by index or configured name.
- Do not commit generated lottery images, caches, or rendered WebP outputs into this directory.
